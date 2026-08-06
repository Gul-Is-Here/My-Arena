/**
 * inviteAdmin — SuperAdmin/permitted-Admin initiated admin onboarding
 *
 * Actions:
 *  invite_admin      — create an admin account with a chosen role
 *  resend_invitation — resend the activation email (rate-limited)
 *  revoke_invitation — revoke a pending admin invitation
 *  accept_invitation — called by the invitee to set password and activate
 */

const admin = require("firebase-admin");
const crypto = require("crypto");
const { getEmailConfig } = require("./emailConfig");
const { buildEmail } = require("./emailTemplates");

const INVITATIONS = "adminInvitations";
const USERS = "users";
const AUDIT = "audit_logs";
const INVITE_TTL_HOURS = 72;

// Roles that can access the admin panel
const ADMIN_ROLES = [
  "admin", "superAdmin", "operationsManager", "supportAgent",
  "finance", "contentManager", "moderator",
];

// Only superAdmin can invite other admins; admin can invite lower-tier roles
const INVITABLE_ROLES = ADMIN_ROLES.filter((r) => r !== "superAdmin");

function generateActivationCode() {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  return Array.from({ length: 8 }, () =>
    chars[crypto.randomInt(0, chars.length)]
  ).join("");
}

function hashCode(code) {
  return crypto.createHash("sha256").update(code).digest("hex");
}

async function verifyInviter(req) {
  const authHeader = req.headers.authorization || "";
  if (!authHeader.startsWith("Bearer ")) return null;
  const token = authHeader.slice(7);
  try {
    const decoded = await admin.auth().verifyIdToken(token);
    const snap = await admin.firestore().collection(USERS).doc(decoded.uid).get();
    const role = snap.data()?.role ?? "customer";
    // Only admin-tier users can invite admins
    if (!ADMIN_ROLES.includes(role)) return null;
    return { uid: decoded.uid, role, data: snap.data() };
  } catch (_) {
    return null;
  }
}

async function writeAuditLog(action, actorUid, actorRole, entityId, targetUid, metadata = {}) {
  await admin.firestore().collection(AUDIT).add({
    action,
    actorUid,
    actorRole,
    entityType: "adminInvitation",
    entityId,
    targetUid: targetUid ?? null,
    metadata,
    success: true,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });
}

async function sendAdminInviteEmail(email, name, role, code) {
  const { transporter, WEBMAIL_CONFIG } = getEmailConfig();
  const roleLabel = role.replace(/([A-Z])/g, " $1").trim();

  const html = buildEmail({
    role: "admin",
    headline: `You've been invited to join MyArena as ${roleLabel}, ${name}!`,
    bodyHtml: `
      <p style="margin:0 0 12px;">
        You have been invited to join the <strong>MyArena administration team</strong>
        as a <strong>${roleLabel}</strong>.
      </p>
      <p style="margin:0;">
        Open the MyArena app, tap <strong>"Activate Admin Account"</strong> on the login screen,
        and enter the activation code below to get started.
      </p>
    `,
    code: {
      value: code,
      label: "Activation code",
      expiry: `${INVITE_TTL_HOURS} hours`,
    },
    footerNote: `
      🔐 As a ${roleLabel} you will have access to the MyArena admin panel
      with permissions appropriate to your role.
    `,
    securityNote: "Didn't request an invitation? You can safely ignore this email — no account will be created without the code.",
  });

  await transporter.sendMail({
    from: `"MyArena" <${WEBMAIL_CONFIG.email}>`,
    to: email,
    subject: `Your invitation to join MyArena as ${roleLabel}`,
    html,
  });
}

// ── ACTION: invite_admin ──────────────────────────────────────────────────

async function inviteAdmin(db, caller, body, res) {
  const { email, name, phone, role: targetRole } = body;

  if (!email || !name || !targetRole) {
    return res.status(400).json({ success: false, message: "email, name, and role are required." });
  }

  if (!INVITABLE_ROLES.includes(targetRole)) {
    return res.status(400).json({
      success: false,
      message: `Invalid role. Invitable roles: ${INVITABLE_ROLES.join(", ")}.`,
    });
  }

  // Only superAdmin can invite other admins; plain admin can only invite lower-tier roles
  const superAdminOnlyRoles = ["admin", "operationsManager"];
  if (superAdminOnlyRoles.includes(targetRole) && caller.role !== "superAdmin") {
    return res.status(403).json({
      success: false,
      message: "Only superAdmin can invite admin-tier roles.",
    });
  }

  const normalizedEmail = email.trim().toLowerCase();

  // Idempotency: no duplicate pending invitations
  const existing = await db.collection(INVITATIONS)
    .where("email", "==", normalizedEmail)
    .where("status", "==", "pending")
    .limit(1)
    .get();

  if (!existing.empty) {
    return res.status(409).json({
      success: false,
      message: "A pending admin invitation already exists for this email.",
      invitationId: existing.docs[0].id,
    });
  }

  // Check if user already exists in Firebase Auth
  let existingUser = null;
  try {
    existingUser = await admin.auth().getUserByEmail(normalizedEmail);
  } catch (e) {
    if (e.code !== "auth/user-not-found") throw e;
  }

  if (existingUser) {
    // Existing user upgrade path — set role directly, no activation needed
    const uid = existingUser.uid;
    const userSnap = await db.collection(USERS).doc(uid).get();
    const currentRole = userSnap.data()?.role ?? "customer";

    if (ADMIN_ROLES.includes(currentRole)) {
      return res.status(409).json({
        success: false,
        message: `This user is already an admin-tier member (${currentRole}).`,
      });
    }

    const invRef = db.collection(INVITATIONS).doc();
    const batch = db.batch();

    batch.update(db.collection(USERS).doc(uid), {
      role: targetRole,
      accountStatus: "active",
      previousRole: currentRole,
      invitedBy: caller.uid,
      inviterRole: caller.role,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    batch.set(invRef, {
      email: normalizedEmail,
      name: name.trim(),
      phone: phone?.trim() ?? "",
      invitedBy: caller.uid,
      inviterRole: caller.role,
      targetRole,
      status: "accepted",
      targetUid: uid,
      expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + INVITE_TTL_HOURS * 3_600_000)),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
      resendCount: 0,
      isUpgrade: true,
    });

    await batch.commit();

    await writeAuditLog("admin.invited", caller.uid, caller.role, invRef.id, uid, {
      targetRole, email: normalizedEmail, isUpgrade: true,
    });

    return res.status(200).json({
      success: true,
      isUpgrade: true,
      targetUid: uid,
      invitationId: invRef.id,
      message: `Existing account upgraded to ${targetRole}.`,
    });
  }

  // New user path
  let newUser;
  try {
    newUser = await admin.auth().createUser({
      email: normalizedEmail,
      displayName: name.trim(),
      disabled: true,
    });
  } catch (e) {
    console.error("createUser failed:", e);
    return res.status(500).json({ success: false, message: "Failed to create account." });
  }

  const activationCode = generateActivationCode();
  const codeHash = hashCode(activationCode);
  const expiresAt = new Date(Date.now() + INVITE_TTL_HOURS * 3_600_000);

  const invRef = admin.firestore().collection(INVITATIONS).doc();
  const batch = admin.firestore().batch();

  batch.set(admin.firestore().collection(USERS).doc(newUser.uid), {
    uid: newUser.uid,
    name: name.trim(),
    email: normalizedEmail,
    phone: phone?.trim() ?? "",
    role: targetRole,
    accountStatus: "pending",
    avatar: "",
    fcmToken: null,
    invitedBy: caller.uid,
    inviterRole: caller.role,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    needsActivation: true,
  });

  batch.set(invRef, {
    email: normalizedEmail,
    name: name.trim(),
    phone: phone?.trim() ?? "",
    invitedBy: caller.uid,
    inviterRole: caller.role,
    targetRole,
    status: "pending",
    targetUid: newUser.uid,
    codeHash,
    expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    resendCount: 0,
    isUpgrade: false,
  });

  try {
    await batch.commit();
  } catch (e) {
    await admin.auth().deleteUser(newUser.uid).catch(() => {});
    console.error("batch failed, auth user rolled back:", e);
    return res.status(500).json({ success: false, message: "Failed to save invitation." });
  }

  try {
    await sendAdminInviteEmail(normalizedEmail, name.trim(), targetRole, activationCode);
  } catch (e) {
    console.error("Email send failed (non-fatal):", e);
  }

  await writeAuditLog("admin.invited", caller.uid, caller.role, invRef.id, newUser.uid, {
    targetRole, email: normalizedEmail, expiresAt: expiresAt.toISOString(),
  });

  return res.status(200).json({
    success: true,
    isUpgrade: false,
    targetUid: newUser.uid,
    invitationId: invRef.id,
    message: "Admin invitation sent successfully.",
  });
}

// ── ACTION: resend_invitation ─────────────────────────────────────────────

async function resendInvitation(db, caller, body, res) {
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
    return res.status(400).json({ success: false, message: "Invitation expired. Revoke and create a new one." });
  }
  if ((inv.resendCount ?? 0) >= 5) {
    return res.status(429).json({ success: false, message: "Maximum resends reached." });
  }
  if (inv.lastResentAt) {
    const minsSince = (Date.now() - inv.lastResentAt.toDate().getTime()) / 60000;
    if (minsSince < 60) {
      return res.status(429).json({ success: false, message: "Please wait at least 60 minutes between resends." });
    }
  }

  // Generate a fresh code
  const activationCode = generateActivationCode();
  const codeHash = hashCode(activationCode);
  const expiresAt = new Date(Date.now() + INVITE_TTL_HOURS * 3_600_000);

  await invRef.update({
    codeHash,
    expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
    resendCount: admin.firestore.FieldValue.increment(1),
    lastResentAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  try {
    await sendAdminInviteEmail(inv.email, inv.name, inv.targetRole, activationCode);
  } catch (e) {
    console.error("Resend email failed (non-fatal):", e);
  }

  await writeAuditLog("admin.invitation_resent", caller.uid, caller.role, invitationId, inv.targetUid, {
    resendCount: (inv.resendCount ?? 0) + 1,
  });

  return res.status(200).json({ success: true, message: "Invitation resent." });
}

// ── ACTION: revoke_invitation ─────────────────────────────────────────────

async function revokeInvitation(db, caller, body, res) {
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
  batch.update(invRef, {
    status: "revoked",
    revokedAt: admin.firestore.FieldValue.serverTimestamp(),
    revokedBy: caller.uid,
  });
  // Disable the Auth account that was created for this invitation
  if (inv.targetUid) {
    try {
      await admin.auth().updateUser(inv.targetUid, { disabled: true });
      batch.update(db.collection(USERS).doc(inv.targetUid), {
        accountStatus: "inactive",
      });
    } catch (_) {}
  }

  await batch.commit();

  await writeAuditLog("admin.invitation_revoked", caller.uid, caller.role, invitationId, inv.targetUid, {
    email: inv.email,
  });

  return res.status(200).json({ success: true, message: "Invitation revoked." });
}

// ── ACTION: accept_invitation (called by unauthenticated invitee) ─────────

async function acceptInvitation(db, body, res) {
  const { email, code, password } = body;
  if (!email || !code || !password) {
    return res.status(400).json({ success: false, message: "email, code, and password are required." });
  }
  if (password.length < 8) {
    return res.status(400).json({ success: false, message: "Password must be at least 8 characters." });
  }

  const normalizedEmail = email.trim().toLowerCase();
  const codeHash = hashCode(code.trim().toUpperCase());

  const snap = await db.collection(INVITATIONS)
    .where("email", "==", normalizedEmail)
    .where("status", "==", "pending")
    .where("codeHash", "==", codeHash)
    .limit(1)
    .get();

  if (snap.empty) {
    return res.status(400).json({ success: false, message: "Invalid code or email. Please check and try again." });
  }

  const invRef = snap.docs[0].ref;
  const inv = snap.docs[0].data();

  if (inv.expiresAt.toDate() < new Date()) {
    return res.status(400).json({ success: false, message: "This invitation has expired. Please contact your administrator." });
  }

  const { targetUid, targetRole } = inv;

  // Enable Firebase Auth account and set password
  await admin.auth().updateUser(targetUid, {
    password,
    disabled: false,
  });

  // Activate the Firestore user doc
  await db.collection(USERS).doc(targetUid).update({
    accountStatus: "active",
    needsActivation: admin.firestore.FieldValue.delete(),
    activatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await invRef.update({
    status: "accepted",
    acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await writeAuditLog("admin.activated", targetUid, targetRole, snap.docs[0].id, targetUid, {
    email: normalizedEmail,
  });

  return res.status(200).json({ success: true, message: "Account activated. You can now sign in." });
}

// ── Handler ───────────────────────────────────────────────────────────────

const inviteAdminHandler = async (req, res) => {
  if (req.method !== "POST") {
    return res.status(405).json({ success: false, message: "Method not allowed." });
  }

  const { action } = req.body;
  if (!action) {
    return res.status(400).json({ success: false, message: "action is required." });
  }

  const db = admin.firestore();

  // accept_invitation is called without admin auth
  if (action === "accept_invitation") {
    try {
      return await acceptInvitation(db, req.body, res);
    } catch (e) {
      console.error("accept_invitation error:", e);
      return res.status(500).json({ success: false, message: "Failed to activate account." });
    }
  }

  const caller = await verifyInviter(req);
  if (!caller) {
    return res.status(401).json({ success: false, message: "Unauthorized." });
  }

  try {
    switch (action) {
      case "invite_admin":
        return await inviteAdmin(db, caller, req.body, res);
      case "resend_invitation":
        return await resendInvitation(db, caller, req.body, res);
      case "revoke_invitation":
        return await revokeInvitation(db, caller, req.body, res);
      default:
        return res.status(400).json({ success: false, message: `Unknown action: ${action}` });
    }
  } catch (e) {
    console.error(`inviteAdmin [${action}] error:`, e);
    return res.status(500).json({ success: false, message: "Internal server error." });
  }
};

module.exports = inviteAdminHandler;
