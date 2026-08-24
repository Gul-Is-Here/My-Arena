/**
 * OTP send-rate limiter backed by Firestore.
 *
 * Tracks how many OTPs have been sent to a given email within the current
 * 1-hour sliding window. Rejects any request beyond the cap.
 *
 * Collection: `_otpRateLimits/{email}`
 * Fields:
 *   count      – number of OTPs sent in the current window
 *   windowStart – epoch ms when the current window opened
 */

const admin = require("firebase-admin");

const RATE_LIMIT_COLLECTION = "_otpRateLimits";
const WINDOW_MS   = 60 * 60 * 1000; // 1 hour
const MAX_PER_WINDOW = 5;

/**
 * Checks and increments the OTP send counter for the given email.
 * Returns { allowed: true } if the request is within limits.
 * Returns { allowed: false, retryAfterMs } if the limit is exceeded.
 */
async function checkOtpRateLimit(email) {
  const ref = admin.firestore()
    .collection(RATE_LIMIT_COLLECTION)
    .doc(email.toLowerCase());

  return admin.firestore().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const now  = Date.now();

    if (!snap.exists) {
      tx.set(ref, { count: 1, windowStart: now });
      return { allowed: true };
    }

    const { count = 0, windowStart = 0 } = snap.data();

    // Window expired — start a fresh one.
    if (now - windowStart >= WINDOW_MS) {
      tx.set(ref, { count: 1, windowStart: now });
      return { allowed: true };
    }

    // Within the window — check the cap.
    if (count >= MAX_PER_WINDOW) {
      const retryAfterMs = WINDOW_MS - (now - windowStart);
      return { allowed: false, retryAfterMs };
    }

    tx.update(ref, { count: count + 1 });
    return { allowed: true };
  });
}

module.exports = { checkOtpRateLimit, MAX_PER_WINDOW, WINDOW_MS };
