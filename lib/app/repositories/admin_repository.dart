import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../data/models/arena_model.dart';
import '../data/models/audit_log_model.dart';
import '../data/models/boost_request_model.dart';
import '../data/models/user_model.dart';
import '../services/audit_service.dart';
import '../services/arena_service.dart';
import '../services/boost_service.dart';

/// Single source of truth for all admin write operations.
/// Every method persists to Firestore AND writes an audit log automatically.
/// Controllers call this — they never call Firestore directly for writes.
class AdminRepository {
  final _db = FirebaseFirestore.instance;
  final _arenaService = ArenaService();
  final _boostService = BoostService();

  AuditService get _audit => Get.find<AuditService>();

  // ── Arena management ──────────────────────────────────────────────────

  Future<void> setArenaStatus(
    String arenaId,
    ArenaStatus status,
    String arenaName, {
    String? reason,
  }) async {
    try {
      await _arenaService.setStatus(arenaId, status, rejectionReason: reason);
      await _audit.log(
        action: switch (status) {
          ArenaStatus.approved => AuditAction.arenaApproved,
          ArenaStatus.rejected => AuditAction.arenaRejected,
          ArenaStatus.suspended => AuditAction.arenaSuspended,
          _ => 'arena.status_changed',
        },
        entityType: 'arena',
        entityId: arenaId,
        newData: {'status': status.name, 'name': arenaName},
        reason: reason,
      );
    } catch (e) {
      await _audit.log(
        action: 'arena.status_change_failed',
        entityType: 'arena',
        entityId: arenaId,
        success: false,
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  Future<void> toggleArenaActive(
      String arenaId, String arenaName, bool nextState) async {
    try {
      await _arenaService.toggleActive(arenaId, nextState);
      await _audit.log(
        action: nextState ? AuditAction.arenaRestored : AuditAction.arenaSuspended,
        entityType: 'arena',
        entityId: arenaId,
        newData: {'isActive': nextState, 'name': arenaName},
      );
    } catch (e) {
      debugPrint('[AdminRepository] toggleArenaActive error: $e');
      rethrow;
    }
  }

  Future<void> toggleDocsVerified(
      String arenaId, String arenaName, bool nextState, List<String> allVerified) async {
    await _db.collection('settings').doc('booking').update({
      'verifiedArenaDocs': allVerified,
    });
    await _audit.log(
      action: nextState
          ? AuditAction.arenaDocsVerified
          : AuditAction.arenaDocsUnverified,
      entityType: 'arena',
      entityId: arenaId,
      newData: {'name': arenaName, 'verified': nextState},
    );
  }

  Future<void> toggleCarousel(
    String arenaId,
    String arenaName, {
    required bool show,
    int? order,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final data = <String, dynamic>{
      'showOnHomeCarousel': show,
      'carouselOrder': order ?? 0,
      if (startDate != null)
        'carouselStartDate': Timestamp.fromDate(startDate)
      else
        'carouselStartDate': FieldValue.delete(),
      if (endDate != null)
        'carouselEndDate': Timestamp.fromDate(endDate)
      else
        'carouselEndDate': FieldValue.delete(),
    };
    await _db.collection('arenas').doc(arenaId).update(data);
    await _audit.log(
      action: show
          ? AuditAction.arenaCarouselAdded
          : AuditAction.arenaCarouselRemoved,
      entityType: 'arena',
      entityId: arenaId,
      newData: {'name': arenaName, 'show': show, 'order': order},
    );
  }

  Future<void> setCarouselOrder(String arenaId, int order) async {
    await _db.collection('arenas').doc(arenaId).update({'carouselOrder': order});
    await _audit.log(
      action: AuditAction.arenaCarouselOrderSet,
      entityType: 'arena',
      entityId: arenaId,
      newData: {'carouselOrder': order},
    );
  }

  Future<void> toggleFeatured(String arenaId, String arenaName, bool nextState) async {
    await _db.collection('arenas').doc(arenaId).update({'isFeatured': nextState});
    await _audit.log(
      action: nextState ? AuditAction.arenaFeatured : AuditAction.arenaUnfeatured,
      entityType: 'arena',
      entityId: arenaId,
      newData: {'name': arenaName, 'isFeatured': nextState},
    );
  }

  // ── Boost management ──────────────────────────────────────────────────

  Future<void> setBoostStatus(
    String boostId,
    BoostStatus status,
    BoostRequestModel boost,
  ) async {
    try {
      await _boostService.updateStatus(boostId, status.key);
      if (status == BoostStatus.approved) {
        final days = switch (boost.duration) {
          BoostDuration.oneWeek => 7,
          BoostDuration.twoWeeks => 14,
          BoostDuration.oneMonth => 30,
        };
        await _db.collection('arenas').doc(boost.arenaId).update({
          'isFeatured': true,
          'featuredUntil': Timestamp.fromDate(
              DateTime.now().add(Duration(days: days))),
        });
      }
      if (status == BoostStatus.rejected) {
        await _db.collection('arenas').doc(boost.arenaId).update({
          'isFeatured': false,
          'featuredUntil': FieldValue.delete(),
        });
      }
      await _audit.log(
        action: status == BoostStatus.approved
            ? AuditAction.boostApproved
            : AuditAction.boostRejected,
        entityType: 'boost',
        entityId: boostId,
        newData: {'arenaName': boost.arenaName, 'status': status.name},
      );
    } catch (e) {
      await _audit.log(
        action: 'boost.status_change_failed',
        entityType: 'boost',
        entityId: boostId,
        success: false,
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  // ── User management ───────────────────────────────────────────────────

  Future<void> changeAccountStatus(
    UserModel user,
    AccountStatus newStatus, {
    String? reason,
  }) async {
    await _db
        .collection('users')
        .doc(user.uid)
        .update({'accountStatus': newStatus.name});
    await _audit.log(
      action: switch (newStatus) {
        AccountStatus.suspended => AuditAction.userSuspended,
        AccountStatus.active => AuditAction.userRestored,
        AccountStatus.inactive => AuditAction.userDeactivated,
        AccountStatus.archived => AuditAction.userArchived,
        AccountStatus.pending => AuditAction.accountStatusChanged,
      },
      entityType: 'user',
      entityId: user.uid,
      oldData: {'accountStatus': user.accountStatus.name, 'name': user.name},
      newData: {'accountStatus': newStatus.name, 'name': user.name},
      reason: reason,
    );
  }

  Future<void> changeRole(UserModel user, UserRole newRole) async {
    await _db
        .collection('users')
        .doc(user.uid)
        .update({'role': newRole.value});
    await _audit.log(
      action: AuditAction.userRoleChanged,
      entityType: 'user',
      entityId: user.uid,
      oldData: {'role': user.role.value, 'name': user.name},
      newData: {'role': newRole.value, 'name': user.name},
    );
  }

  Future<void> updateAdminScope(
    UserModel user, {
    required List<String> managedOwnerIds,
    required List<String> managedArenaIds,
    int? ownerInviteLimit,
  }) async {
    final data = <String, dynamic>{
      'managedOwnerIds': managedOwnerIds,
      'managedArenaIds': managedArenaIds,
    };
    if (ownerInviteLimit != null) {
      data['ownerInviteLimit'] = ownerInviteLimit;
    } else {
      data['ownerInviteLimit'] = null;
    }
    await _db.collection('users').doc(user.uid).update(data);
    await _audit.log(
      action: AuditAction.adminPermissionsChanged,
      entityType: 'user',
      entityId: user.uid,
      oldData: {
        'managedOwnerIds': user.managedOwnerIds,
        'managedArenaIds': user.managedArenaIds,
        'ownerInviteLimit': user.ownerInviteLimit,
        'name': user.name,
      },
      newData: {
        'managedOwnerIds': managedOwnerIds,
        'managedArenaIds': managedArenaIds,
        'ownerInviteLimit': ownerInviteLimit,
        'name': user.name,
      },
    );
  }

  Future<void> updateCustomPermissions(
    UserModel user,
    Map<String, bool> newPerms,
  ) async {
    await _db
        .collection('users')
        .doc(user.uid)
        .update({'customPermissions': newPerms});
    await _audit.log(
      action: AuditAction.adminPermissionsChanged,
      entityType: 'user',
      entityId: user.uid,
      oldData: {'customPermissions': user.customPermissions, 'name': user.name},
      newData: {'customPermissions': newPerms, 'name': user.name},
    );
  }

  // ── Settings ──────────────────────────────────────────────────────────

  Future<void> saveSettings({
    required int deposit,
    required int deduct,
    required int minHours,
    required String jazzCash,
    required Map<String, dynamic> oldValues,
  }) async {
    final data = {
      'depositPercent': deposit,
      'cancellationDeductPercent': deduct,
      'minCancelHoursBefore': minHours,
      'jazzCashNumber': jazzCash,
    };
    await _db
        .collection('settings')
        .doc('booking')
        .set(data, SetOptions(merge: true));
    await _audit.log(
      action: AuditAction.settingsUpdated,
      entityType: 'settings',
      entityId: 'booking',
      oldData: oldValues,
      newData: data,
    );
  }
}
