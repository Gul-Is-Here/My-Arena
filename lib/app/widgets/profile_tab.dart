import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/theme_controller.dart';
import '../widgets/app_card.dart';

/// Profile tab shared by all role shells: user info, theme toggle, sign out.
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthController.to;
    final theme = ThemeController.to;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Obx(() {
            final user = auth.currentUser.value;
            return Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: const Icon(Icons.person,
                      size: 48, color: AppColors.primary),
                ),
                const SizedBox(height: 16),
                Text(user?.name ?? 'User', style: AppTextStyles.headlineMedium),
                const SizedBox(height: 4),
                Text(
                  user?.email.isNotEmpty == true
                      ? user!.email
                      : (user?.phone ?? ''),
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textGrey),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    (user?.role.name ?? 'customer').toUpperCase(),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: 32),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Obx(
                  () => SwitchListTile(
                    secondary: const Icon(Icons.dark_mode_outlined),
                    title: const Text('Dark Mode'),
                    value: theme.isDarkMode.value,
                    activeThumbColor: AppColors.primary,
                    onChanged: (_) => theme.toggleTheme(),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('Notifications'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _comingSoon('Notification settings'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: const Text('Help & Support'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _comingSoon('Support chat (Phase 4)'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.logout, color: AppColors.error),
              title: const Text(
                'Sign Out',
                style: TextStyle(color: AppColors.error),
              ),
              onTap: auth.signOut,
            ),
          ),
        ],
      ),
    );
  }

  void _comingSoon(String feature) {
    Get.snackbar(
      'Coming soon',
      feature,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
    );
  }
}
