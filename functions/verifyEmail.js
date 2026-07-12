const admin = require("firebase-admin");
const crypto = require("crypto");
const { getEmailConfig } = require("./emailConfig");

const OTP_COLLECTION = "email_verification_otps";
const OTP_TTL_MS = 10 * 60 * 1000; // 10 minutes

// Simple one-way hash so plain password is never stored in Firestore.
// Server-side we pass it straight to Firebase Auth which hashes it properly.
const hashPassword = (p) =>
  crypto.createHash("sha256").update(p).digest("hex");

const verifyEmail = async (req, res) => {
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

  const { action, email, otp, name, password, role } = req.body || {};

  // ───────────────────────────────────────────────
  // ACTION: register_and_send_otp
  // ───────────────────────────────────────────────
  if (action === "register_and_send_otp") {
    try {
      // Check if user already exists
      try {
        await admin.auth().getUserByEmail(email);
        return res.status(400).json({
          success: false,
          message: "Email already registered. Please login.",
        });
      } catch (e) {
        // User doesn't exist — good to proceed
      }

      const code = Math.floor(100000 + Math.random() * 900000).toString();
      const expiresAt = Date.now() + OTP_TTL_MS;

      await admin.firestore().collection(OTP_COLLECTION).doc(email).set({
        code,
        expiresAt,
        attempts: 0,
        name,
        passwordHash: hashPassword(password), // never store plain password
        role,
        createdAt: Date.now(),
      });

      const { transporter, WEBMAIL_CONFIG } = getEmailConfig();
      await transporter.sendMail({
        from: `"${WEBMAIL_CONFIG.fromName}" <${WEBMAIL_CONFIG.email}>`,
        to: email,
        subject: "Verify Your Email Address",
        html: `
          <div style="font-family:Arial,sans-serif;max-width:480px;margin:auto;padding:30px;border:1px solid #eee;border-radius:12px;">
            <h2 style="color:#333333;">Welcome to Arena Booking and Management!</h2>
            <p style="color:#666;">Please verify your email address to complete registration.</p>
            <div style="background:#f99a03;border-radius:10px;padding:24px;text-align:center;margin:24px 0;">
              <p style="color:#fff;font-size:13px;margin:0 0 8px;">Your verification code</p>
              <h3 style="color:#fff;font-size:26px;letter-spacing:8px;margin:0;">${code}</h3>
              <p style="color:rgba(255,255,255,0.85);font-size:12px;margin:8px 0 0;">Valid for 10 minutes</p>
            </div>
            <p style="color:#666;font-size:13px;">Enter this code in the app to verify your email.</p>
            <hr style="border:none;border-top:1px solid #eee;margin:20px 0;"/>
            <p style="color:#aaa;font-size:11px;">If you didn't request this, please ignore this email.</p>
          </div>
        `,
      });

      return res.status(200).json({
        success: true,
        message: "Verification code sent to your email.",
      });
    } catch (error) {
      console.error("Send OTP error:", error);
      return res.status(500).json({
        success: false,
        message: "Failed to send verification code.",
      });
    }
  }

  // ───────────────────────────────────────────────
  // ACTION: verify_otp_and_create_user
  // ───────────────────────────────────────────────
  if (action === "verify_otp_and_create_user") {
    if (!otp) {
      return res.status(400).json({
        success: false,
        message: "Verification code is required.",
      });
    }
    if (!password) {
      return res.status(400).json({
        success: false,
        message: "Password is required.",
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
          message: "No verification code found. Please register again.",
        });
      }

      const { code, expiresAt, attempts, name, passwordHash, role } =
        otpDoc.data();

      if (Date.now() > expiresAt) {
        await otpDoc.ref.delete();
        return res.status(400).json({
          success: false,
          message: "Verification code expired. Please register again.",
        });
      }

      if (attempts >= 5) {
        await otpDoc.ref.delete();
        return res.status(400).json({
          success: false,
          message: "Too many attempts. Please register again.",
        });
      }

      // Verify OTP
      if (otp.trim() !== code) {
        await otpDoc.ref.update({ attempts: attempts + 1 });
        const remaining = 4 - attempts;
        return res.status(400).json({
          success: false,
          message: `Incorrect code. ${remaining} attempt(s) remaining.`,
        });
      }

      // Verify that the password matches the hash stored during registration
      if (hashPassword(password) !== passwordHash) {
        return res.status(400).json({
          success: false,
          message: "Invalid request.",
        });
      }

      // OTP verified — create Firebase Auth user
      const userRecord = await admin.auth().createUser({
        email: email,
        password: password,
        displayName: name,
        emailVerified: true,
      });

      // Set role as custom claim for Firestore rules
      await admin.auth().setCustomUserClaims(userRecord.uid, { role });

      // Create Firestore user doc
      await admin.firestore().collection("users").doc(userRecord.uid).set({
        uid: userRecord.uid,
        name,
        email,
        role,
        phone: "",
        avatar: "",
        isActive: true,
        emailVerified: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        lastLogin: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Clean up OTP doc
      await otpDoc.ref.delete();

      return res.status(200).json({
        success: true,
        message: "Account created successfully!",
      });
    } catch (error) {
      console.error("Verification error:", error);
      return res.status(500).json({
        success: false,
        message: "Failed to create account. Please try again.",
      });
    }
  }

  // ───────────────────────────────────────────────
  // ACTION: resend_otp
  // ───────────────────────────────────────────────
  if (action === "resend_otp") {
    try {
      const otpDoc = await admin
        .firestore()
        .collection(OTP_COLLECTION)
        .doc(email)
        .get();

      if (!otpDoc.exists) {
        return res.status(400).json({
          success: false,
          message: "No pending registration found. Please register again.",
        });
      }

      const code = Math.floor(100000 + Math.random() * 900000).toString();
      const expiresAt = Date.now() + OTP_TTL_MS;

      await otpDoc.ref.update({ code, expiresAt, attempts: 0 });

      const { transporter, WEBMAIL_CONFIG } = getEmailConfig();
      await transporter.sendMail({
        from: `"${WEBMAIL_CONFIG.fromName}" <${WEBMAIL_CONFIG.email}>`,
        to: email,
        subject: "New Verification Code",
        html: `
          <div style="font-family:Arial,sans-serif;max-width:480px;margin:auto;padding:30px;border:1px solid #eee;border-radius:12px;">
            <h2 style="color:#333333;">New Verification Code</h2>
            <div style="background:#f99a03;border-radius:10px;padding:24px;text-align:center;margin:24px 0;">
              <h1 style="color:#fff;font-size:42px;letter-spacing:10px;margin:0;">${code}</h1>
              <p style="color:rgba(255,255,255,0.85);font-size:12px;margin:8px 0 0;">Valid for 10 minutes</p>
            </div>
          </div>
        `,
      });

      return res.status(200).json({
        success: true,
        message: "New verification code sent.",
      });
    } catch (error) {
      return res.status(500).json({
        success: false,
        message: "Failed to resend code.",
      });
    }
  }

  return res.status(400).json({ success: false, message: "Invalid action." });
};

module.exports = verifyEmail;
