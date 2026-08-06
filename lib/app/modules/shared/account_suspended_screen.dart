import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../data/models/user_model.dart';
import '../../theme/app_colors.dart';

class AccountSuspendedScreen extends StatelessWidget {
  const AccountSuspendedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final status = Get.arguments as AccountStatus? ?? AccountStatus.suspended;

    final (icon, title, message) = switch (status) {
      AccountStatus.suspended => (
          Icons.block_rounded,
          'Account Suspended',
          'Your account has been temporarily suspended. Please contact support to resolve this.',
        ),
      AccountStatus.inactive => (
          Icons.person_off_rounded,
          'Account Deactivated',
          'Your account has been deactivated. Please contact support if you think this is a mistake.',
        ),
      AccountStatus.archived => (
          Icons.archive_rounded,
          'Account Closed',
          'This account has been permanently closed. Please contact support for further assistance.',
        ),
      _ => (
          Icons.error_outline_rounded,
          'Access Restricted',
          'Your account access has been restricted. Please contact support.',
        ),
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.error.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 48, color: AppColors.error),
              ),
              const SizedBox(height: 32),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textGrey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Get.find<AuthController>().signOut(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: AppColors.error),
                  ),
                  child: Text(
                    'Sign Out',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
