const admin = require("firebase-admin");
const { getEmailConfig } = require("./emailConfig");
const { buildEmail } = require("./emailTemplates");

const OTP_COLLECTION = "password_reset_otps";
const OTP_TTL_MS = 10 * 60 * 1000; // 10 minutes

const passwordReset = async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");
  res.set("Cache-Control", "no-store, no-cache, must-revalidate, private");
  res.set("Pragma", "no-cache");
  res.set("Expires", "0");

  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }

  const { action, email, otp, newPassword } = req.body || {};

  // ───────────────────────────────────────────────
  // ACTION: send_reset_otp
  // ───────────────────────────────────────────────
  if (action === "send_reset_otp") {
    try {
      // Only send if account exists
      try {
        await admin.auth().getUserByEmail(email);
      } catch (_) {
        return res.status(400).json({
          success: false,
          message: "No account found for this email.",
        });
      }

      const code = Math.floor(100000 + Math.random() * 900000).toString();
      const expiresAt = Date.now() + OTP_TTL_MS;

      await admin.firestore().collection(OTP_COLLECTION).doc(email).set({
        code,
        expiresAt,
        attempts: 0,
        createdAt: Date.now(),
      });

      // Detect role to apply correct portal theme
      let resetRole = "customer";
      try {
        const userRecord = await admin.auth().getUserByEmail(email);
        const userSnap = await admin.firestore().collection("users").doc(userRecord.uid).get();
        const userRole = userSnap.data()?.role ?? "customer";
        if (userRole === "owner" || userRole === "staff") resetRole = "owner";
        else if (userRole === "admin" || userRole === "superAdmin") resetRole = "admin";
      } catch (_) { /* user may not have a Firestore doc yet — default to customer */ }

      const { transporter, WEBMAIL_CONFIG } = getEmailConfig();
      await transporter.sendMail({
        from: `"${WEBMAIL_CONFIG.fromName}" <${WEBMAIL_CONFIG.email}>`,
        to: email,
        subject: "Reset your MyArena password",
        html: buildEmail({
          role: resetRole,
          headline: "Reset your password",
          bodyHtml: `
            <p style="margin:0 0 12px;">We received a request to reset your MyArena password. Enter the code below in the app to continue.</p>
            <p style="margin:0;">If this wasn't you, your account is still safe — just ignore this email.</p>
          `,
          code: { value: code, label: "Password reset code", expiry: "10 minutes" },
          footerNote: `
            🔒 <strong>Security tip:</strong> MyArena will never ask for your password over email or phone.
            If you're ever unsure, contact us at
            <a href="mailto:support@myarena.app" style="color:#374151;">support@myarena.app</a>.
          `,
          securityNote: "Didn't request a password reset? No action is needed — your account hasn't been changed.",
        }),
      });

      return res.status(200).json({
        success: true,
        message: "Password reset code sent to your email.",
      });
    } catch (error) {
      console.error("Send reset OTP error:", error);
      return res.status(500).json({
        success: false,
        message: "Failed to send reset code.",
      });
    }
  }

  // ───────────────────────────────────────────────
  // ACTION: verify_reset_otp
  // ───────────────────────────────────────────────
  if (action === "verify_reset_otp") {
    if (!otp || !newPassword) {
      return res.status(400).json({
        success: false,
        message: "Code and new password are required.",
      });
    }
    if (newPassword.length < 6) {
      return res.status(400).json({
        success: false,
        message: "Password must be at least 6 characters.",
      });
    }

    try {
      const otpDoc = await admin
        .firestore()
        .collection(OTP_COLLECTION)
        .doc(email)
        .get();

      if (!otpDoc.exists) {
        return res.status(400).json({
          success: false,
          message: "No reset code found. Please request again.",
        });
      }

      const { code, expiresAt, attempts } = otpDoc.data();

      if (Date.now() > expiresAt) {
        await otpDoc.ref.delete();
        return res.status(400).json({
          success: false,
          message: "Code expired. Please request a new one.",
        });
      }

      if (attempts >= 5) {
        await otpDoc.ref.delete();
        return res.status(400).json({
          success: false,
          message: "Too many attempts. Please request a new code.",
        });
      }

      if (otp.trim() !== code) {
        await otpDoc.ref.update({ attempts: attempts + 1 });
        const remaining = 4 - attempts;
        return res.status(400).json({
          success: false,
          message: `Incorrect code. ${remaining} attempt(s) remaining.`,
        });
      }

      // OTP verified — update password
      const user = await admin.auth().getUserByEmail(email);
      await admin.auth().updateUser(user.uid, { password: newPassword });
      await otpDoc.ref.delete();

      return res.status(200).json({
        success: true,
        message: "Password updated successfully.",
      });
    } catch (error) {
      console.error("Reset OTP verify error:", error);
      return res.status(500).json({
        success: false,
        message: "Failed to reset password.",
      });
    }
  }

  return res.status(400).json({ success: false, message: "Invalid action." });
};

module.exports = passwordReset;
