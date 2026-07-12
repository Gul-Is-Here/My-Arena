const admin = require("firebase-admin");
const { getEmailConfig } = require("./emailConfig");

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

      const { transporter, WEBMAIL_CONFIG } = getEmailConfig();
      await transporter.sendMail({
        from: `"${WEBMAIL_CONFIG.fromName}" <${WEBMAIL_CONFIG.email}>`,
        to: email,
        subject: "Reset Your MyArena Password",
        html: `
          <div style="font-family:Arial,sans-serif;max-width:480px;margin:auto;padding:30px;border:1px solid #eee;border-radius:12px;">
            <h2 style="color:#333333;">Password Reset</h2>
            <p style="color:#666;">Use the code below to reset your MyArena password.</p>
            <div style="background:#f99a03;border-radius:10px;padding:24px;text-align:center;margin:24px 0;">
              <p style="color:#fff;font-size:13px;margin:0 0 8px;">Your reset code</p>
              <h3 style="color:#fff;font-size:26px;letter-spacing:8px;margin:0;">${code}</h3>
              <p style="color:rgba(255,255,255,0.85);font-size:12px;margin:8px 0 0;">Valid for 10 minutes</p>
            </div>
            <p style="color:#666;font-size:13px;">If you didn't request this, ignore this email.</p>
          </div>
        `,
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
