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
const admin = require("firebase-admin");

admin.initializeApp();

const verifyEmail = require("./verifyEmail");
const passwordReset = require("./passwordReset");

exports.verifyEmail = onRequest(verifyEmail);
exports.passwordReset = onRequest(passwordReset);
