import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/admin_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';

/// Audit trail of admin & staff actions, filterable by role.
class AdminAuditLogsScreen extends StatefulWidget {
  const AdminAuditLogsScreen({super.key});

  @override
  State<AdminAuditLogsScreen> createState() => _AdminAuditLogsScreenState();
}

class _AdminAuditLogsScreenState extends State<AdminAuditLogsScreen> {
  String _filter = 'all'; // all | admin | staff

  static String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final admin = AdminController.to;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Export CSV',
            onPressed: () => Get.snackbar(
                'Export', 'CSV export arrives with the backend phase.',
                snackPosition: SnackPosition.BOTTOM,
                margin: const EdgeInsets.all(16)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: ['all', 'admin', 'staff'].map((f) {
                final sel = _filter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f.capitalizeFirst!),
                    selected: sel,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: sel ? Colors.white : null,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) => setState(() => _filter = f),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: Obx(() {
              final items = admin.logs
                  .where((l) => _filter == 'all' || l.actorRole == _filter)
                  .toList();
              if (items.isEmpty) {
                return const Center(child: Text('No log entries'));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final log = items[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: (log.actorRole == 'admin'
                                      ? AppColors.primary
                                      : AppColors.accent)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              log.actorRole == 'admin'
                                  ? Icons.admin_panel_settings_outlined
                                  : Icons.support_agent,
                              size: 20,
                              color: log.actorRole == 'admin'
                                  ? AppColors.primary
                                  : AppColors.accent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(log.action,
                                    style: AppTextStyles.titleMedium),
                                Text(
                                  '${log.target} · by ${log.actorName}',
                                  style: AppTextStyles.bodySmall
                                      .copyWith(color: AppColors.textGrey),
                                ),
                              ],
                            ),
                          ),
                          Text(_timeAgo(log.timestamp),
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.textGrey)),
                        ],
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}
