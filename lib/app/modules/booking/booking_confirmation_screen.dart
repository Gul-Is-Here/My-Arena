import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_button.dart';

class BookingConfirmationScreen extends StatelessWidget {
  const BookingConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.4, end: 1),
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
                builder: (_, v, child) =>
                    Transform.scale(scale: v, child: child),
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded,
                      size: 64, color: AppColors.success),
                ),
              ),
              const SizedBox(height: 28),
              Text('Deposit Submitted!',
                  style: AppTextStyles.headlineLarge,
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(
                'Your booking is awaiting owner approval. We\'ll notify you as soon as it\'s confirmed.',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textGrey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'STATUS: DEPOSIT SUBMITTED',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              AppButton(
                label: 'View My Bookings',
                onPressed: () => Get.offAllNamed(
                  AppRoutes.customerDashboard,
                  arguments: 1, // open Bookings tab
                ),
              ),
              const SizedBox(height: 12),
              AppButton(
                label: 'Back to Home',
                outlined: true,
                onPressed: () => Get.offAllNamed(AppRoutes.customerDashboard),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
