import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/admin_controller.dart';
import '../../data/models/arena_model.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/status_badge.dart';

/// Arena management — Pending approvals | All arenas (force off).
class AdminArenasScreen extends StatelessWidget {
  const AdminArenasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final admin = AdminController.to;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Arena Management'),
          bottom: TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textGrey,
            tabs: [
              Obx(() => Tab(text: 'Pending (${admin.pendingArenas.length})')),
              const Tab(text: 'All Arenas'),
            ],
          ),
        ),
        body: Obx(() {
          admin.arenas.length;
          return TabBarView(
            children: [
              _pendingList(admin),
              _allList(admin),
            ],
          );
        }),
      ),
    );
  }

  Widget _pendingList(AdminController admin) {
    final items = admin.pendingArenas;
    if (items.isEmpty) {
      return const Center(child: Text('No arenas awaiting approval'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final a = items[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            onTap: () =>
                Get.toNamed(AppRoutes.adminArenaDetail, arguments: a.id),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _arenaHeader(a),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            admin.setArenaStatus(a.id, ArenaStatus.rejected),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                        ),
                        child: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () =>
                            admin.setArenaStatus(a.id, ArenaStatus.approved),
                        style: FilledButton.styleFrom(
                            backgroundColor: AppColors.success),
                        child: const Text('Approve'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _allList(AdminController admin) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: admin.arenas.length,
      itemBuilder: (_, i) {
        final a = admin.arenas[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            onTap: () =>
                Get.toNamed(AppRoutes.adminArenaDetail, arguments: a.id),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _arenaHeader(a),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      a.isActive ? 'Visible to customers' : 'Hidden (OFF)',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: a.isActive
                            ? AppColors.success
                            : AppColors.error,
                      ),
                    ),
                    Switch(
                      value: a.isActive,
                      activeThumbColor: AppColors.success,
                      onChanged: (_) => admin.toggleArenaActive(a.id),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _arenaHeader(ArenaModel a) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(a.name, style: AppTextStyles.titleMedium),
              Text(a.location.address,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textGrey)),
              const SizedBox(height: 4),
              Text('${a.courts.length} court${a.courts.length == 1 ? '' : 's'}',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textGrey)),
            ],
          ),
        ),
        StatusBadge(status: a.status.name),
      ],
    );
  }
}
