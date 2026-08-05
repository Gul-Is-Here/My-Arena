import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/models/audit_log_model.dart';
import '../../services/audit_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Audit trail streamed from Firestore `audit_logs` — immutable, append-only.
class AdminAuditLogsScreen extends StatefulWidget {
  const AdminAuditLogsScreen({super.key});

  @override
  State<AdminAuditLogsScreen> createState() => _AdminAuditLogsScreenState();
}

class _AdminAuditLogsScreenState extends State<AdminAuditLogsScreen> {
  String _filter = 'all';
  StreamSubscription<List<AuditLogModel>>? _sub;
  List<AuditLogModel> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _subscribe('all');
  }

  void _subscribe(String filter) {
    _sub?.cancel();
    setState(() => _loading = true);

    final stream = filter == 'all'
        ? AuditService.to.stream()
        : AuditService.to.streamByRole(filter);

    _sub = stream.listen(
      (logs) => setState(() {
        _logs = logs;
        _loading = false;
      }),
      onError: (_) => setState(() => _loading = false),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _exportCsv() async {
    if (_logs.isEmpty) {
      Get.snackbar('Export', 'No logs to export.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.elevated,
          colorText: AppColors.textPrimary,
          margin: const EdgeInsets.all(16));
      return;
    }
    final buf = StringBuffer();
    buf.writeln('ID,Timestamp,Actor Name,Actor Role,Action,Entity Type,Entity ID,Success,Reason,Error');
    final fmt = DateFormat("yyyy-MM-dd'T'HH:mm:ss");
    for (final log in _logs) {
      buf.writeln([
        _csvEsc(log.id),
        fmt.format(log.timestamp),
        _csvEsc(log.actorName),
        _csvEsc(log.actorRole),
        _csvEsc(log.action),
        _csvEsc(log.entityType),
        _csvEsc(log.entityId),
        log.success ? 'true' : 'false',
        _csvEsc(log.reason ?? ''),
        _csvEsc(log.errorMessage ?? ''),
      ].join(','));
    }
    try {
      final file = File(
          '${Directory.systemTemp.path}/audit_logs_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(buf.toString());
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'MyArena Audit Logs ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
      );
    } catch (e) {
      Get.snackbar('Export failed', e.toString(),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.error,
          colorText: AppColors.textPrimary,
          margin: const EdgeInsets.all(16));
    }
  }

  String _csvEsc(String s) {
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text('Audit logs',
            style: AppTextStyles.titleMedium.copyWith(color: AppColors.textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined, color: AppColors.textSecondary),
            tooltip: 'Export CSV',
            onPressed: _exportCsv,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Filter chips ─────────────────────────────────────────────
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                for (final f in ['all', 'admin', 'staff', 'owner'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _filter = f);
                        _subscribe(f);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: _filter == f
                              ? AppColors.primary
                              : AppColors.elevated,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _filter == f
                                ? AppColors.primary
                                : AppColors.border,
                          ),
                        ),
                        child: Text(
                          f[0].toUpperCase() + f.substring(1),
                          style: AppTextStyles.label.copyWith(
                            fontSize: 12,
                            color: _filter == f
                                ? AppColors.onPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                const Spacer(),
                Text(
                  '${_logs.length} entries',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),

          // ── Log list ─────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : _logs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.receipt_long_outlined,
                                color: AppColors.textSecondary, size: 48),
                            const SizedBox(height: 12),
                            Text('No log entries',
                                style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.textSecondary)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _logs.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (_, i) => _LogTile(log: _logs[i]),
                      ),
          ),
        ],
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  final AuditLogModel log;
  const _LogTile({required this.log});

  @override
  Widget build(BuildContext context) {
    final roleColor = _roleColor(log.actorRole);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: log.success ? AppColors.border : AppColors.error.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Role icon ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_roleIcon(log.actorRole), color: roleColor, size: 18),
          ),
          const SizedBox(width: 12),

          // ── Details ──────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _formatAction(log.action),
                        style: AppTextStyles.titleMedium.copyWith(
                            color: AppColors.textPrimary, fontSize: 14),
                      ),
                    ),
                    if (!log.success)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('failed',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.error)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${log.entityType} · ${log.entityId.length > 12 ? '${log.entityId.substring(0, 12)}…' : log.entityId}',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
                Text(
                  'by ${log.actorName} · ${log.actorRole}',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
                if (log.reason != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Reason: ${log.reason}',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.warning),
                  ),
                ],
              ],
            ),
          ),

          // ── Timestamp ────────────────────────────────────────────────
          const SizedBox(width: 8),
          Text(
            _timeAgo(log.timestamp),
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  String _formatAction(String action) =>
      action.replaceAll('.', ' › ').replaceAll('_', ' ');

  Color _roleColor(String role) {
    return switch (role) {
      'admin' || 'superAdmin' => AppColors.primary,
      'staff' || 'supportAgent' => AppColors.secondary,
      'owner' => AppColors.accent,
      'finance' => AppColors.success,
      'moderator' => AppColors.warning,
      _ => AppColors.textSecondary,
    };
  }

  IconData _roleIcon(String role) {
    return switch (role) {
      'admin' || 'superAdmin' => Icons.admin_panel_settings_outlined,
      'staff' || 'supportAgent' => Icons.support_agent,
      'owner' => Icons.storefront_outlined,
      'finance' => Icons.payments_outlined,
      'moderator' => Icons.gavel_outlined,
      _ => Icons.person_outline,
    };
  }

  String _timeAgo(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    return '${d.inDays}d';
  }
}
