/**
 * staffManagement — Owner-initiated staff onboarding and permission management.
 *
 * Actions:
 *  invite_staff          — owner invites a staff member by email + assigns arenas
 *  accept_staff_invitation — staff activates their account with the code
 *  revoke_staff_invitation — owner cancels a pending invitation
 *  update_staff_assignment — owner changes assigned arenas or suspends/reactivates
 *  request_permission    — staff requests edit_arena / edit_courts access
 *  resolve_permission    — owner approves or denies a permission request
 */

const admin = require("firebase-admin");
const crypto = require("crypto");
// Lazy-loaded inside sendStaffInviteEmail to avoid cold-start crash if emailConfig.js is absent.

const STAFF_INVITATIONS = "staffInvitations";
const STAFF_PERM_REQUESTS = "staffPermissionRequests";
const USERS = "users";
const AUDIT = "audit_logs";
const INVITE_TTL_HOURS = 168; // 7 days

function generateActivationCode() {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  return Array.from({ length: 8 }, () =>
    chars[crypto.randomInt(0, chars.length)]
  ).join("");
}

function hashCode(code) {
  return crypto.createHash("sha256").update(code).digest("hex");
}

// ── Auth helpers ────────────────────────────────────────────────────────────

const ADMIN_ROLES = ["admin", "superAdmin", "operationsManager", "supportAgent", "finance", "contentManager", "moderator"];

async function verifyOwner(req) {
  const authHeader = req.headers.authorization || "";
  if (!authHeader.startsWith("Bearer ")) return null;
  const token = authHeader.slice(7);
  try {
    const decoded = await admin.auth().verifyIdToken(token);
    const snap = await admin.firestore().collection(USERS).doc(decoded.uid).get();
    const data = snap.data();
    const role = data?.role ?? "customer";
    // Allow owners AND admin-tier roles to manage staff permissions.
    if (role !== "owner" && !ADMIN_ROLES.includes(role)) return null;
    return { uid: decoded.uid, role, name: data?.name ?? "Arena Owner" };
  } catch (_) {
    return null;
  }
}

async function verifyStaff(req) {
  const authHeader = req.headers.authorization || "";
  if (!authHeader.startsWith("Bearer ")) return null;
  const token = authHeader.slice(7);
  try {
    const decoded = await admin.auth().verifyIdToken(token);
    const snap = await admin.firestore().collection(USERS).doc(decoded.uid).get();
    const data = snap.data();
    if (!data || data.role !== "staff") return null;
    return {
      uid: decoded.uid,
      name: data.name ?? "Staff",
      ownerId: data.ownerId ?? null,
      assignedArenas: data.assignedArenas ?? [],
      arenaPermissions: data.arenaPermissions ?? {},
    };
  } catch (_) {
    return null;
  }
}

async function writeAuditLog(action, actorUid, actorRole, entityId, targetUid, metadata = {}) {
  await admin.firestore().collection(AUDIT).add({
    action,
    actorUid,
    actorRole,
    entityType: "staffInvitation",
    entityId,
    targetUid: targetUid ?? null,
    metadata,
    success: true,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });
}

async function sendStaffInviteEmail(email, staffName, ownerName, arenaNames, code) {
  const { getEmailConfig } = require("./emailConfig");
  const { buildEmail } = require("./emailTemplates");
  const { transporter, WEBMAIL_CONFIG } = getEmailConfig();
  const arenaList = arenaNames.length > 0
    ? arenaNames.map(n => `<li>${n}</li>`).join("")
    : "<li>All assigned arenas</li>";

  const html = buildEmail({
    role: "owner",
    headline: `You're invited to join ${ownerName}'s team on MyArena!`,
    bodyHtml: `
      <p style="margin:0 0 12px;">
        <strong>${ownerName}</strong> has invited you to manage their arenas on MyArena.
        You will have access to:
      </p>
      <ul style="margin:0 0 12px;padding-left:20px;">${arenaList}</ul>
      <p style="margin:0 0 12px;">
        Open the MyArena app, tap <strong>"Activate Staff Account"</strong>, and enter
        the activation code below to get started.
      </p>
    `,
    code: {
      value: code,
      label: "Staff activation code",
      expiry: "7 days",
    },
    footerNote: `
      📱 Don't have the app yet? Download MyArena from the App Store or Google Play,
      then tap <strong>"Have a staff invitation? Activate Account"</strong> on the login screen.
    `,
    securityNote: "Didn't expect this invite? You can safely ignore this email — no account will be created without the code.",
  });

  await transporter.sendMail({
    from: `"MyArena" <${WEBMAIL_CONFIG.email}>`,
    to: email,
    subject: `${ownerName} invited you to manage arenas on MyArena`,
    html,
  });
}

// ── ACTION: invite_staff ────────────────────────────────────────────────────

async function inviteStaff(db, owner, body, res) {
  const { email, assignedArenas = [], arenaNames = [] } = body;
  if (!email) {
    return res.status(400).json({ success: false, message: "email is required." });
  }
  if (!Array.isArray(assignedArenas) || assignedArenas.length === 0) {
    return res.status(400).json({ success: false, message: "At least one arena must be assigned." });
  }

  const normalizedEmail = email.trim().toLowerCase();

  // Idempotency: check for an existing pending invitation from this owner to this email
  const existingSnap = await db.collection(STAFF_INVITATIONS)
    .where("email", "==", normalizedEmail)
    .where("ownerId", "==", owner.uid)
    .where("status", "==", "pending")
    .limit(1)
    .get();

  if (!existingSnap.empty) {
    return res.status(409).json({
      success: false,
      message: "A pending invitation already exists for this email.",
      invitationId: existingSnap.docs[0].id,
    });
  }

  // Check if email already exists in Firebase Auth
  let existingUser = null;
  try {
    existingUser = await admin.auth().getUserByEmail(normalizedEmail);
  } catch (e) {
    if (e.code !== "auth/user-not-found") throw e;
  }

  const activationCode = generateActivationCode();
  const codeHash = hashCode(activationCode);
  const expiresAt = new Date(Date.now() + INVITE_TTL_HOURS * 3_600_000);
  const invitationRef = db.collection(STAFF_INVITATIONS).doc();

  if (existingUser) {
    // Existing user — link directly (same approach as owner upgrade)
    const uid = existingUser.uid;
    const userSnap = await db.collection(USERS).doc(uid).get();
    const currentRole = userSnap.data()?.role ?? "customer";

    // Don't allow inviting owners or admins
    if (["owner", "admin", "superAdmin"].includes(currentRole)) {
      return res.status(409).json({
        success: false,
        message: `Cannot invite this user as staff (they are an ${currentRole}).`,
      });
    }

    // Check if already staff under same owner
    const existingOwnerId = userSnap.data()?.ownerId;
    if (currentRole === "staff" && existingOwnerId === owner.uid) {
      return res.status(409).json({
        success: false,
        message: "This user is already staff under your account.",
      });
    }

    const batch = db.batch();
    batch.update(db.collection(USERS).doc(uid), {
      role: "staff",
      ownerId: owner.uid,
      assignedArenas,
      arenaPermissions: {},
      isActive: true,
      staffActivatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    batch.set(invitationRef, {
      email: normalizedEmail,
      ownerId: owner.uid,
      ownerName: owner.name,
      assignedArenas,
      arenaNames,
      status: "accepted",
      targetUid: uid,
      expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
      isExistingUser: true,
    });
    await batch.commit();

    await sendStaffInviteEmail(normalizedEmail, userSnap.data()?.name ?? "Staff", owner.name, arenaNames, null).catch((e) =>
      console.error("Staff upgrade email failed (non-fatal):", e)
    );

    await writeAuditLog("staff_invited_existing", owner.uid, "owner", invitationRef.id, uid, {
      email: normalizedEmail, assignedArenas,
    });

    return res.status(200).json({
      success: true,
      isExistingUser: true,
      targetUid: uid,
      invitationId: invitationRef.id,
      message: "Existing user added as staff.",
    });
  }

  // New user — create disabled account
  let newUser;
  try {
    newUser = await admin.auth().createUser({
      email: normalizedEmail,
      disabled: true,
    });
  } catch (e) {
    console.error("createUser failed:", e);
    return res.status(500).json({ success: false, message: "Failed to create account." });
  }

  const batch = db.batch();
  batch.set(db.collection(USERS).doc(newUser.uid), {
    uid: newUser.uid,
    name: "",
    email: normalizedEmail,
    phone: "",
    role: "staff",
    ownerId: owner.uid,
    assignedArenas,
    arenaPermissions: {},
    isActive: false,
    avatar: "",
    fcmToken: null,
    needsActivation: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  batch.set(invitationRef, {
    email: normalizedEmail,
    ownerId: owner.uid,
    ownerName: owner.name,
    assignedArenas,
    arenaNames,
    codeHash,
    status: "pending",
    targetUid: newUser.uid,
    expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    resendCount: 0,
    isExistingUser: false,
  });

  try {
    await batch.commit();
  } catch (e) {
    await admin.auth().deleteUser(newUser.uid).catch(() => {});
    console.error("Firestore batch failed:", e);
    return res.status(500).json({ success: false, message: "Failed to save invitation." });
  }

  try {
    await sendStaffInviteEmail(normalizedEmail, "", owner.name, arenaNames, activationCode);
  } catch (e) {
    console.error("Staff invite email failed (non-fatal):", e);
  }

  await writeAuditLog("staff_invited", owner.uid, "owner", invitationRef.id, newUser.uid, {
    email: normalizedEmail, assignedArenas,
  });

  return res.status(200).json({
    success: true,
    isExistingUser: false,
    targetUid: newUser.uid,
    invitationId: invitationRef.id,
    message: "Staff invitation sent.",
  });
}

// ── ACTION: accept_staff_invitation ─────────────────────────────────────────

async function acceptStaffInvitation(db, req, res) {
  const { email, code, password, name } = req.body || {};
  if (!email || !code || !password) {
    return res.status(400).json({ success: false, message: "email, code and password are required." });
  }
  if (password.length < 8) {
    return res.status(400).json({ success: false, message: "Password must be at least 8 characters." });
  }

  const normalizedEmail = email.trim().toLowerCase();
  const submittedHash = hashCode(code.trim().toUpperCase());

  const snap = await db.collection(STAFF_INVITATIONS)
    .where("email", "==", normalizedEmail)
    .where("status", "==", "pending")
    .limit(1)
    .get();

  if (snap.empty) {
    return res.status(404).json({ success: false, message: "No pending invitation found for this email." });
  }

  const invDoc = snap.docs[0];
  const inv = invDoc.data();

  if (inv.expiresAt.toDate() < new Date()) {
    await invDoc.ref.update({ status: "expired" });
    return res.status(410).json({ success: false, message: "Invitation has expired. Ask your owner to resend." });
  }

  if (inv.codeHash !== submittedHash) {
    return res.status(401).json({ success: false, message: "Invalid activation code." });
  }

  const uid = inv.targetUid;

  try {
    await admin.auth().updateUser(uid, {
      password,
      disabled: false,
      emailVerified: true,
      ...(name ? { displayName: name.trim() } : {}),
    });
  } catch (e) {
    console.error("updateUser failed:", e);
    return res.status(500).json({ success: false, message: "Failed to activate account." });
  }

  const batch = db.batch();
  batch.update(db.collection(USERS).doc(uid), {
    isActive: true,
    needsActivation: false,
    ...(name ? { name: name.trim() } : {}),
    activatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  batch.update(invDoc.ref, {
    status: "accepted",
    acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
    codeHash: admin.firestore.FieldValue.delete(),
  });

  try {
    await batch.commit();
  } catch (e) {
    return res.status(500).json({ success: false, message: "Account enabled but profile update failed." });
  }

  await writeAuditLog("staff_invitation_accepted", uid, "staff", invDoc.id, uid, {
    email: normalizedEmail,
  });

  return res.status(200).json({ success: true, message: "Staff account activated. You can now log in." });
}

// ── ACTION: revoke_staff_invitation ─────────────────────────────────────────

async function revokeStaffInvitation(db, owner, body, res) {
  const { invitationId } = body;
  if (!invitationId) {
    return res.status(400).json({ success: false, message: "invitationId is required." });
  }

  const invRef = db.collection(STAFF_INVITATIONS).doc(invitationId);
  const invSnap = await invRef.get();
  if (!invSnap.exists) {
    return res.status(404).json({ success: false, message: "Invitation not found." });
  }

  const inv = invSnap.data();
  if (!ADMIN_ROLES.includes(owner.role) && inv.ownerId !== owner.uid) {
    return res.status(403).json({ success: false, message: "Not your invitation." });
  }
  if (inv.status !== "pending") {
    return res.status(400).json({ success: false, message: `Cannot revoke a ${inv.status} invitation.` });
  }

  const batch = db.batch();
  batch.update(invRef, {
    status: "revoked",
    revokedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  if (inv.targetUid && !inv.isExistingUser) {
    try {
      await admin.auth().updateUser(inv.targetUid, { disabled: true });
    } catch (_) {}
    batch.update(db.collection(USERS).doc(inv.targetUid), { isActive: false });
  }

  await batch.commit();

  await writeAuditLog("staff_invitation_revoked", owner.uid, "owner", invitationId, inv.targetUid, {
    email: inv.email,
  });

  return res.status(200).json({ success: true, message: "Invitation revoked." });
}

// ── ACTION: update_staff_assignment ─────────────────────────────────────────

async function updateStaffAssignment(db, owner, body, res) {
  const { staffUid, assignedArenas, arenaNames, suspend } = body;
  if (!staffUid) {
    return res.status(400).json({ success: false, message: "staffUid is required." });
  }

  const staffRef = db.collection(USERS).doc(staffUid);
  const staffSnap = await staffRef.get();
  if (!staffSnap.exists) {
    return res.status(404).json({ success: false, message: "Staff member not found." });
  }

  const staffData = staffSnap.data();
  if (!ADMIN_ROLES.includes(owner.role) && staffData.ownerId !== owner.uid) {
    return res.status(403).json({ success: false, message: "This staff member does not belong to your team." });
  }

  const update = {};
  if (Array.isArray(assignedArenas)) {
    update.assignedArenas = assignedArenas;
    // Remove permissions for arenas no longer assigned
    const currentPerms = staffData.arenaPermissions ?? {};
    const newPerms = {};
    for (const arenaId of assignedArenas) {
      if (currentPerms[arenaId]) newPerms[arenaId] = currentPerms[arenaId];
    }
    update.arenaPermissions = newPerms;
  }
  if (typeof suspend === "boolean") {
    update.isActive = !suspend;
    if (suspend) {
      try { await admin.auth().updateUser(staffUid, { disabled: true }); } catch (_) {}
    } else {
      try { await admin.auth().updateUser(staffUid, { disabled: false }); } catch (_) {}
    }
  }

  await staffRef.update(update);

  await writeAuditLog("staff_assignment_updated", owner.uid, "owner", staffUid, staffUid, {
    assignedArenas, suspend,
  });

  return res.status(200).json({ success: true, message: "Staff assignment updated." });
}

// ── ACTION: request_permission ───────────────────────────────────────────────

async function requestPermission(db, staffUser, body, res) {
  const { arenaId, arenaName, permissions, reason } = body;
  if (!arenaId || !Array.isArray(permissions) || permissions.length === 0) {
    return res.status(400).json({ success: false, message: "arenaId and permissions are required." });
  }

  const validPerms = ["edit_arena", "edit_courts"];
  const invalid = permissions.filter(p => !validPerms.includes(p));
  if (invalid.length > 0) {
    return res.status(400).json({ success: false, message: `Invalid permissions: ${invalid.join(", ")}` });
  }

  if (!staffUser.assignedArenas.includes(arenaId)) {
    return res.status(403).json({ success: false, message: "You are not assigned to this arena." });
  }

  // Check if already has a pending request for this arena
  const existing = await db.collection(STAFF_PERM_REQUESTS)
    .where("staffUid", "==", staffUser.uid)
    .where("arenaId", "==", arenaId)
    .where("status", "==", "pending")
    .limit(1)
    .get();

  if (!existing.empty) {
    return res.status(409).json({ success: false, message: "You already have a pending request for this arena." });
  }

  const reqRef = await db.collection(STAFF_PERM_REQUESTS).add({
    staffUid: staffUser.uid,
    staffName: staffUser.name,
    ownerId: staffUser.ownerId,
    arenaId,
    arenaName: arenaName ?? "",
    permissions,
    reason: reason ?? "",
    status: "pending",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Notify owner
  if (staffUser.ownerId) {
    await admin.firestore().collection("notifications").add({
      uid: staffUser.ownerId,
      title: "Staff Permission Request",
      body: `${staffUser.name} is requesting edit access for ${arenaName ?? "an arena"}.`,
      type: "staff_permission",
      relatedId: reqRef.id,
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }).catch(e => console.error("Notification write failed:", e));
  }

  return res.status(200).json({ success: true, requestId: reqRef.id, message: "Permission request sent to your owner." });
}

// ── ACTION: resolve_permission ───────────────────────────────────────────────

async function resolvePermission(db, owner, body, res) {
  const { requestId, approved } = body;
  if (!requestId || typeof approved !== "boolean") {
    return res.status(400).json({ success: false, message: "requestId and approved are required." });
  }

  const reqRef = db.collection(STAFF_PERM_REQUESTS).doc(requestId);
  const reqSnap = await reqRef.get();
  if (!reqSnap.exists) {
    return res.status(404).json({ success: false, message: "Permission request not found." });
  }

  const req = reqSnap.data();
  if (!ADMIN_ROLES.includes(owner.role) && req.ownerId !== owner.uid) {
    return res.status(403).json({ success: false, message: "This request does not belong to your team." });
  }
  if (req.status !== "pending") {
    return res.status(400).json({ success: false, message: `Request already ${req.status}.` });
  }

  const batch = db.batch();
  batch.update(reqRef, {
    status: approved ? "approved" : "denied",
    resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
    resolvedBy: owner.uid,
  });

  if (approved) {
    // Merge new permissions into arenaPermissions map
    const staffRef = db.collection(USERS).doc(req.staffUid);
    const staffSnap = await staffRef.get();
    const existing = staffSnap.data()?.arenaPermissions ?? {};
    const current = existing[req.arenaId] ?? [];
    const merged = [...new Set([...current, ...req.permissions])];
    batch.update(staffRef, {
      [`arenaPermissions.${req.arenaId}`]: merged,
    });
  }

  await batch.commit();

  // Notify staff member
  await admin.firestore().collection("notifications").add({
    uid: req.staffUid,
    title: approved ? "Permission Granted ✅" : "Permission Request Denied",
    body: approved
      ? `You now have edit access for ${req.arenaName}.`
      : `Your request for ${req.arenaName} was denied by your owner.`,
    type: "staff_permission",
    relatedId: requestId,
    read: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  }).catch(e => console.error("Notification write failed:", e));

  return res.status(200).json({ success: true, message: approved ? "Permission granted." : "Request denied." });
}

// ── ACTION: revoke_permission ────────────────────────────────────────────────

async function revokePermission(db, owner, body, res) {
  const { staffUid, arenaId, permission } = body;
  if (!staffUid || !arenaId || !permission) {
    return res.status(400).json({ success: false, message: "staffUid, arenaId and permission are required." });
  }

  const staffRef = db.collection(USERS).doc(staffUid);
  const staffSnap = await staffRef.get();
  if (!staffSnap.exists) {
    return res.status(404).json({ success: false, message: "Staff member not found." });
  }

  const staffData = staffSnap.data();
  const callerIsAdmin = ADMIN_ROLES.includes(owner.role);
  if (!callerIsAdmin && staffData.ownerId !== owner.uid) {
    return res.status(403).json({ success: false, message: "This staff member does not belong to your team." });
  }

  const existing = staffData.arenaPermissions ?? {};
  const current = existing[arenaId] ?? [];
  const updated = current.filter(p => p !== permission);

  if (updated.length === current.length) {
    return res.status(200).json({ success: true, message: "Permission was not set." });
  }

  if (updated.length === 0) {
    // Remove the key entirely when no permissions remain for this arena
    await staffRef.update({
      [`arenaPermissions.${arenaId}`]: admin.firestore.FieldValue.delete(),
    });
  } else {
    await staffRef.update({
      [`arenaPermissions.${arenaId}`]: updated,
    });
  }

  // Notify staff
  await admin.firestore().collection("notifications").add({
    uid: staffUid,
    title: "Permission Revoked",
    body: `Your ${permission === 'edit_arena' ? 'Edit Arena' : 'Edit Courts'} access for an arena has been removed by your owner.`,
    type: "staff_permission",
    read: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  }).catch(e => console.error("Notification write failed:", e));

  return res.status(200).json({ success: true, message: "Permission revoked." });
}

// ── Router ───────────────────────────────────────────────────────────────────

const staffManagementHandler = async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
  if (req.method === "OPTIONS") { res.status(204).send(""); return; }
  if (req.method !== "POST") { res.status(405).json({ success: false, message: "Method not allowed." }); return; }

  const { action } = req.body || {};
  const db = admin.firestore();

  if (action === "accept_staff_invitation") {
    try {
      return await acceptStaffInvitation(db, req, res);
    } catch (e) {
      console.error("accept_staff_invitation error:", e);
      return res.status(500).json({ success: false, message: "Internal server error." });
    }
  }

  if (action === "request_permission") {
    const staffUser = await verifyStaff(req);
    if (!staffUser) return res.status(403).json({ success: false, message: "Staff authentication required." });
    try {
      return await requestPermission(db, staffUser, req.body, res);
    } catch (e) {
      console.error("request_permission error:", e);
      return res.status(500).json({ success: false, message: "Internal server error." });
    }
  }

  // All remaining actions require owner auth
  const owner = await verifyOwner(req);
  if (!owner) {
    return res.status(403).json({ success: false, message: "Owner authentication required." });
  }

  try {
    switch (action) {
      case "invite_staff":
        return await inviteStaff(db, owner, req.body, res);
      case "revoke_staff_invitation":
        return await revokeStaffInvitation(db, owner, req.body, res);
      case "update_staff_assignment":
        return await updateStaffAssignment(db, owner, req.body, res);
      case "resolve_permission":
        return await resolvePermission(db, owner, req.body, res);
      case "revoke_permission":
        return await revokePermission(db, owner, req.body, res);
      default:
        return res.status(400).json({ success: false, message: `Unknown action: ${action}` });
    }
  } catch (e) {
    console.error(`staffManagement [${action}] error:`, e);
    return res.status(500).json({ success: false, message: "Internal server error." });
  }
};

module.exports = staffManagementHandler;
