const admin = require("firebase-admin");
const crypto = require("crypto");
const { getEmailConfig } = require("./emailConfig");
const { buildEmail } = require("./emailTemplates");

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

      const emailRole = role === "owner" ? "owner" : "customer";
      const { transporter, WEBMAIL_CONFIG } = getEmailConfig();
      await transporter.sendMail({
        from: `"${WEBMAIL_CONFIG.fromName}" <${WEBMAIL_CONFIG.email}>`,
        to: email,
        subject: "Verify your email — MyArena",
        html: buildEmail({
          role: emailRole,
          headline: `Welcome to MyArena, ${name}!`,
          bodyHtml: `
            <p style="margin:0 0 12px;">Thanks for signing up. Enter the code below in the app to verify your email address and complete your registration.</p>
          `,
          code: { value: code, label: "Verification code", expiry: "10 minutes" },
          securityNote: "If you didn't create a MyArena account, you can safely ignore this email.",
        }),
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

      const resendRole = (otpDoc.data()?.role === "owner") ? "owner" : "customer";
      const { transporter, WEBMAIL_CONFIG } = getEmailConfig();
      await transporter.sendMail({
        from: `"${WEBMAIL_CONFIG.fromName}" <${WEBMAIL_CONFIG.email}>`,
        to: email,
        subject: "New verification code — MyArena",
        html: buildEmail({
          role: resendRole,
          headline: "New verification code",
          bodyHtml: `<p style="margin:0 0 4px;">Here's your new verification code. The previous one is no longer valid.</p>`,
          code: { value: code, label: "New verification code", expiry: "10 minutes" },
          securityNote: "If you didn't request this, you can safely ignore this email.",
        }),
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
