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
    UserRole.superAdmin: Permission.values.toSet(), // Full access — every permission

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
      Permission.changeAccountStatus,
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
      Permission.inviteAdmins,
      Permission.inviteOwners,
      Permission.manageAdmins,
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
      Permission.suspendUser,
      Permission.changeAccountStatus,
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
      Permission.inviteOwners,
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
  ///
  /// Layer 1: role matrix default.
  /// Layer 2: customPermissions override (true = grant, false = deny).
  bool can(Permission permission) {
    final user = Get.find<AuthController>().currentUser.value;
    if (user == null) return false;

    // Layer 2 — dynamic override wins if key present.
    final key = permission.name;
    if (user.customPermissions.containsKey(key)) {
      return user.customPermissions[key] == true;
    }

    // Layer 1 — role matrix default.
    return _matrix[user.role]?.contains(permission) ?? false;
  }

  /// Returns true if the user has ALL of the given permissions.
  bool canAll(List<Permission> permissions) => permissions.every(can);

  /// Returns true if the user has ANY of the given permissions.
  bool canAny(List<Permission> permissions) => permissions.any(can);

  /// Effective permission set after applying dynamic overrides.
  Set<Permission> get myPermissions {
    final user = Get.find<AuthController>().currentUser.value;
    if (user == null) return const {};
    return effectivePermissionsFor(user);
  }

  /// Computes effective permissions for any UserModel (used in the editor UI).
  static Set<Permission> effectivePermissionsFor(UserModel user) {
    final result = Set<Permission>.from(_matrix[user.role] ?? const <Permission>{});
    for (final entry in user.customPermissions.entries) {
      final p = _fromName(entry.key);
      if (p == null) continue;
      if (entry.value) {
        result.add(p);
      } else {
        result.remove(p);
      }
    }
    return result;
  }

  /// Default grants for a role, ignoring customPermissions.
  static Set<Permission> defaultsFor(UserRole role) =>
      Set<Permission>.from(_matrix[role] ?? const <Permission>{});

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

  static Permission? _fromName(String name) {
    try {
      return Permission.values.firstWhere((p) => p.name == name);
    } catch (_) {
      return null;
    }
  }

  UserRole get _currentRole =>
      Get.find<AuthController>().currentUser.value?.role ?? UserRole.customer;
}
