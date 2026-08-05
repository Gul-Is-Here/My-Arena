import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint, defaultTargetPlatform;
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../data/models/audit_log_model.dart';
import '../data/models/user_model.dart';

/// Writes immutable audit log entries to Firestore `audit_logs/{logId}`.
/// Registered as a permanent GetX service via InitialBinding.
///
/// Usage:
///   AuditService.to.log(
///     action: AuditAction.arenaApproved,
///     entityType: 'arena',
///     entityId: arenaId,
///     newData: {'status': 'approved'},
///   );
class AuditService extends GetxService {
  static AuditService get to => Get.find();

  final _col = FirebaseFirestore.instance.collection('audit_logs');

  /// Writes a log entry. Fire-and-forget — logs failures to debug console
  /// but never throws, so a logging error never breaks a business operation.
  Future<void> log({
    required String action,
    required String entityType,
    required String entityId,
    Map<String, dynamic>? oldData,
    Map<String, dynamic>? newData,
    String? reason,
    bool success = true,
    String? errorMessage,
  }) async {
    try {
      final user = Get.find<AuthController>().currentUser.value;
      final entry = AuditLogModel(
        id: '',
        actorId: user?.uid ?? 'system',
        actorName: user?.name ?? 'System',
        actorRole: user?.role.value ?? 'unknown',
        action: action,
        entityType: entityType,
        entityId: entityId,
        oldData: oldData,
        newData: newData,
        timestamp: DateTime.now(),
        platform: defaultTargetPlatform.name,
        appVersion: '1.0.0',
        success: success,
        errorMessage: errorMessage,
        reason: reason,
      );
      await _col.add(entry.toMap());
    } catch (e) {
      debugPrint('[AuditService] Failed to write log: $e');
    }
  }

  /// Streams the most recent [limit] audit logs.
  Stream<List<AuditLogModel>> stream({int limit = 200}) =>
      _col
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .snapshots()
          .map((s) => s.docs
              .map((d) => AuditLogModel.fromMap(d.data(), d.id))
              .toList());

  /// Returns logs filtered by [actorRole].
  Stream<List<AuditLogModel>> streamByRole(String role, {int limit = 200}) =>
      _col
          .where('actorRole', isEqualTo: role)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .snapshots()
          .map((s) => s.docs
              .map((d) => AuditLogModel.fromMap(d.data(), d.id))
              .toList());

  /// Returns logs for a specific entity.
  Stream<List<AuditLogModel>> streamForEntity(
          String entityType, String entityId) =>
      _col
          .where('entityType', isEqualTo: entityType)
          .where('entityId', isEqualTo: entityId)
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map((s) => s.docs
              .map((d) => AuditLogModel.fromMap(d.data(), d.id))
              .toList());
}
