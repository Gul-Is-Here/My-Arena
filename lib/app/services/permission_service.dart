import 'package:get/get.dart';

import '../data/enums/permission.dart';
import '../data/models/user_model.dart';
import '../controllers/auth_controller.dart';

/// Central permission service — maps roles to permissions.
/// Use this everywhere instead of checking `user.role == UserRole.admin`.
///
/// Example:
///   if (PermissionService.to.can(Permission.approveArena)) { ... }
class PermissionService extends GetxService {
  static PermissionService get to => Get.find();

  /// Permission matrix — every role gets an explicit set.
  static final Map<UserRole, Set<Permission>> _matrix = {
    UserRole.superAdmin: {
      // Full access — everything
      Permission.viewArenas,
      Permission.approveArena,
      Permission.rejectArena,
      Permission.suspendArena,
      Permission.restoreArena,
      Permission.deleteArena,
      Permission.featureArena,
      Permission.manageCarousel,
      Permission.verifyArenaDocs,
      Permission.viewAllBookings,
      Permission.cancelAnyBooking,
      Permission.refundBooking,
      Permission.markNoShow,
      Permission.viewUsers,
      Permission.suspendUser,
      Permission.deleteUser,
      Permission.changeUserRole,
      Permission.manageStaff,
      Permission.viewBoosts,
      Permission.approveBoost,
      Permission.rejectBoost,
      Permission.viewAllTickets,
      Permission.assignTicket,
      Permission.resolveTicket,
      Permission.viewAnalytics,
      Permission.viewFinancials,
      Permission.exportReports,
      Permission.manageSettings,
      Permission.manageCMS,
      Permission.viewAuditLogs,
      Permission.exportAuditLogs,
      Permission.manageTournaments,
      Permission.viewAdminNotifications,
      Permission.sendBroadcast,
    },

    UserRole.admin: {
      Permission.viewArenas,
      Permission.approveArena,
      Permission.rejectArena,
      Permission.suspendArena,
      Permission.restoreArena,
      Permission.deleteArena,
      Permission.featureArena,
      Permission.manageCarousel,
      Permission.verifyArenaDocs,
      Permission.viewAllBookings,
      Permission.cancelAnyBooking,
      Permission.refundBooking,
      Permission.markNoShow,
      Permission.viewUsers,
      Permission.suspendUser,
      Permission.deleteUser,
      Permission.changeUserRole,
      Permission.manageStaff,
      Permission.viewBoosts,
      Permission.approveBoost,
      Permission.rejectBoost,
      Permission.viewAllTickets,
      Permission.assignTicket,
      Permission.resolveTicket,
      Permission.viewAnalytics,
      Permission.viewFinancials,
      Permission.exportReports,
      Permission.manageSettings,
      Permission.manageCMS,
      Permission.viewAuditLogs,
      Permission.exportAuditLogs,
      Permission.manageTournaments,
      Permission.viewAdminNotifications,
      Permission.sendBroadcast,
    },

    UserRole.operationsManager: {
      Permission.viewArenas,
      Permission.approveArena,
      Permission.rejectArena,
      Permission.suspendArena,
      Permission.restoreArena,
      Permission.verifyArenaDocs,
      Permission.viewAllBookings,
      Permission.cancelAnyBooking,
      Permission.refundBooking,
      Permission.markNoShow,
      Permission.viewUsers,
      Permission.viewBoosts,
      Permission.approveBoost,
      Permission.rejectBoost,
      Permission.viewAllTickets,
      Permission.assignTicket,
      Permission.resolveTicket,
      Permission.viewAnalytics,
      Permission.viewFinancials,
      Permission.manageTournaments,
      Permission.viewAdminNotifications,
    },

    UserRole.supportAgent: {
      Permission.viewAllTickets,
      Permission.assignTicket,
      Permission.resolveTicket,
      Permission.viewUsers,
      Permission.viewAllBookings,
      Permission.viewAdminNotifications,
    },

    UserRole.finance: {
      Permission.viewAllBookings,
      Permission.refundBooking,
      Permission.viewAnalytics,
      Permission.viewFinancials,
      Permission.exportReports,
      Permission.viewAuditLogs,
    },

    UserRole.contentManager: {
      Permission.viewArenas,
      Permission.manageCMS,
      Permission.manageCarousel,
      Permission.featureArena,
      Permission.manageTournaments,
    },

    UserRole.moderator: {
      Permission.viewArenas,
      Permission.suspendArena,
      Permission.restoreArena,
      Permission.viewUsers,
      Permission.suspendUser,
      Permission.viewAllTickets,
      Permission.resolveTicket,
    },

    UserRole.staff: {
      Permission.viewAllTickets,
      Permission.viewAllBookings,
      Permission.viewUsers,
      Permission.viewAdminNotifications,
    },

    // Owners and customers have no admin permissions
    UserRole.owner: {},
    UserRole.customer: {},
  };

  /// Returns true if the currently signed-in user has [permission].
  bool can(Permission permission) {
    final role = _currentRole;
    return _matrix[role]?.contains(permission) ?? false;
  }

  /// Returns true if the user has ALL of the given permissions.
  bool canAll(List<Permission> permissions) =>
      permissions.every(can);

  /// Returns true if the user has ANY of the given permissions.
  bool canAny(List<Permission> permissions) =>
      permissions.any(can);

  /// Returns the full set of permissions for the current user.
  Set<Permission> get myPermissions =>
      _matrix[_currentRole] ?? const {};

  /// Returns true if the current user is an admin-tier role.
  bool get isAdminTier {
    final r = _currentRole;
    return r == UserRole.superAdmin ||
        r == UserRole.admin ||
        r == UserRole.operationsManager ||
        r == UserRole.supportAgent ||
        r == UserRole.finance ||
        r == UserRole.contentManager ||
        r == UserRole.moderator ||
        r == UserRole.staff;
  }

  UserRole get _currentRole =>
      Get.find<AuthController>().currentUser.value?.role ?? UserRole.customer;
}
