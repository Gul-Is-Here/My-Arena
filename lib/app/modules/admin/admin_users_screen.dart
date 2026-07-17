import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/admin_controller.dart';
import '../../data/models/user_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';

/// User management — All users (ban/role) | Staff.
class AdminUsersScreen extends StatelessWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final admin = AdminController.to;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('User Management'),
          bottom: const TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textGrey,
            tabs: [
              Tab(text: 'All Users'),
              Tab(text: 'Staff'),
            ],
          ),
        ),
        body: Obx(() {
          admin.users.length;
          final all = admin.users.toList();
          final staff =
              admin.users.where((u) => u.role == UserRole.staff).toList();
          return TabBarView(
            children: [
              _userList(context, all, admin),
              _userList(context, staff, admin),
            ],
          );
        }),
      ),
    );
  }

  Widget _userList(
      BuildContext context, List<UserModel> users, AdminController admin) {
    if (users.isEmpty) {
      return const Center(child: Text('No users'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: users.length,
      itemBuilder: (_, i) {
        final u = users[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: Text(
                    u.name.isNotEmpty ? u.name[0] : '?',
                    style: AppTextStyles.titleMedium
                        .copyWith(color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(u.name,
                                style: AppTextStyles.titleMedium,
                                overflow: TextOverflow.ellipsis),
                          ),
                          if (!u.isActive) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.error.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('BANNED',
                                  style: AppTextStyles.bodySmall.copyWith(
                                      fontSize: 10,
                                      color: AppColors.error,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ],
                      ),
                      Text(u.email,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textGrey)),
                      Text(u.role.name.toUpperCase(),
                          style: AppTextStyles.bodySmall.copyWith(
                              fontSize: 10,
                              color: AppColors.accent,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5)),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppColors.textGrey),
                  onSelected: (action) {
                    if (action == 'ban') {
                      admin.toggleBan(u.uid);
                    } else if (action == 'role') {
                      _showRoleSheet(context, u, admin);
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'ban',
                      child: Text(u.isActive ? 'Ban user' : 'Unban user'),
                    ),
                    const PopupMenuItem(
                      value: 'role',
                      child: Text('Change role'),
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

  void _showRoleSheet(
      BuildContext context, UserModel user, AdminController admin) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Change role — ${user.name}',
                  style: AppTextStyles.titleLarge),
              const SizedBox(height: 12),
              ...UserRole.values.map(
                (r) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    r == user.role
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color:
                        r == user.role ? AppColors.primary : AppColors.textGrey,
                  ),
                  title: Text(r.name.capitalizeFirst!),
                  onTap: () {
                    admin.changeRole(user.uid, r);
                    Get.back();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
