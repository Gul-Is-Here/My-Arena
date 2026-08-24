import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../data/models/user_model.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Shown when a user tries to access a route they don't have permission for.
/// Never shows a crash or blank screen — always shows a clear explanation.
class UnauthorizedScreen extends StatefulWidget {
  const UnauthorizedScreen({super.key});

  @override
  State<UnauthorizedScreen> createState() => _UnauthorizedScreenState();
}

class _UnauthorizedScreenState extends State<UnauthorizedScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── Icon ──────────────────────────────────────────────
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3),
                          width: 1.5),
                    ),
                    child: const Icon(
                      Icons.lock_outline,
                      color: AppColors.error,
                      size: 44,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Error code ────────────────────────────────────────
                  Text(
                    '403',
                    style: AppTextStyles.scoreboardLarge.copyWith(
                      color: AppColors.error.withValues(alpha: 0.3),
                      fontSize: 64,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ── Title ─────────────────────────────────────────────
                  Text(
                    'Access denied',
                    style: AppTextStyles.headlineMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // ── Explanation ───────────────────────────────────────
                  Text(
                    "Your account doesn't have permission to view this page. "
                    "If you believe this is a mistake, contact your administrator.",
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // ── Current role pill ─────────────────────────────────
                  Obx(() {
                    final role =
                        AuthController.to.currentUser.value?.role;
                    if (role == null) return const SizedBox.shrink();
                    return Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.elevated,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person_outline,
                              size: 14,
                              color: AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            'Signed in as ${role.label}',
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 40),

                  // ── Actions ───────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: _PrimaryButton(
                      label: 'Go to my dashboard',
                      onTap: _goHome,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: _SecondaryButton(
                      label: Get.previousRoute.isNotEmpty
                          ? 'Go back'
                          : 'Sign out',
                      onTap: Get.previousRoute.isNotEmpty
                          ? () => Get.back()
                          : () => AuthController.to.signOut(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _goHome() {
    final role = AuthController.to.currentUser.value?.role;
    final dest = switch (role) {
      UserRole.admin ||
      UserRole.superAdmin ||
      UserRole.operationsManager ||
      UserRole.supportAgent ||
      UserRole.finance ||
      UserRole.contentManager ||
      UserRole.moderator =>
        AppRoutes.adminDashboard,
      UserRole.owner => AppRoutes.ownerDashboard,
      UserRole.staff => AppRoutes.staffDashboard,
      _ => AppRoutes.customerDashboard,
    };
    Get.offAllNamed(dest);
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTextStyles.button.copyWith(color: AppColors.onPrimary),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SecondaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.elevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTextStyles.button.copyWith(
              color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
