/**
 * OTP-based password reset — send code + verify-and-set new password.
 * Called from the app's OtpService: sendPasswordResetOtp / resetPasswordWithOtp.
 */

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const { createAndEmailOtp, consumeOtp, requireEmail } = require("./otp_store");

exports.sendPasswordResetOtp = onCall(async (req) => {
  const email = requireEmail(req.data);
  // Only send if an account actually exists.
  try {
    await admin.auth().getUserByEmail(email);
  } catch (_) {
    throw new HttpsError("not-found", "No account found for this email.");
  }
  await createAndEmailOtp(
    email,
    "reset",
    "Your MyArena password reset code",
    "Use this code to reset your password:"
  );
  return { ok: true };
});

exports.resetPasswordWithOtp = onCall(async (req) => {
  const email = requireEmail(req.data);
  const newPassword = String(req.data?.newPassword || "");
  if (newPassword.length < 6) {
    throw new HttpsError("invalid-argument", "Password must be at least 6 characters.");
  }
  await consumeOtp(email, "reset", req.data?.otp);
  const user = await admin.auth().getUserByEmail(email);
  await admin.auth().updateUser(user.uid, { password: newPassword });
  return { ok: true };
});
