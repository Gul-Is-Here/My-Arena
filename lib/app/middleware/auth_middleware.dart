import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../controllers/owner_controller.dart';
import '../data/enums/permission.dart';
import '../data/models/user_model.dart';
import '../routes/app_routes.dart';
import '../services/permission_service.dart';

/// Redirects unauthenticated users to login.
class AuthMiddleware extends GetMiddleware {
  @override
  int? get priority => 1;

  @override
  RouteSettings? redirect(String? route) {
    if (!Get.find<AuthController>().isLoggedIn) {
      return const RouteSettings(name: AppRoutes.login);
    }
    return null;
  }
}

/// Allows only arena owners (or any admin-tier role) through.
class OwnerMiddleware extends GetMiddleware {
  @override
  int? get priority => 1;

  @override
  RouteSettings? redirect(String? route) {
    final auth = Get.find<AuthController>();
    if (!auth.isLoggedIn) {
      return const RouteSettings(name: AppRoutes.login);
    }
    final role = auth.currentUser.value?.role;
    if (role != UserRole.owner && !(role?.isAdminTier ?? false)) {
      return const RouteSettings(name: AppRoutes.unauthorized);
    }
    if (!Get.isRegistered<OwnerController>()) {
      Get.put(OwnerController());
    }
    return null;
  }
}

/// Allows any admin-tier role through (admin, superAdmin, operationsManager,
/// supportAgent, finance, contentManager, moderator, staff).
/// Non-admin authenticated users are sent to the Unauthorized screen — not
/// silently redirected to their own dashboard.
class AdminMiddleware extends GetMiddleware {
  @override
  int? get priority => 1;

  @override
  RouteSettings? redirect(String? route) {
    final auth = Get.find<AuthController>();
    if (!auth.isLoggedIn) {
      return const RouteSettings(name: AppRoutes.login);
    }
    final role = auth.currentUser.value?.role;
    if (!(role?.isAdminTier ?? false)) {
      return const RouteSettings(name: AppRoutes.unauthorized);
    }
    return null;
  }
}

/// Allows owners, admin-tier roles, AND arena-assigned staff.
/// Used for screens that arena staff have legitimate access to
/// (bookings, schedule, QR scanner, edit arena, edit courts).
class OwnerOrArenaStaffMiddleware extends GetMiddleware {
  @override
  int? get priority => 1;

  @override
  RouteSettings? redirect(String? route) {
    final auth = Get.find<AuthController>();
    if (!auth.isLoggedIn) {
      return const RouteSettings(name: AppRoutes.login);
    }
    final user = auth.currentUser.value;
    final role = user?.role;
    if (role == UserRole.owner ||
        (role?.isAdminTier ?? false) ||
        user?.isArenaStaff == true) {
      if (!Get.isRegistered<OwnerController>()) {
        Get.put(OwnerController());
      }
      return null;
    }
    return const RouteSettings(name: AppRoutes.unauthorized);
  }
}

/// Requires admin-tier role AND a specific permission.
/// SuperAdmins are always allowed through regardless of customPermissions.
class PermissionMiddleware extends GetMiddleware {
  final Permission permission;
  PermissionMiddleware(this.permission);

  @override
  int? get priority => 2;

  @override
  RouteSettings? redirect(String? route) {
    final auth = Get.find<AuthController>();
    if (!auth.isLoggedIn) {
      return const RouteSettings(name: AppRoutes.login);
    }
    final role = auth.currentUser.value?.role;
    if (!(role?.isAdminTier ?? false)) {
      return const RouteSettings(name: AppRoutes.unauthorized);
    }
    // SuperAdmin always passes — never blocked by permission middleware.
    if (role == UserRole.superAdmin) return null;
    if (!PermissionService.to.can(permission)) {
      return const RouteSettings(name: AppRoutes.unauthorized);
    }
    return null;
  }
}

/// Allows only arena staff through. Admin-tier roles are denied — staff and
/// admin have separate dashboards with separate route guards.
class StaffMiddleware extends GetMiddleware {
  @override
  int? get priority => 1;

  @override
  RouteSettings? redirect(String? route) {
    final auth = Get.find<AuthController>();
    if (!auth.isLoggedIn) {
      return const RouteSettings(name: AppRoutes.login);
    }
    final role = auth.currentUser.value?.role;
    if (role != UserRole.staff) {
      return const RouteSettings(name: AppRoutes.unauthorized);
    }
    return null;
  }
}
