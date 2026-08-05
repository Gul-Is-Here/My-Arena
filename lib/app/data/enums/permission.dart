/// Every action that can be guarded by the permission system.
/// Controllers and UI check these — never check roles directly.
enum Permission {
  // ── Arena management ──────────────────────────────────────────────────
  viewArenas,
  approveArena,
  rejectArena,
  suspendArena,
  restoreArena,
  deleteArena,
  featureArena,
  manageCarousel,
  verifyArenaDocs,

  // ── Booking management ────────────────────────────────────────────────
  viewAllBookings,
  cancelAnyBooking,
  refundBooking,
  markNoShow,

  // ── User management ───────────────────────────────────────────────────
  viewUsers,
  suspendUser,
  deleteUser,
  changeUserRole,
  manageStaff,

  // ── Boost management ─────────────────────────────────────────────────
  viewBoosts,
  approveBoost,
  rejectBoost,

  // ── Ticket management ─────────────────────────────────────────────────
  viewAllTickets,
  assignTicket,
  resolveTicket,

  // ── Analytics & finance ───────────────────────────────────────────────
  viewAnalytics,
  viewFinancials,
  exportReports,

  // ── Platform settings ─────────────────────────────────────────────────
  manageSettings,
  manageCMS,

  // ── Audit logs ────────────────────────────────────────────────────────
  viewAuditLogs,
  exportAuditLogs,

  // ── Tournaments ───────────────────────────────────────────────────────
  manageTournaments,

  // ── Notifications ─────────────────────────────────────────────────────
  viewAdminNotifications,
  sendBroadcast,
}
