/**
 * MyArena Cloud Functions
 *
 * HTTP endpoints:
 *  - verifyEmail   → signup OTP: register_and_send_otp | verify_otp_and_create_user | resend_otp
 *  - passwordReset → reset OTP:  send_reset_otp | verify_reset_otp
 *
 * Phone OTP is handled natively by Firebase Auth on the client side —
 * no Cloud Function needed for phone verification.
 */

const { onRequest, onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated, onDocumentUpdated, onDocumentDeleted } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const { getStorage } = require("firebase-admin/storage");

admin.initializeApp();

const verifyEmail = require("./verifyEmail");
const passwordReset = require("./passwordReset");
const inviteOwner = require("./inviteOwner");
const inviteAdmin = require("./inviteAdmin");
const staffManagement = require("./staffManagement");

exports.verifyEmail = onRequest(verifyEmail);
exports.passwordReset = onRequest(passwordReset);
exports.inviteOwner = onRequest({ cors: true }, inviteOwner);
exports.inviteAdmin = onRequest({ cors: true }, inviteAdmin);
exports.staffManagement = onRequest({ cors: true }, staffManagement);

// ── FCM helpers ──────────────────────────────────────────────────────

// Returns all valid FCM tokens stored for a user (supports multi-device).
// Schema: users/{uid}.fcmTokens = { [token]: true }   (new, preferred)
//         users/{uid}.fcmToken  = "..."                (legacy single-token)
async function getTokens(uid) {
  const snap = await admin.firestore().collection("users").doc(uid).get();
  const data = snap.data();
  if (!data) return [];
  // Prefer the per-device map; fall back to legacy single field.
  if (data.fcmTokens && typeof data.fcmTokens === "object") {
    return Object.keys(data.fcmTokens).filter((t) => t && t.length > 0);
  }
  if (data.fcmToken && typeof data.fcmToken === "string") {
    return [data.fcmToken];
  }
  return [];
}

// Remove a token that FCM has rejected (expired / device re-imaged).
async function removeStaleToken(uid, token) {
  const ref = admin.firestore().collection("users").doc(uid);
  try {
    await ref.update({
      [`fcmTokens.${token}`]: admin.firestore.FieldValue.delete(),
      // Clear legacy field too if it matches.
      ...(await ref.get().then((s) => s.data()?.fcmToken === token
        ? { fcmToken: admin.firestore.FieldValue.delete() }
        : {})),
    });
  } catch (_) { /* best-effort */ }
}

// Extra data fields merged into the FCM data payload (all values must be strings).
async function sendPush(uid, title, body, type = "general", relatedId = null, extraData = {}) {
  // Durable in-app inbox copy — written even when the user has no FCM token,
  // so the notification center shows every event.
  await admin.firestore().collection("notifications").add({
    uid,
    title,
    body,
    type,
    ...(relatedId ? { relatedId } : {}),
    read: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  }).catch((e) => console.error("inbox write failed:", e));

  const tokens = await getTokens(uid);
  if (tokens.length === 0) return;

  const dataPayload = {
    type,
    ...(relatedId ? { relatedId } : {}),
    ...extraData,
  };

  const msgBase = {
    notification: { title, body },
    data: dataPayload,
    android: {
      priority: "high",
      notification: { sound: "default", channelId: "my_arena_channel" },
    },
    apns: {
      headers: { "apns-priority": "10" },
      payload: { aps: { sound: "default" } },
    },
  };

  await Promise.all(tokens.map(async (token) => {
    try {
      await admin.messaging().send({ ...msgBase, token });
    } catch (e) {
      const code = e.errorInfo?.code ?? e.code ?? "";
      if (
        code === "messaging/registration-token-not-registered" ||
        code === "messaging/invalid-registration-token"
      ) {
        await removeStaleToken(uid, token);
      } else {
        console.error(`sendPush: FCM error for uid=${uid}:`, code, e.message);
      }
    }
  }));
}

// ── Idempotent push — uses a deterministic doc ID so Cloud Function retries
//    never duplicate the in-app inbox entry. FCM itself is best-effort.
async function sendPushIdempotent(uid, title, body, type, relatedId, idempotencyKey) {
  const db = admin.firestore();
  const docId = idempotencyKey
    ? `${uid}_${idempotencyKey}`
    : null;
  if (docId) {
    // set with merge:false is idempotent — second write is a no-op if the
    // doc already exists because Firestore merges the same data cleanly.
    // Use a set with the deterministic ID rather than add().
    const ref = db.collection("notifications").doc(docId);
    const existing = await ref.get();
    if (existing.exists) {
      // Already delivered this notification event; skip FCM too.
      return;
    }
    await ref.set({
      uid, title, body, type,
      ...(relatedId ? { relatedId } : {}),
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }).catch((e) => console.error("idempotent inbox write failed:", e));
  } else {
    // Fallback to non-idempotent path (same as sendPush).
    await db.collection("notifications").add({
      uid, title, body, type,
      ...(relatedId ? { relatedId } : {}),
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }).catch((e) => console.error("inbox write failed:", e));
  }

  const tokens = await getTokens(uid);
  if (tokens.length === 0) return;
  const msgBase = {
    notification: { title, body },
    data: { type, ...(relatedId ? { relatedId } : {}) },
    android: { priority: "high", notification: { sound: "default", channelId: "my_arena_channel" } },
    apns: { headers: { "apns-priority": "10" }, payload: { aps: { sound: "default" } } },
  };
  await Promise.all(tokens.map(async (token) => {
    try {
      await admin.messaging().send({ ...msgBase, token });
    } catch (e) {
      const code = e.errorInfo?.code ?? e.code ?? "";
      if (code === "messaging/registration-token-not-registered" ||
          code === "messaging/invalid-registration-token") {
        await removeStaleToken(uid, token);
      } else {
        console.error(`sendPushIdempotent: FCM error for uid=${uid}:`, code, e.message);
      }
    }
  }));
}

// ── Booking: deposit submitted → notify owner ─────────────────────────
exports.onBookingCreated = onDocumentCreated("bookings/{bookingId}", async (event) => {
  const data = event.data.data();
  const db = admin.firestore();

  // For recurring series, only notify on week 1 to avoid duplicate notifications.
  const isRecurring = !!data?.recurringGroupId;
  const week = data?.recurringWeek ?? 1;
  if (isRecurring && week > 1) {
    // Still refresh availability but skip push notifications.
    if (data?.arenaId) await refreshNextAvailable(db, data.arenaId);
    return;
  }

  const title = isRecurring
    ? "New Recurring Booking Request"
    : "New Booking Request";
  const body = isRecurring
    ? `${data?.customerName ?? "A customer"} requested ${data?.recurringTotal ?? "multiple"} recurring sessions for ${data?.courtName ?? "your court"}.`
    : `${data?.customerName ?? "A customer"} submitted a deposit for ${data?.courtName ?? "your court"}.`;

  // Idempotency key: booking_created_{bookingId} — function retries are safe.
  const idempKey = `booking_created_${event.params.bookingId}`;

  // Notify owner of new booking
  if (data?.ownerId) {
    await sendPushIdempotent(data.ownerId, title, body, "booking", event.params.bookingId, idempKey);
  }

  // Notify all staff assigned to this arena
  if (data?.arenaId) {
    await notifyArenaStaff(db, data.arenaId, title, body, "booking", event.params.bookingId);
  }

  // Refresh next-available slot for the arena
  if (data?.arenaId) {
    await refreshNextAvailable(db, data.arenaId);
  }
});

// ── Notify all arena-assigned staff of an event ───────────────────────
// Queries users where role=='staff' && assignedArenas arrayContains arenaId
// and calls sendPush for each one. Runs in parallel and never throws.
async function notifyArenaStaff(db, arenaId, title, body, type, relatedId) {
  if (!arenaId) return;
  try {
    const snap = await db.collection("users")
      .where("role", "==", "staff")
      .where("assignedArenas", "array-contains", arenaId)
      .get();
    await Promise.all(snap.docs.map((d) =>
      sendPush(d.id, title, body, type, relatedId).catch((e) =>
        console.error(`notifyArenaStaff: failed to push to ${d.id}:`, e)
      )
    ));
  } catch (e) {
    console.error("notifyArenaStaff query failed:", e);
  }
}

// ── Booking: status changed → notify customer + waitlist ──────────────
exports.onBookingUpdated = onDocumentUpdated("bookings/{bookingId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  if (before.status === after.status) return;
  const uid = after.customerId;

  // Notify the customer of their booking status change.
  // For recurring series, only send a push for week 1 to avoid N duplicate notifications.
  const isRecurring = !!after.recurringGroupId;
  const week = after.recurringWeek ?? 1;
  if (uid && (!isRecurring || week === 1)) {
    let confirmedMsg = "Your booking is confirmed! Check the details.";
    if (isRecurring && after.status === "confirmed") {
      confirmedMsg = `Your recurring booking is confirmed! ${after.recurringTotal ?? "All"} sessions starting from ${after.courtName ?? "the court"}.`;
    }
    const messages = {
      confirmed: confirmedMsg,
      rejected: isRecurring ? "Your recurring booking was rejected." : "Your booking was rejected.",
      refund_sent: "Your refund has been sent.",
      completed: "Your session is complete! How was it? Leave a review.",
    };
    const msg = messages[after.status];
    if (msg) {
      const titles = {
        confirmed: isRecurring ? "Recurring Booking Confirmed ✅" : "Booking Confirmed ✅",
        completed: "Session Complete ⭐",
      };
      // Idempotency key: booking_status_{bookingId}_{status} — retries are safe.
      const idempKey = `booking_status_${event.params.bookingId}_${after.status}`;
      await sendPushIdempotent(uid, titles[after.status] ?? "Booking Update", msg, "booking", event.params.bookingId, idempKey);
    }
  }

  // Notify arena staff — suppress for recurring weeks > 1 to avoid N duplicate staff pushes.
  if (after.arenaId && (!isRecurring || week === 1)) {
    const db2 = admin.firestore();
    const staffTitles = {
      deposit_submitted: "New Deposit Submitted",
      confirmed: "Booking Approved",
      rejected: "Booking Rejected",
      cancelled: "Booking Cancelled",
      refund_pending: "Refund Requested",
      refund_confirmed: "Refund Confirmed by Customer",
      completed: "Session Completed",
    };
    const staffBodies = {
      deposit_submitted: `${after.customerName ?? "A customer"} submitted a deposit for ${after.courtName ?? "a court"}.`,
      confirmed: `${after.customerName ?? "A customer"}'s booking for ${after.courtName ?? "a court"} was approved.`,
      rejected: `${after.customerName ?? "A customer"}'s booking for ${after.courtName ?? "a court"} was rejected.`,
      cancelled: `${after.customerName ?? "A customer"} cancelled their booking for ${after.courtName ?? "a court"}.`,
      refund_pending: `${after.customerName ?? "A customer"} requested a refund for ${after.courtName ?? "a court"}.`,
      refund_confirmed: `${after.customerName ?? "A customer"} confirmed the refund for ${after.courtName ?? "a court"}.`,
      completed: `Session for ${after.customerName ?? "a customer"} at ${after.courtName ?? "a court"} is complete.`,
    };
    const staffTitle = staffTitles[after.status];
    const staffBody = staffBodies[after.status];
    if (staffTitle && staffBody) {
      await notifyArenaStaff(db2, after.arenaId, staffTitle, staffBody, "booking", event.params.bookingId);
    }
  }

  // When a booking slot becomes available, notify waitlisted customers
  if (after.status === "cancelled" || after.status === "rejected") {
    const db = admin.firestore();
    const hoursRange = Array.from(
      { length: after.totalHours ?? 1 },
      (_, i) => (after.startHour ?? 0) + i
    );
    const waitlistSnap = await db.collection("waitlist")
      .where("arenaId", "==", after.arenaId)
      .where("courtId", "==", after.courtId)
      .where("date", "==", after.date)
      .get();
    const affected = waitlistSnap.docs.filter(d =>
      hoursRange.includes(d.data().hour)
    );
    await Promise.all(affected.map(d =>
      sendPush(
        d.data().customerId,
        "Slot Available! 🎉",
        `A slot at ${after.arenaName ?? "your waitlisted arena"} just opened up. Book before it's gone!`
      )
    ));
  }

  // Mirror the status change into the linked chat:
  //  - pair chats (pairKey) get a system message so both parties see the
  //    event inline; the pinned banner itself streams bookings live.
  //  - all chats get a bookingSnapshot refresh — the chat-list status chip
  //    reads it, and it's the only live source for legacy chats.
  try {
    const db = admin.firestore();
    const pricePerHour = after.pricePerHour ?? 0;
    const totalHours = after.totalHours ?? 0;
    const totalAmount = after.totalAmount ?? (pricePerHour * totalHours);
    const startHour = after.startHour ?? 0;
    const fmt = h => `${String(h % 24).padStart(2, "0")}:00`;
    const timeRange = `${fmt(startHour)} – ${fmt(startHour + totalHours)}`;

    // Booking dates are stored as local (Pakistan) midnight; format in that
    // zone or the UTC render shifts to the previous day.
    let dateLabel = "";
    if (after.date?.toDate) {
      dateLabel = after.date.toDate()
        .toLocaleDateString("en-GB", {
          weekday: "short", day: "numeric", month: "short",
          timeZone: "Asia/Karachi",
        })
        .replace(",", "");
    }

    // Canonical pair chat first, legacy per-booking chat as fallback.
    let chatDoc = null;
    let isPair = false;
    if (after.arenaId && after.customerId) {
      const pairSnap = await db.collection("chats")
        .where("pairKey", "==", `${after.arenaId}_${after.customerId}`)
        .limit(1)
        .get();
      if (!pairSnap.empty) {
        chatDoc = pairSnap.docs[0];
        isPair = true;
      }
    }
    if (!chatDoc) {
      const legacySnap = await db.collection("chats")
        .where("bookingId", "==", event.params.bookingId)
        .limit(1)
        .get();
      if (!legacySnap.empty) chatDoc = legacySnap.docs[0];
    }

    if (chatDoc) {
      const systemTexts = {
        deposit_submitted: "Deposit submitted — awaiting approval",
        confirmed: "Booking approved ✅",
        rejected: "Booking rejected",
        cancelled: "Booking cancelled",
        completed: "Session completed",
        refund_pending: "Refund requested",
        refund_sent: "Refund sent by owner",
        refund_confirmed: "Refund confirmed by customer",
      };
      const text = systemTexts[after.status];

      const batch = db.batch();

      if (isPair && text) {
        const context = [after.courtName, dateLabel].filter(Boolean).join(" · ");
        const content = context ? `${text} — ${context}` : text;
        batch.set(chatDoc.ref.collection("messages").doc(), {
          senderId: "system",
          senderRole: "system",
          type: "system",
          content,
          isRead: true,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          bookingRef: {
            bookingId: event.params.bookingId,
            courtName: after.courtName ?? "",
            dateLabel,
            timeRange,
          },
        });
        const chatUpdates = {
          lastMessage: content,
          lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
        };
        for (const p of chatDoc.data().participants ?? []) {
          chatUpdates[`unreadCounts.${p}`] =
            admin.firestore.FieldValue.increment(1);
        }
        batch.update(chatDoc.ref, chatUpdates);
      }

      batch.set(chatDoc.ref, {
        bookingSnapshot: {
          arenaName: after.arenaName ?? "",
          courtName: after.courtName ?? "",
          date: after.date || null,
          timeRange,
          totalAmount,
          depositAmount: totalAmount * 0.3,
          status: after.status,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      }, { merge: true });

      await batch.commit();
    }
  } catch (e) {
    console.error("chat status mirror failed:", e);
  }

  // Refresh next-available slot for the arena
  try {
    const db2 = admin.firestore();
    if (after.arenaId) await refreshNextAvailable(db2, after.arenaId);
  } catch (e) {
    console.error("refreshNextAvailable failed:", e);
  }
});

// ── Auto-transition bookings every 30 minutes ──────────────────────────
exports.autoTransitionBookings = onSchedule("every 30 minutes", async () => {
  const db = admin.firestore();
  const now = new Date();
  const todayTs = admin.firestore.Timestamp.fromDate(now);
  const batch = db.batch();
  let ops = 0;

  function endMs(data) {
    // The client stores `date` as local midnight (Timestamp.fromDate of a
    // y/m/d DateTime), so the timestamp itself is the booking day's start
    // instant. Recomputing midnight in the server's timezone (UTC) shifted
    // the end time by the UTC offset — add the hours to the raw instant.
    return data.date.toDate().getTime() +
      (data.startHour + data.totalHours) * 3600000 +
      (data.extensionMinutes || 0) * 60000;
  }

  // confirmed + ongoing → completed
  // `confirmed` = approved but not yet checked in (may be a no-show)
  // `ongoing`   = checked in via QR scan; session is now over
  for (const queryStatus of ["confirmed", "ongoing"]) {
    const snap = await db.collection("bookings")
      .where("status", "==", queryStatus)
      .where("date", "<=", todayTs)
      .get();

    for (const doc of snap.docs) {
      if (endMs(doc.data()) <= now.getTime()) {
        batch.update(doc.ref, {
          status: "completed",
          completedAt: admin.firestore.FieldValue.serverTimestamp(),
          // Only mark no-show when there was never a check-in.
          ...(doc.data().checkedIn ? {} : { noShow: true }),
        });
        ops++;
      }
    }
  }

  // pending_deposit / deposit_submitted → rejected (expired)
  for (const pendingStatus of ["pending_deposit", "deposit_submitted"]) {
    const snap = await db.collection("bookings")
      .where("status", "==", pendingStatus)
      .where("date", "<=", todayTs)
      .get();
    for (const doc of snap.docs) {
      if (endMs(doc.data()) <= now.getTime()) {
        batch.update(doc.ref, {
          status: "rejected",
          rejectionReason: "expired",
          rejectedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        ops++;
      }
    }
  }

  if (ops > 0) await batch.commit();
  console.log(`autoTransitionBookings: ${ops} bookings updated.`);
});

// ── Chat: new message → notify the other party ──────────────────────
// All six chat flows (customer↔owner, customer↔admin, owner↔admin) use
// type="chat" in the payload so the Flutter handler opens the correct
// chat room directly.  Admin recipients get isAdminChat="true" so the
// app knows to open adminChatView instead of chatRoom.
exports.onChatMessageCreated = onDocumentCreated("chats/{chatId}/messages/{msgId}", async (event) => {
  const msg = event.data.data();
  if (!msg || msg.type === "system" || msg.senderRole === "system") return;

  const db = admin.firestore();
  const chatId = event.params.chatId;
  const chatSnap = await db.collection("chats").doc(chatId).get();
  if (!chatSnap.exists) return;
  const chat = chatSnap.data();

  const preview = typeof msg.content === "string"
    ? msg.content.substring(0, 60)
    : "Sent a message";
  const senderName = msg.senderName ?? "Someone";
  const senderRole = msg.senderRole ?? "customer";
  const senderId = msg.senderId ?? "";

  // ── Flow 1 & 2: Booking chat (customer ↔ owner / staff) ──────────
  if (chat.type === "booking" || chat.arenaId) {
    if (senderRole === "customer") {
      // Customer → Owner/Staff
      const title = `New message from ${senderName}`;
      if (chat.ownerId) {
        await sendPush(chat.ownerId, title, preview, "chat", chatId);
      }
      if (chat.arenaId) {
        await notifyArenaStaff(db, chat.arenaId, title, preview, "chat", chatId);
      }
    } else {
      // Owner/Staff → Customer
      const title = `Reply from ${senderName}`;
      if (chat.customerId) {
        await sendPush(chat.customerId, title, preview, "chat", chatId);
      }
    }
    return;
  }

  // ── Flows 3–6: Support chat (customer/owner ↔ admin) ─────────────
  // chat.type is "owner_support" or "customer_support".
  // participants = [raiserId] initially; admins join by being the senderId.
  if (chat.type === "owner_support" || chat.type === "customer_support" || chat.type === "support") {
    const participants = chat.participants ?? [];

    if (senderRole === "admin" || senderRole === "superAdmin") {
      // Admin/SuperAdmin → Customer or Owner
      // The raiser is the only non-admin participant.
      const raiser = participants.find((p) => p !== senderId);
      if (raiser) {
        await sendPush(raiser, `Reply from Support`, preview, "chat", chatId);
      }
    } else {
      // Customer or Owner → Admin/SuperAdmin
      // Notify every admin + superAdmin user so any available admin can respond.
      const adminRoles = ["admin", "superAdmin", "operationsManager", "supportAgent"];
      const adminsSnap = await db.collection("users")
        .where("role", "in", adminRoles)
        .get();
      await Promise.all(adminsSnap.docs
        .filter((d) => d.id !== senderId) // don't self-notify
        .map((d) =>
          sendPush(
            d.id,
            `Support message from ${senderName}`,
            preview,
            "chat",
            chatId,
            { isAdminChat: "true" }, // Flutter opens adminChatView for this flag
          )
        )
      );
    }
    return;
  }
});

// ── Arena: new review → recalculate average rating ────────────────────
exports.onReviewCreated = onDocumentCreated("arenas/{arenaId}/reviews/{reviewId}", async (event) => {
  const { arenaId } = event.params;
  const db = admin.firestore();

  const snap = await db.collection("arenas").doc(arenaId).collection("reviews").get();
  const ratings = snap.docs.map((d) => d.data().rating ?? 0);
  const avg = ratings.length > 0
    ? ratings.reduce((a, b) => a + b, 0) / ratings.length
    : 0;

  await db.collection("arenas").doc(arenaId).update({
    rating: Math.round(avg * 10) / 10,
    reviewCount: ratings.length,
  });

  // Notify the arena owner
  const arenaSnap = await db.collection("arenas").doc(arenaId).get();
  const ownerId = arenaSnap.data()?.ownerId;
  const reviewData = event.data.data();
  if (ownerId) {
    await sendPush(
      ownerId,
      "New Review ⭐",
      `Your arena received a ${reviewData.rating}★ review.`
    );
  }
});

// ── Arena: new arena pending approval → notify admin ──────────────────
exports.onArenaCreated = onDocumentCreated("arenas/{arenaId}", async (event) => {
  const data = event.data.data();
  // Notify all admins
  const adminsSnap = await admin.firestore()
    .collection("users")
    .where("role", "==", "admin")
    .get();
  await Promise.all(
    adminsSnap.docs.map((d) =>
      sendPush(d.id, "New Arena Pending", `${data?.name ?? "An arena"} is awaiting approval.`)
    )
  );
});

// ── Account deletion (GDPR / App Store compliance) ───────────────────
// Called by the app with a valid Firebase ID token in the Authorization
// header. Deletes Firebase Auth user, anonymizes Firestore docs, removes
// Storage avatar. Pending bookings are cancelled; confirmed bookings are
// left intact for owner records but customer PII is anonymised.
exports.deleteAccount = onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
  if (req.method === "OPTIONS") { res.status(204).send(""); return; }
  if (req.method !== "POST") { res.status(405).json({ success: false, message: "Method not allowed." }); return; }

  // Verify the caller's Firebase ID token.
  const authHeader = req.headers.authorization || "";
  const idToken = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : null;
  if (!idToken) {
    return res.status(401).json({ success: false, message: "Missing auth token." });
  }

  let decodedToken;
  try {
    decodedToken = await admin.auth().verifyIdToken(idToken);
  } catch (_) {
    return res.status(401).json({ success: false, message: "Invalid or expired token." });
  }

  const uid = decodedToken.uid;
  const db  = admin.firestore();

  try {
    // 1. Cancel any pending/deposit-submitted bookings so slots are freed.
    const pendingStatuses = ["pending_deposit", "deposit_submitted"];
    const bookingSnap = await db.collection("bookings")
      .where("customerId", "==", uid)
      .where("status", "in", pendingStatuses)
      .get();
    const batch = db.batch();
    for (const doc of bookingSnap.docs) {
      batch.update(doc.ref, {
        status: "cancelled",
        "cancellation.requestedAt": admin.firestore.FieldValue.serverTimestamp(),
        "cancellation.reason": "account_deleted",
      });
    }
    await batch.commit();

    // 2. Anonymize the Firestore user document — keep uid for referential
    //    integrity in bookings/chats, but remove all PII.
    await db.collection("users").doc(uid).set({
      uid,
      name: "Deleted User",
      email: "",
      phone: "",
      avatar: "",
      role: "customer",
      isActive: false,
      fcmToken: admin.firestore.FieldValue.delete(),
      fcmTokens: admin.firestore.FieldValue.delete(),
      deletedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: false });

    // 3. Delete Storage avatar (best-effort — path may not exist).
    try {
      const bucket = getStorage().bucket();
      await bucket.deleteFiles({ prefix: `avatars/${uid}/` });
    } catch (_) { /* no avatar to delete */ }

    // 4. Delete the Firebase Auth account — this invalidates all tokens.
    await admin.auth().deleteUser(uid);

    return res.status(200).json({ success: true, message: "Account deleted." });
  } catch (error) {
    console.error("deleteAccount error:", error);
    return res.status(500).json({ success: false, message: "Failed to delete account." });
  }
});

// ── Home screen summary — CDN-cached, no auth required ───────────────
// Returns featured arenas + 20 newest approved arenas for the initial home
// load. Cache-Control instructs CDN / Firebase Hosting to cache the response
// for 5 minutes (s-maxage=300) and serve stale for up to 10 minutes while
// revalidating in the background (stale-while-revalidate=600).
exports.homeScreenSummary = onRequest(async (req, res) => {
  res.set(
    "Cache-Control",
    "public, s-maxage=300, stale-while-revalidate=600"
  );
  try {
    const db = admin.firestore();
    const [featuredSnap, recentSnap] = await Promise.all([
      db.collection("arenas")
        .where("status", "==", "approved")
        .where("isActive", "==", true)
        .where("isFeatured", "==", true)
        .orderBy("createdAt", "desc")
        .limit(5)
        .get(),
      db.collection("arenas")
        .where("status", "==", "approved")
        .where("isActive", "==", true)
        .orderBy("createdAt", "desc")
        .limit(20)
        .get(),
    ]);

    const toArena = (doc) => {
      const data = doc.data();
      // Strip sensitive/heavy fields before sending to client.
      const { position, ...safe } = data;
      return { id: doc.id, ...safe };
    };

    res.json({
      success: true,
      featured: featuredSnap.docs.map(toArena),
      recent: recentSnap.docs.map(toArena),
      generatedAt: Date.now(),
    });
  } catch (e) {
    console.error("homeScreenSummary error:", e);
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── nextAvailableSlot — compute and denormalize onto arena doc ────────

const CANCELLED_STATUSES = new Set([
  "cancelled", "rejected", "refund_pending", "refund_sent", "refund_confirmed",
]);

async function computeNextAvailableSlot(db, arenaId) {
  const courtsSnap = await db
    .collection("arenas").doc(arenaId)
    .collection("courts")
    .where("isActive", "==", true)
    .get();

  if (courtsSnap.empty) return null;

  const courts = courtsSnap.docs.map((d) => {
    const data = d.data();
    const startStr = data.startTime || "08:00";
    const endStr   = data.endTime   || "23:00";
    return {
      id: d.id,
      startHour: parseInt(startStr.split(":")[0], 10),
      endHour:   parseInt(endStr.split(":")[0], 10),
    };
  });

  const now   = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());

  for (let dayOffset = 0; dayOffset < 7; dayOffset++) {
    const date = new Date(today);
    date.setDate(today.getDate() + dayOffset);

    const pad  = (n) => String(n).padStart(2, "0");
    const dateKey = `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
    const minHour = dayOffset === 0 ? now.getHours() + 1 : 0;

    const dayStart = new Date(date);
    const dayEnd   = new Date(date);
    dayEnd.setDate(dayEnd.getDate() + 1);

    const [bookingsSnap, blockedSnap] = await Promise.all([
      db.collection("bookings")
        .where("arenaId", "==", arenaId)
        .where("date", ">=", admin.firestore.Timestamp.fromDate(dayStart))
        .where("date", "<",  admin.firestore.Timestamp.fromDate(dayEnd))
        .get(),
      db.collection("blockedSlots")
        .where("arenaId", "==", arenaId)
        .where("dateKey", "==", dateKey)
        .get(),
    ]);

    // Build occupied-hours maps
    const booked  = {};
    const blocked = {};

    for (const doc of bookingsSnap.docs) {
      const d = doc.data();
      if (CANCELLED_STATUSES.has(d.status)) continue;
      const cid   = d.courtId;
      const start = d.startHour  || 0;
      const dur   = d.totalHours || 1;
      if (!booked[cid]) booked[cid] = new Set();
      for (let h = start; h < start + dur; h++) booked[cid].add(h);
    }

    for (const doc of blockedSnap.docs) {
      const d   = doc.data();
      const cid = d.courtId;
      if (!blocked[cid]) blocked[cid] = new Set();
      blocked[cid].add(d.hour);
    }

    // Find earliest free hour across courts
    for (const court of courts) {
      const startH = Math.max(court.startHour, minHour);
      for (let h = startH; h < court.endHour; h++) {
        if (!(booked[court.id]?.has(h)) && !(blocked[court.id]?.has(h))) {
          const slotTime = new Date(date);
          slotTime.setHours(h, 0, 0, 0);
          return admin.firestore.Timestamp.fromDate(slotTime);
        }
      }
    }
  }

  return null;
}

async function refreshNextAvailable(db, arenaId) {
  if (!arenaId) return;
  const slot = await computeNextAvailableSlot(db, arenaId);
  await db.collection("arenas").doc(arenaId).update({
    nextAvailableSlot: slot,
  });
}

exports.onBlockedSlotCreated = onDocumentCreated("blockedSlots/{slotId}", async (event) => {
  const db      = admin.firestore();
  const arenaId = event.data.data().arenaId;
  await refreshNextAvailable(db, arenaId);
});

exports.onBlockedSlotDeleted = onDocumentDeleted("blockedSlots/{slotId}", async (event) => {
  const db      = admin.firestore();
  const arenaId = event.data.data().arenaId;
  await refreshNextAvailable(db, arenaId);
});

// ── Booking reminders: T-24h and T-1h push to customer ───────────────
//
// Runs every 30 minutes. For each reminder window we use a ±35-minute
// band around the target lead time so no booking falls between two runs.
// Idempotency flags (remindedAt24h / remindedAt1h) prevent double-sends
// if the same booking is caught in overlapping windows.

exports.sendBookingReminders = onSchedule("every 30 minutes", async () => {
  const db  = admin.firestore();
  const now = Date.now(); // ms

  // Helper: booking start time in ms.
  // Bookings store `date` as local-midnight Timestamp; startHour is added on top.
  const startMs = (data) =>
    data.date.toDate().getTime() + (data.startHour || 0) * 3_600_000;

  // Helper: human-readable time string, e.g. "14:00".
  const fmtHour = (h) => `${String(h).padStart(2, "0")}:00`;

  const WINDOW_MS = 35 * 60 * 1000; // 35 minutes either side

  const targets = [
    { leadMs: 24 * 3_600_000, flag: "remindedAt24h", label: "24 hours" },
    { leadMs:  1 * 3_600_000, flag: "remindedAt1h",  label: "1 hour"   },
  ];

  // Broad date window: query confirmed bookings whose `date` falls within
  // the next 25 hours (covers both reminder windows with headroom).
  const windowStart = admin.firestore.Timestamp.fromDate(new Date(now));
  const windowEnd   = admin.firestore.Timestamp.fromDate(new Date(now + 25 * 3_600_000));

  const snap = await db.collection("bookings")
    .where("status", "==", "confirmed")
    .where("date", ">=", windowStart)
    .where("date", "<=", windowEnd)
    .get();

  let sent = 0;
  const batch = db.batch();

  for (const doc of snap.docs) {
    const data   = doc.data();
    const uid    = data.customerId;
    if (!uid) continue;

    const bookingStart = startMs(data);
    const lead         = bookingStart - now; // ms until the booking starts

    for (const { leadMs, flag, label } of targets) {
      if (data[flag]) continue; // already sent

      const diff = lead - leadMs; // ms away from this reminder's ideal send time
      if (Math.abs(diff) > WINDOW_MS) continue; // outside this run's window

      const timeStr  = fmtHour(data.startHour || 0);
      const arena    = data.arenaName || "your arena";
      const court    = data.courtName || "";
      const courtStr = court ? ` (${court})` : "";

      await sendPush(
        uid,
        `Booking in ${label}`,
        `Your booking at ${arena}${courtStr} starts at ${timeStr}. See you there!`,
        "booking_reminder",
        doc.id,
      );

      batch.update(doc.ref, {
        [flag]: admin.firestore.FieldValue.serverTimestamp(),
      });
      sent++;
    }
  }

  if (sent > 0) await batch.commit();
  console.log(`sendBookingReminders: ${sent} reminders sent.`);
});

// ── Extension request created → notify owner ─────────────────────────
exports.onExtensionRequestCreated = onDocumentCreated("extensionRequests/{reqId}", async (event) => {
  const data = event.data.data();
  if (!data) return;
  const ownerId = data.ownerId;
  const customerName = data.customerName ?? "A customer";
  const mins = data.extensionMinutes ?? 0;
  const courtName = data.courtName ?? "the court";
  if (ownerId) {
    await sendPush(
      ownerId,
      "Extension Request ⏱",
      `${customerName} wants +${mins} min on ${courtName}. Tap to approve or reject.`,
      "extension_request",
      event.params.reqId,
    );
  }
});

// ── Tournament registration payment verified → notify customer ────────
exports.onRegistrationUpdated = onDocumentUpdated("registrations/{regId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  if (before.paymentStatus === after.paymentStatus) return;
  const uid = after.userId;
  if (!uid) return;
  if (after.paymentStatus === "verified") {
    await sendPush(uid, "Registration Confirmed", "Your tournament registration payment has been verified. You're in!");
  } else if (after.paymentStatus === "rejected") {
    await sendPush(uid, "Registration Rejected", "Your tournament registration payment was rejected. Please resubmit.");
  }
});

// ── Expire stale invitations + archive orphaned arenas ────────────────────
// Runs daily. Finds `pending` owner invitations whose `expiresAt` is in the
// past, marks them expired, disables the Auth user, and archives any arena
// that was admin-created for that invitation but was never approved.
exports.expireInvitations = onSchedule("every 24 hours", async () => {
  const db = admin.firestore();
  const now = admin.firestore.Timestamp.now();

  const snap = await db.collection("ownerInvitations")
    .where("status", "==", "pending")
    .where("expiresAt", "<", now)
    .get();

  if (snap.empty) {
    console.log("expireInvitations: nothing to expire.");
    return;
  }

  let expired = 0;
  let arenasArchived = 0;

  for (const doc of snap.docs) {
    const invitationId = doc.id;
    const data = doc.data();
    const batch = db.batch();

    // Mark invitation expired.
    batch.update(doc.ref, {
      status: "expired",
      expiredAt: now,
    });

    // Disable the Auth user so they can't activate later with the stale code.
    if (data.targetUid) {
      try {
        await admin.auth().updateUser(data.targetUid, { disabled: true });
      } catch (e) {
        console.warn(`expireInvitations: could not disable user ${data.targetUid}:`, e.message);
      }
    }

    // Archive any arena created for this invitation that was never approved.
    const arenaSnap = await db.collection("arenas")
      .where("adminCreatedFor", "==", invitationId)
      .where("status", "!=", "approved")
      .get();

    for (const arenaDoc of arenaSnap.docs) {
      batch.update(arenaDoc.ref, {
        status: "archived",
        archivedReason: "invitation_expired",
        archivedAt: now,
      });
      arenasArchived++;
    }

    await batch.commit();
    expired++;

    // Audit log.
    await db.collection("audit_logs").add({
      action: "invitation_expired",
      actorUid: "system",
      actorRole: "system",
      entityType: "ownerInvitation",
      entityId: invitationId,
      targetUid: data.targetUid ?? null,
      metadata: { email: data.email, arenasArchived },
      success: true,
      timestamp: now,
    }).catch((e) => console.error("audit log write failed:", e));
  }

  console.log(`expireInvitations: ${expired} invitations expired, ${arenasArchived} arenas archived.`);
});

// ── Admin: Export audit logs as CSV ──────────────────────────────────────
exports.exportAuditLogs = onRequest({ cors: true }, async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).send("Method not allowed");
    return;
  }

  // Verify caller is admin-tier
  const authHeader = req.headers.authorization || "";
  if (!authHeader.startsWith("Bearer ")) {
    res.status(401).send("Unauthorized");
    return;
  }
  const idToken = authHeader.split("Bearer ")[1];
  let uid;
  try {
    const decoded = await admin.auth().verifyIdToken(idToken);
    uid = decoded.uid;
  } catch (e) {
    res.status(401).send("Invalid token");
    return;
  }

  const userDoc = await admin.firestore().collection("users").doc(uid).get();
  const role = userDoc.data()?.role ?? "customer";
  const adminTierRoles = [
    "admin", "superAdmin", "operationsManager",
    "supportAgent", "finance", "contentManager", "moderator", "staff"
  ];
  if (!adminTierRoles.includes(role)) {
    res.status(403).send("Forbidden");
    return;
  }

  const { action, actorRole, dateFrom, dateTo, limit = 500 } = req.body;

  let query = admin.firestore()
    .collection("audit_logs")
    .orderBy("timestamp", "desc")
    .limit(Math.min(limit, 5000));

  if (action) query = query.where("action", "==", action);
  if (actorRole) query = query.where("actorRole", "==", actorRole);
  if (dateFrom) {
    query = query.where("timestamp", ">=", new Date(dateFrom));
  }
  if (dateTo) {
    query = query.where("timestamp", "<=", new Date(dateTo));
  }

  const snap = await query.get();

  const headers = [
    "ID", "Timestamp", "Actor Name", "Actor Role", "Action",
    "Entity Type", "Entity ID", "Success", "Reason", "Error"
  ];

  const rows = snap.docs.map((doc) => {
    const d = doc.data();
    const ts = d.timestamp?.toDate?.()?.toISOString() ?? "";
    return [
      doc.id,
      ts,
      `"${(d.actorName ?? "").replace(/"/g, '""')}"`,
      d.actorRole ?? "",
      d.action ?? "",
      d.entityType ?? "",
      d.entityId ?? "",
      d.success ? "true" : "false",
      `"${(d.reason ?? "").replace(/"/g, '""')}"`,
      `"${(d.errorMessage ?? "").replace(/"/g, '""')}"`,
    ].join(",");
  });

  const csv = [headers.join(","), ...rows].join("\n");
  res.setHeader("Content-Type", "text/csv");
  res.setHeader("Content-Disposition", `attachment; filename="audit_logs_${Date.now()}.csv"`);
  res.status(200).send(csv);
});

// ── Promo: atomic claim (check maxUses + increment in one transaction) ─────────
//
// Called by BookingController.applyPromoCode() and .applyOffer() instead of
// doing the read-check-write on the client, which is a race condition.
//
// Input:  { promoId: string, bookingTotal: number }
// Output: { discount: number, code: string, title: string, scope: string }
// Throws: FAILED_PRECONDITION if promo is not valid / limit reached
//         NOT_FOUND if promo document doesn't exist
//         UNAUTHENTICATED if caller is not signed in
exports.validateAndApplyPromo = onCall({ region: "asia-south1" }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required.");

  const { promoId, bookingTotal } = request.data;
  if (!promoId || typeof bookingTotal !== "number") {
    throw new HttpsError("invalid-argument", "promoId and bookingTotal are required.");
  }

  const db = admin.firestore();
  const promoRef = db.collection("promotions").doc(promoId);

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(promoRef);
    if (!snap.exists) throw new HttpsError("not-found", "Promo code not found.");

    const p = snap.data();
    const now = new Date();

    // Status check
    if (p.status !== "active") {
      throw new HttpsError("failed-precondition", "This offer is no longer active.");
    }

    // Expiry check
    if (p.expiresAt && p.expiresAt.toDate() < now) {
      throw new HttpsError("failed-precondition", "This offer has expired.");
    }

    // Minimum booking amount check
    if (p.minBookingAmount != null && bookingTotal < p.minBookingAmount) {
      throw new HttpsError(
        "failed-precondition",
        `Minimum booking amount of Rs. ${p.minBookingAmount.toFixed(0)} required.`
      );
    }

    // maxUses check (null = unlimited)
    if (p.maxUses != null && (p.usageCount ?? 0) >= p.maxUses) {
      throw new HttpsError("failed-precondition", "This offer has reached its usage limit.");
    }

    // All checks passed — increment usage atomically
    tx.update(promoRef, { usageCount: admin.firestore.FieldValue.increment(1) });

    // Calculate discount
    let discount = 0;
    if (p.discountType === "percentage") {
      discount = bookingTotal * (p.discountValue / 100);
      if (p.maxDiscountAmount != null) discount = Math.min(discount, p.maxDiscountAmount);
    } else {
      discount = p.discountValue;
    }
    discount = Math.min(discount, bookingTotal); // never exceed total

    return {
      discount: Math.round(discount * 100) / 100,
      code: p.code,
      title: p.title,
      scope: p.scope,
    };
  });
});

// ── Promo rollback — called when booking creation fails after promo was claimed ─
// Decrements usageCount by 1 (never below 0). Idempotent — safe to call
// multiple times because the Firestore transaction reads before decrementing.
exports.rollbackPromo = onCall({ region: "asia-south1" }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required.");

  const { promoId } = request.data;
  if (!promoId) throw new HttpsError("invalid-argument", "promoId required.");

  const db = admin.firestore();
  const promoRef = db.collection("promotions").doc(promoId);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(promoRef);
    if (!snap.exists) return; // promo deleted — nothing to roll back
    const current = (snap.data().usageCount ?? 0);
    if (current <= 0) return; // already at zero
    tx.update(promoRef, { usageCount: admin.firestore.FieldValue.increment(-1) });
  });

  return { success: true };
});

// ── Expire confirmed bookings with unpaid deposits (configurable deadline) ──
// Reads settings/booking.paymentDeadlineHours (default: 24). Any booking
// that is confirmed with paymentStatus == 'deposit_accepted' and was
// confirmed more than N hours ago without amountPaid set is expired.
// This is payment-deadline enforcement — releasing slots held with no payment.
exports.expireUnpaidConfirmedBookings = onSchedule("every 60 minutes", async () => {
  const db = admin.firestore();

  // Read configurable deadline (default 24 h).
  let deadlineHours = 24;
  try {
    const settingsSnap = await db.collection("settings").doc("booking").get();
    if (settingsSnap.exists) {
      deadlineHours = settingsSnap.data().paymentDeadlineHours ?? 24;
    }
  } catch (_) { /* use default */ }

  const cutoff = new Date(Date.now() - deadlineHours * 3600 * 1000);
  const cutoffTs = admin.firestore.Timestamp.fromDate(cutoff);

  // Find confirmed bookings with deposit_accepted payment status where
  // confirmedAt is before the cutoff and amountPaid is null/unset.
  const snap = await db.collection("bookings")
    .where("status", "==", "confirmed")
    .where("paymentStatus", "==", "deposit_accepted")
    .where("confirmedAt", "<=", cutoffTs)
    .get();

  if (snap.empty) return;

  const batch = db.batch();
  let expired = 0;

  for (const doc of snap.docs) {
    const data = doc.data();
    // Skip if amountPaid is set — customer has paid.
    if (data.amountPaid != null && data.amountPaid > 0) continue;
    // Skip if the booking date has already passed — autoTransition handles those.
    const bookingDate = data.date?.toDate();
    if (bookingDate && bookingDate < new Date()) continue;

    batch.update(doc.ref, {
      status: "cancelled",
      paymentStatus: "failed",
      "cancellation.requestedAt": admin.firestore.FieldValue.serverTimestamp(),
      "cancellation.reason": "payment_deadline_expired",
    });
    expired++;

    // Notify customer.
    if (data.customerId) {
      sendPushIdempotent(
        data.customerId,
        "Booking Cancelled — Payment Deadline",
        `Your booking for ${data.courtName ?? "the court"} was cancelled because the payment deadline passed.`,
        "booking",
        doc.id,
        `payment_expired_${doc.id}`
      ).catch(() => {});
    }
  }

  if (expired > 0) await batch.commit();
  console.log(`expireUnpaidConfirmedBookings: ${expired} bookings expired.`);
});
