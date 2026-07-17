/**
 * Signup email verification — send + verify a 6-digit OTP (no links).
 * Called from the app's OtpService: sendEmailOtp / verifyEmailOtp.
 */

const { onCall } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const { createAndEmailOtp, consumeOtp, requireEmail } = require("./otp_store");

exports.sendEmailOtp = onCall(async (req) => {
  const email = requireEmail(req.data);
  await createAndEmailOtp(
    email,
    "verify",
    "Your MyArena verification code",
    "Use this code to verify your email address:"
  );
  return { ok: true };
});

exports.verifyEmailOtp = onCall(async (req) => {
  const email = requireEmail(req.data);
  await consumeOtp(email, "verify", req.data?.otp);
  // Mark the Firebase Auth user's email as verified.
  try {
    const user = await admin.auth().getUserByEmail(email);
    await admin.auth().updateUser(user.uid, { emailVerified: true });
  } catch (_) {
    // User record may not exist yet in edge cases — verification still passes.
  }
  return { ok: true };
});
