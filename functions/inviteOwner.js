/**
 * inviteOwner — Admin-initiated owner onboarding
 *
 * Actions:
 *  invite_owner      — create or upgrade an owner account
 *  resend_invitation — resend the activation email (rate-limited)
 *  revoke_invitation — revoke a pending invitation + archive orphaned arenas
 */

const admin = require("firebase-admin");
const crypto = require("crypto");
const { getEmailConfig } = require("./emailConfig");
const { buildEmail } = require("./emailTemplates");

const INVITATIONS = "ownerInvitations";
const USERS = "users";
const ARENAS = "arenas";
const AUDIT = "audit_logs";
const INVITE_TTL_HOURS = 72;

// Generates a human-friendly 8-char alphanumeric code (no O/0/I/l confusion)
function generateActivationCode() {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  return Array.from({ length: 8 }, () =>
    chars[crypto.randomInt(0, chars.length)]
  ).join("");
}

function hashCode(code) {
  return crypto.createHash("sha256").update(code).digest("hex");
}

// ── Helpers ───────────────────────────────────────────────────────────────

async function verifyAdmin(req) {
  const authHeader = req.headers.authorization || "";
  if (!authHeader.startsWith("Bearer ")) return null;
  const token = authHeader.slice(7);
  try {
    const decoded = await admin.auth().verifyIdToken(token);
    const userSnap = await admin.firestore().collection(USERS).doc(decoded.uid).get();
    const role = userSnap.data()?.role ?? "customer";
    const adminRoles = ["admin", "superAdmin", "operationsManager"];
    if (!adminRoles.includes(role)) return null;
    return { uid: decoded.uid, role };
  } catch (_) {
    return null;
  }
}

async function writeAuditLog(action, actorUid, actorRole, entityId, targetUid, metadata = {}) {
  await admin.firestore().collection(AUDIT).add({
    action,
    actorUid,
    actorRole,
    entityType: "invitation",
    entityId,
    targetUid: targetUid ?? null,
    metadata,
    success: true,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });
}

async function sendInviteEmail(email, name, code, isUpgrade) {
  const { transporter, WEBMAIL_CONFIG } = getEmailConfig();

  const html = isUpgrade
    ? buildEmail({
        role: "owner",
        headline: `You're now an Arena Owner, ${name}!`,
        bodyHtml: `
          <p style="margin:0 0 12px;">
            Great news — the MyArena admin team has upgraded your account to
            <strong>Arena Owner</strong>. You now have full access to the Owner Portal.
          </p>
          <p style="margin:0 0 12px;">
            Open the MyArena app and sign in with your existing credentials to access
            your Owner Dashboard and start managing your arenas.
          </p>
        `,
        footerNote: `
          💼 As an Arena Owner you can list arenas, manage bookings, view earnings, and
          communicate directly with your customers.
        `,
        securityNote: "Didn't expect this upgrade? Contact us at support@myarena.app and we'll sort it out.",
      })
    : buildEmail({
        role: "owner",
        headline: `You're invited to MyArena, ${name}!`,
        bodyHtml: `
          <p style="margin:0 0 12px;">
            The MyArena team has selected you to join as an <strong>Arena Owner</strong>.
            You'll be able to list your arenas, manage bookings, and grow your business on our platform.
          </p>
          <p style="margin:0;">
            Open the MyArena app, tap <strong>"Activate Owner Account"</strong> on the login screen,
            and enter the activation code below to get started.
          </p>
        `,
        code: {
          value: code,
          label: "Activation code",
          expiry: `${INVITE_TTL_HOURS} hours`,
        },
        footerNote: `
          📱 Don't have the app yet? Download MyArena from the App Store or Google Play,
          then tap <strong>"Have an invitation code? Activate Account"</strong> on the login screen.
        `,
        securityNote: "Didn't request an invitation? You can safely ignore this email — no account will be created without the code.",
      });

  await transporter.sendMail({
    from: `"MyArena" <${WEBMAIL_CONFIG.email}>`,
    to: email,
    subject: isUpgrade
      ? "You're now an Arena Owner on MyArena 🏟️"
      : "Your invitation to join MyArena as an Arena Owner",
    html,
  });
}

// ── ACTION: invite_owner ──────────────────────────────────────────────────

async function inviteOwner(db, adminUid, adminRole, body, res) {
  const { email, name, phone } = body;
  if (!email || !name) {
    return res.status(400).json({ success: false, message: "email and name are required." });
  }

  const normalizedEmail = email.trim().toLowerCase();

  // ── Idempotency: check for an existing pending invitation for this email ─
  const existingInviteSnap = await db.collection(INVITATIONS)
    .where("email", "==", normalizedEmail)
    .where("status", "==", "pending")
    .limit(1)
    .get();

  if (!existingInviteSnap.empty) {
    return res.status(409).json({
      success: false,
      message: "A pending invitation already exists for this email.",
      invitationId: existingInviteSnap.docs[0].id,
    });
  }

  // ── Check if email already exists in Firebase Auth ────────────────────
  let existingUser = null;
  try {
    existingUser = await admin.auth().getUserByEmail(normalizedEmail);
  } catch (e) {
    if (e.code !== "auth/user-not-found") throw e;
  }

  if (existingUser) {
    // ── Existing user upgrade path ────────────────────────────────────
    const uid = existingUser.uid;

    // Check if already an owner
    const userSnap = await db.collection(USERS).doc(uid).get();
    const currentRole = userSnap.data()?.role ?? "customer";
    if (currentRole === "owner") {
      return res.status(409).json({
        success: false,
        message: "This user is already an Arena Owner.",
      });
    }

    const invitationRef = db.collection(INVITATIONS).doc();
    const expiresAt = new Date(Date.now() + INVITE_TTL_HOURS * 3_600_000);

    const batch = db.batch();

    // Upgrade user role, preserve previous role
    batch.update(db.collection(USERS).doc(uid), {
      role: "owner",
      previousRole: currentRole,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Create invitation record (isUpgrade: true — no activation link needed)
    batch.set(invitationRef, {
      email: normalizedEmail,
      name: name.trim(),
      phone: phone?.trim() ?? "",
      invitedBy: adminUid,
      status: "accepted", // upgrade takes effect immediately
      targetUid: uid,
      arenaIds: [],
      expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
      resendCount: 0,
      isUpgrade: true,
    });

    await batch.commit();

    // Send upgrade notification email (no activation link)
    await sendInviteEmail(normalizedEmail, name.trim(), null, true).catch((e) =>
      console.error("upgrade email failed (non-fatal):", e)
    );

    await writeAuditLog("owner_upgraded", adminUid, adminRole, invitationRef.id, uid, {
      previousRole: currentRole,
      email: normalizedEmail,
    });

    return res.status(200).json({
      success: true,
      isUpgrade: true,
      targetUid: uid,
      invitationId: invitationRef.id,
      message: `Existing ${currentRole} account upgraded to owner.`,
    });
  }

  // ── New user path: create Firebase Auth account ───────────────────────
  let newUser;
  try {
    newUser = await admin.auth().createUser({
      email: normalizedEmail,
      displayName: name.trim(),
      disabled: true, // stays disabled until acceptInvitation enables it
    });
  } catch (e) {
    console.error("createUser failed:", e);
    return res.status(500).json({ success: false, message: "Failed to create account." });
  }

  // ── Generate activation code (stored as hash — plain code only in email) ─
  const activationCode = generateActivationCode();
  const codeHash = hashCode(activationCode);
  const expiresAt = new Date(Date.now() + INVITE_TTL_HOURS * 3_600_000);

  // ── Write Firestore: users doc + invitation doc (in a batch) ─────────
  const invitationRef = admin.firestore().collection(INVITATIONS).doc();
  const batch = admin.firestore().batch();

  batch.set(admin.firestore().collection(USERS).doc(newUser.uid), {
    uid: newUser.uid,
    name: name.trim(),
    email: normalizedEmail,
    phone: phone?.trim() ?? "",
    role: "owner",
    isActive: false,
    avatar: "",
    fcmToken: null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    createdBy: adminUid,
    needsActivation: true,
  });

  batch.set(invitationRef, {
    email: normalizedEmail,
    name: name.trim(),
    phone: phone?.trim() ?? "",
    invitedBy: adminUid,
    status: "pending",
    targetUid: newUser.uid,
    arenaIds: [],
    codeHash,   // plain code never stored — only the SHA-256 hash
    expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    resendCount: 0,
    isUpgrade: false,
  });

  try {
    await batch.commit();
  } catch (e) {
    // Rollback: delete the Auth user so the email can be re-invited cleanly
    await admin.auth().deleteUser(newUser.uid).catch(() => {});
    console.error("Firestore batch failed, Auth user rolled back:", e);
    return res.status(500).json({ success: false, message: "Failed to save invitation. Please try again." });
  }

  // ── Send activation email with plain code ─────────────────────────────
  try {
    await sendInviteEmail(normalizedEmail, name.trim(), activationCode, false);
  } catch (e) {
    // Non-fatal — invitation is saved; admin can resend from the UI
    console.error("Email send failed (non-fatal):", e);
  }

  await writeAuditLog("owner_invited", adminUid, adminRole, invitationRef.id, newUser.uid, {
    email: normalizedEmail,
    expiresAt: expiresAt.toISOString(),
  });

  return res.status(200).json({
    success: true,
    isUpgrade: false,
    targetUid: newUser.uid,
    invitationId: invitationRef.id,
    message: "Invitation sent successfully.",
  });
}

// ── ACTION: resend_invitation ─────────────────────────────────────────────

async function resendInvitation(db, adminUid, adminRole, body, res) {
  const { invitationId } = body;
  if (!invitationId) {
    return res.status(400).json({ success: false, message: "invitationId is required." });
  }

  const invRef = db.collection(INVITATIONS).doc(invitationId);
  const invSnap = await invRef.get();
  if (!invSnap.exists) {
    return res.status(404).json({ success: false, message: "Invitation not found." });
  }

  const inv = invSnap.data();

  if (inv.status !== "pending") {
    return res.status(400).json({ success: false, message: `Cannot resend a ${inv.status} invitation.` });
  }

  if (inv.expiresAt.toDate() < new Date()) {
    return res.status(400).json({ success: false, message: "Invitation has expired. Please revoke and create a new one." });
  }

  if (inv.isUpgrade) {
    return res.status(400).json({ success: false, message: "Upgrade invitations do not require a resend." });
  }

  // Rate limit: max 5 resends, min 60 min between resends
  if ((inv.resendCount ?? 0) >= 5) {
    return res.status(429).json({ success: false, message: "Maximum resend limit reached." });
  }
  if (inv.lastResentAt) {
    const minutesSince = (Date.now() - inv.lastResentAt.toDate().getTime()) / 60000;
    if (minutesSince < 60) {
      return res.status(429).json({
        success: false,
        message: `Please wait ${Math.ceil(60 - minutesSince)} more minutes before resending.`,
      });
    }
  }

  // Generate a fresh code and update the hash on the invitation
  const newCode = generateActivationCode();
  await invRef.update({
    codeHash: hashCode(newCode),
    resendCount: admin.firestore.FieldValue.increment(1),
    lastResentAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  try {
    await sendInviteEmail(inv.email, inv.name, newCode, false);
  } catch (e) {
    console.error("Resend email failed:", e);
    return res.status(500).json({ success: false, message: "Failed to send email." });
  }

  await writeAuditLog("invitation_resent", adminUid, adminRole, invitationId, inv.targetUid, {
    resendCount: (inv.resendCount ?? 0) + 1,
  });

  return res.status(200).json({ success: true, message: "Invitation resent." });
}

// ── ACTION: revoke_invitation ─────────────────────────────────────────────

async function revokeInvitation(db, adminUid, adminRole, body, res) {
  const { invitationId } = body;
  if (!invitationId) {
    return res.status(400).json({ success: false, message: "invitationId is required." });
  }

  const invRef = db.collection(INVITATIONS).doc(invitationId);
  const invSnap = await invRef.get();
  if (!invSnap.exists) {
    return res.status(404).json({ success: false, message: "Invitation not found." });
  }

  const inv = invSnap.data();
  if (inv.status !== "pending") {
    return res.status(400).json({ success: false, message: `Cannot revoke a ${inv.status} invitation.` });
  }

  const batch = db.batch();

  // Mark invitation revoked
  batch.update(invRef, {
    status: "revoked",
    revokedAt: admin.firestore.FieldValue.serverTimestamp(),
    revokedBy: adminUid,
  });

  // Disable the Auth account if one was created and not yet activated
  if (inv.targetUid && !inv.isUpgrade) {
    try {
      await admin.auth().updateUser(inv.targetUid, { disabled: true });
    } catch (e) {
      console.error("Could not disable auth user (non-fatal):", e);
    }

    // Archive arenas pre-created for this owner under this invitation
    const arenaSnap = await db.collection(ARENAS)
      .where("adminCreatedFor", "==", invitationId)
      .where("status", "!=", "approved")
      .get();

    for (const doc of arenaSnap.docs) {
      batch.update(doc.ref, {
        status: "archived",
        archivedAt: admin.firestore.FieldValue.serverTimestamp(),
        archivedReason: "invitation_revoked",
      });
    }
  }

  await batch.commit();

  await writeAuditLog("invitation_revoked", adminUid, adminRole, invitationId, inv.targetUid, {
    email: inv.email,
  });

  return res.status(200).json({ success: true, message: "Invitation revoked." });
}

// ── ACTION: accept_invitation ─────────────────────────────────────────────
// Called by the app (as the unauthenticated owner) with email + code.
// Validates the code, enables the Auth account, sets the password,
// activates the Firestore user doc, and marks the invitation accepted.

async function acceptInvitation(db, req, res) {
  // acceptInvitation is called by the owner (not yet logged in), so we
  // do NOT require an admin token here — just validate the code.
  const { email, code, password } = req.body || {};
  if (!email || !code || !password) {
    return res.status(400).json({ success: false, message: "email, code and password are required." });
  }
  if (password.length < 8) {
    return res.status(400).json({ success: false, message: "Password must be at least 8 characters." });
  }

  const normalizedEmail = email.trim().toLowerCase();
  const submittedHash = hashCode(code.trim().toUpperCase());

  // Find the matching pending invitation
  const snap = await db.collection(INVITATIONS)
    .where("email", "==", normalizedEmail)
    .where("status", "==", "pending")
    .limit(1)
    .get();

  if (snap.empty) {
    return res.status(404).json({ success: false, message: "No pending invitation found for this email." });
  }

  const invDoc = snap.docs[0];
  const inv = invDoc.data();

  // Check expiry
  if (inv.expiresAt.toDate() < new Date()) {
    // Mark as expired
    await invDoc.ref.update({ status: "expired" });
    return res.status(410).json({ success: false, message: "Invitation has expired. Please ask your admin for a new one." });
  }

  // Validate the code hash
  if (inv.codeHash !== submittedHash) {
    return res.status(401).json({ success: false, message: "Invalid activation code." });
  }

  const uid = inv.targetUid;

  // Enable Auth account + set password
  try {
    await admin.auth().updateUser(uid, {
      password,
      disabled: false,
      emailVerified: true,
    });
  } catch (e) {
    console.error("updateUser failed:", e);
    return res.status(500).json({ success: false, message: "Failed to activate account." });
  }

  // Activate Firestore user + mark invitation accepted
  const batch = db.batch();
  batch.update(db.collection(USERS).doc(uid), {
    isActive: true,
    needsActivation: false,
    activatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  batch.update(invDoc.ref, {
    status: "accepted",
    acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
    codeHash: admin.firestore.FieldValue.delete(), // clean up the hash
  });

  try {
    await batch.commit();
  } catch (e) {
    console.error("Activation batch failed:", e);
    return res.status(500).json({ success: false, message: "Account enabled but profile update failed. Please contact support." });
  }

  await writeAuditLog("invitation_accepted", uid, "owner", invDoc.id, uid, {
    email: normalizedEmail,
  });

  return res.status(200).json({ success: true, message: "Account activated. You can now log in." });
}

// ── Router ────────────────────────────────────────────────────────────────

const inviteOwnerHandler = async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
  if (req.method === "OPTIONS") { res.status(204).send(""); return; }
  if (req.method !== "POST") { res.status(405).json({ success: false, message: "Method not allowed." }); return; }

  const { action } = req.body || {};
  const db = admin.firestore();

  // accept_invitation is called by the unauthenticated owner — no admin token.
  if (action === "accept_invitation") {
    try {
      return await acceptInvitation(db, req, res);
    } catch (e) {
      console.error("accept_invitation error:", e);
      return res.status(500).json({ success: false, message: "Internal server error." });
    }
  }

  // All other actions require admin auth.
  const caller = await verifyAdmin(req);
  if (!caller) {
    return res.status(403).json({ success: false, message: "Forbidden. Admin access required." });
  }

  try {
    switch (action) {
      case "invite_owner":
        return await inviteOwner(db, caller.uid, caller.role, req.body, res);
      case "resend_invitation":
        return await resendInvitation(db, caller.uid, caller.role, req.body, res);
      case "revoke_invitation":
        return await revokeInvitation(db, caller.uid, caller.role, req.body, res);
      default:
        return res.status(400).json({ success: false, message: `Unknown action: ${action}` });
    }
  } catch (e) {
    console.error(`inviteOwner [${action}] error:`, e);
    return res.status(500).json({ success: false, message: "Internal server error." });
  }
};

module.exports = inviteOwnerHandler;
