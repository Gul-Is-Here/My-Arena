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

const { onRequest } = require("firebase-functions/v2/https");
const { onDocumentCreated, onDocumentUpdated, onDocumentDeleted } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const { getStorage } = require("firebase-admin/storage");

admin.initializeApp();

const verifyEmail = require("./verifyEmail");
const passwordReset = require("./passwordReset");
const inviteOwner = require("./inviteOwner");
const staffManagement = require("./staffManagement");

exports.verifyEmail = onRequest(verifyEmail);
exports.passwordReset = onRequest(passwordReset);
exports.inviteOwner = onRequest({ cors: true }, inviteOwner);
exports.staffManagement = onRequest({ cors: true }, staffManagement);

// ── FCM helpers ──────────────────────────────────────────────────────

async function getToken(uid) {
  const snap = await admin.firestore().collection("users").doc(uid).get();
  return snap.data()?.fcmToken ?? null;
}

async function sendPush(uid, title, body, type = "general", relatedId = null) {
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

  const token = await getToken(uid);
  if (!token) return;
  await admin.messaging().send({
    token,
    notification: { title, body },
    data: { type, ...(relatedId ? { relatedId } : {}) },
  });
}

// ── Booking: deposit submitted → notify owner ─────────────────────────
exports.onBookingCreated = onDocumentCreated("bookings/{bookingId}", async (event) => {
  const data = event.data.data();
  const db = admin.firestore();

  // Notify owner of new booking
  if (data?.ownerId) {
    await sendPush(
      data.ownerId,
      "New Booking Request",
      `${data.customerName ?? "A customer"} submitted a deposit for ${data.courtName ?? "your court"}.`,
      "booking",
      event.params.bookingId
    );
  }

  // Refresh next-available slot for the arena
  if (data?.arenaId) {
    await refreshNextAvailable(db, data.arenaId);
  }
});

// ── Booking: status changed → notify customer + waitlist ──────────────
exports.onBookingUpdated = onDocumentUpdated("bookings/{bookingId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  if (before.status === after.status) return;
  const uid = after.customerId;

  // Notify the customer of their booking status change
  if (uid) {
    const messages = {
      confirmed: "Your booking is confirmed! Check the details.",
      rejected: "Your booking was rejected.",
      refund_sent: "Your refund has been sent.",
      completed: "Your session is complete! How was it? Leave a review.",
    };
    const msg = messages[after.status];
    if (msg) {
      const titles = { confirmed: "Booking Confirmed ✅", completed: "Session Complete ⭐" };
      await sendPush(uid, titles[after.status] ?? "Booking Update", msg, "booking", event.params.bookingId);
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
      (data.startHour + data.totalHours) * 3600000;
  }

  // confirmed → completed
  const confirmedSnap = await db.collection("bookings")
    .where("status", "==", "confirmed")
    .where("date", "<=", todayTs)
    .get();

  for (const doc of confirmedSnap.docs) {
    if (endMs(doc.data()) <= now.getTime()) {
      batch.update(doc.ref, {
        status: "completed",
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
        // Never checked in → the customer didn't show up.
        ...(doc.data().checkedIn ? {} : { noShow: true }),
      });
      ops++;
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

// ── Booking reminders: push 2 hours before confirmed bookings ─────────
// Runs every 15 min; finds bookings starting in 2h ±15min and sends a push.
exports.sendBookingReminders = onSchedule({ schedule: "every 15 minutes", timeZone: "Asia/Karachi" }, async () => {
  const db = admin.firestore();
  const now = new Date();
  const windowStart = new Date(now.getTime() + 105 * 60 * 1000); // 1h45m ahead
  const windowEnd   = new Date(now.getTime() + 135 * 60 * 1000); // 2h15m ahead

  const snap = await db.collection("bookings")
    .where("status", "==", "confirmed")
    .where("startDateTime", ">=", admin.firestore.Timestamp.fromDate(windowStart))
    .where("startDateTime", "<=", admin.firestore.Timestamp.fromDate(windowEnd))
    .get();

  let sent = 0;
  await Promise.all(snap.docs.map(async (doc) => {
    const b = doc.data();
    if (!b.customerId || b.reminderSent) return;
    const hour = b.startHour ?? 0;
    const ampm = hour >= 12 ? 'PM' : 'AM';
    const h12 = ((hour % 12) || 12);
    await sendPush(
      b.customerId,
      `⏰ Booking in 2 hours`,
      `${b.arenaName} · ${b.courtName} at ${h12}:00 ${ampm}. Don't forget your QR code!`,
      "booking_reminder",
      doc.id,
    );
    await doc.ref.update({ reminderSent: true });
    sent++;
  }));
  console.log(`sendBookingReminders: ${sent} reminders sent.`);
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
