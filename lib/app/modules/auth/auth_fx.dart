import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/user_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Fade + slide-up entrance, staggered by [index].
class StaggerIn extends StatefulWidget {
  final int index;
  final Widget child;
  const StaggerIn({super.key, required this.index, required this.child});

  @override
  State<StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<StaggerIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _ctrl,
    curve: Curves.easeOut,
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.12),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 80 + widget.index * 70), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _fade,
    child: SlideTransition(position: _slide, child: widget.child),
  );
}

// ---------------------------------------------------------------------------
// Portal mismatch bottom sheet
// ---------------------------------------------------------------------------

/// Call [PortalMismatchSheet.show] from the auth controller whenever a user
/// signs in through the wrong portal. Auth has already succeeded at this
/// point — the sheet just routes them to the right place.
class PortalMismatchSheet extends StatelessWidget {
  final UserRole actualRole;
  final VoidCallback onSwitch;
  final VoidCallback onCancel;

  const PortalMismatchSheet({
    super.key,
    required this.actualRole,
    required this.onSwitch,
    required this.onCancel,
  });

  static Future<void> show({
    required UserRole actualRole,
    required VoidCallback onSwitch,
    required VoidCallback onCancel,
  }) =>
      Get.bottomSheet(
        PortalMismatchSheet(
          actualRole: actualRole,
          onSwitch: onSwitch,
          onCancel: onCancel,
        ),
        isScrollControlled: true,
        enableDrag: true,
        backgroundColor: Colors.transparent,
        ignoreSafeArea: false,
      );

  static _SheetConfig _config(UserRole role) {
    switch (role) {
      case UserRole.owner:
        return _SheetConfig(
          icon: Icons.stadium_rounded,
          accent: AppColors.secondary,
          headline: 'You\'re an Arena Owner',
          body:
              'This account is registered as an Arena Owner. We\'ll take you to your Owner Dashboard right away.',
          switchLabel: 'Go to Owner Dashboard',
        );
      case UserRole.staff:
        return _SheetConfig(
          icon: Icons.badge_outlined,
          accent: AppColors.accent,
          headline: 'Arena Staff Account',
          body:
              'This account belongs to Arena Staff. Staff access is available through the Owner portal.',
          switchLabel: 'Go to Staff Dashboard',
        );
      case UserRole.admin:
      case UserRole.superAdmin:
      case UserRole.operationsManager:
      case UserRole.supportAgent:
      case UserRole.finance:
      case UserRole.contentManager:
      case UserRole.moderator:
        return _SheetConfig(
          icon: Icons.admin_panel_settings_outlined,
          accent: AppColors.accent,
          headline: 'Admin Account',
          body: 'Taking you to the Admin Dashboard.',
          switchLabel: 'Go to Admin Dashboard',
        );
      default:
        return _SheetConfig(
          icon: Icons.sports_tennis_rounded,
          accent: AppColors.primary,
          headline: 'You\'re a Customer',
          body:
              'This account is registered as a Customer. We\'ll take you to the Customer portal right away.',
          switchLabel: 'Go to Customer Portal',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _config(actualRole);
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 24),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon badge
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: cfg.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(cfg.icon, color: cfg.accent, size: 28),
                  ),
                  const SizedBox(height: 20),

                  Text(cfg.headline,
                      style: AppTextStyles.titleLarge
                          .copyWith(letterSpacing: -0.3)),
                  const SizedBox(height: 8),
                  Text(cfg.body,
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textSecondary, height: 1.5)),
                  const SizedBox(height: 28),

                  // Primary: switch to correct portal
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: cfg.accent,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: cfg.accent.withValues(alpha: 0.3),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: onSwitch,
                          child: Center(
                            child: Text(
                              cfg.switchLabel,
                              style: AppTextStyles.button
                                  .copyWith(color: AppColors.onPrimary),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Secondary: cancel → sign out
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: TextButton(
                      onPressed: onCancel,
                      style: TextButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: AppTextStyles.button
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetConfig {
  final IconData icon;
  final Color accent;
  final String headline;
  final String body;
  final String switchLabel;

  const _SheetConfig({
    required this.icon,
    required this.accent,
    required this.headline,
    required this.body,
    required this.switchLabel,
  });
}

// ---------------------------------------------------------------------------

/// Accent CTA with a repeating shimmer sweep, ink ripple, and a
/// spring-bounce scale on tap.
class ShimmerBounceButton extends StatefulWidget {
  final String label;
  final Color accent;
  final bool isLoading;
  final VoidCallback onTap;

  const ShimmerBounceButton({
    super.key,
    required this.label,
    required this.accent,
    required this.isLoading,
    required this.onTap,
  });

  @override
  State<ShimmerBounceButton> createState() => _ShimmerBounceButtonState();
}

class _ShimmerBounceButtonState extends State<ShimmerBounceButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();
  bool _pressed = false;

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  void _setPressed(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.94 : 1.0,
      // Quick press-in, springy release.
      duration: _pressed
          ? const Duration(milliseconds: 110)
          : const Duration(milliseconds: 550),
      curve: _pressed ? Curves.easeOut : Curves.elasticOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 54,
        width: double.infinity,
        decoration: BoxDecoration(
          color: widget.accent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: widget.accent.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Shimmer sweep
              AnimatedBuilder(
                animation: _shimmer,
                builder: (_, child) {
                  // Sweep from off-screen left to off-screen right.
                  final dx = -1.5 + _shimmer.value * 4.0;
                  return FractionalTranslation(
                    translation: Offset(dx, 0),
                    child: Transform.rotate(
                      angle: 0.35,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0),
                              Colors.white.withValues(alpha: 0.35),
                              Colors.white.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  splashColor: AppColors.onPrimary.withValues(alpha: 0.12),
                  highlightColor: Colors.transparent,
                  onTapDown: widget.isLoading ? null : (_) => _setPressed(true),
                  onTapCancel: () => _setPressed(false),
                  onTap: widget.isLoading
                      ? null
                      : () {
                          _setPressed(false);
                          widget.onTap();
                        },
                  child: Center(
                    child: widget.isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.onPrimary,
                            ),
                          )
                        : Text(
                            widget.label,
                            style: AppTextStyles.button.copyWith(
                              color: AppColors.onPrimary,
                            ),
                          ),
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
