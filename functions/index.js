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
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

admin.initializeApp();

const verifyEmail = require("./verifyEmail");
const passwordReset = require("./passwordReset");

exports.verifyEmail = onRequest(verifyEmail);
exports.passwordReset = onRequest(passwordReset);

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
  if (!data?.ownerId) return;
  await sendPush(
    data.ownerId,
    "New Booking Request",
    `${data.customerName ?? "A customer"} submitted a deposit for ${data.courtName ?? "your court"}.`,
    "booking",
    event.params.bookingId
  );
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
