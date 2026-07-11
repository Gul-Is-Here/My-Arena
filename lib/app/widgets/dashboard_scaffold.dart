import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/theme_controller.dart';

/// Shared shell for the 4 role dashboards. Real dashboard content
/// arrives in Phases 2–4; this provides the header, theme toggle
/// and sign-out so the Phase 1 role-based navigation is testable.
class DashboardScaffold extends StatelessWidget {
  final String title;
  final IconData icon;
  final String phaseNote;
  final Widget? body;

  const DashboardScaffold({
    super.key,
    required this.title,
    required this.icon,
    required this.phaseNote,
    this.body,
  });

  @override
  Widget build(BuildContext context) {
    final auth = AuthController.to;
    final theme = ThemeController.to;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          Obx(
            () => IconButton(
              tooltip: 'Toggle theme',
              icon: Icon(
                theme.isDarkMode.value
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
              ),
              onPressed: theme.toggleTheme,
            ),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: auth.signOut,
          ),
        ],
      ),
      body: body ??
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 80, color: AppColors.primary),
                  const SizedBox(height: 24),
                  Obx(
                    () => Text(
                      'Welcome, ${auth.currentUser.value?.name ?? 'User'}!',
                      style: AppTextStyles.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    phaseNote,
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textGrey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
    );
  }
}
