import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../data/models/user_model.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Shown after onboarding and for returning unauthenticated users.
/// Lets the user choose whether to enter as a Customer or Owner,
/// which pre-selects the role context for the login/signup flow.
class RoleSelectScreen extends StatefulWidget {
  const RoleSelectScreen({super.key});

  @override
  State<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends State<RoleSelectScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<double>(begin: 40, end: 0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _select(UserRole role) {
    AuthController.to.selectedRole.value = role;
    Get.toNamed(AppRoutes.login, arguments: role);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background art
          Positioned.fill(child: _RoleSelectBg()),

          // Content
          SafeArea(
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, child) => Opacity(
                opacity: _opacity.value,
                child: Transform.translate(
                  offset: Offset(0, _slide.value),
                  child: child,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: size.height * 0.1),

                    // Brand mark
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.sports_soccer,
                              size: 20, color: AppColors.onPrimary),
                        ),
                        const SizedBox(width: 10),
                        Text('MY ARENA',
                            style: AppTextStyles.titleMedium.copyWith(
                                color: AppColors.textPrimary,
                                letterSpacing: 3)),
                      ],
                    ),
                    SizedBox(height: size.height * 0.06),

                    // Headline
                    Text(
                      'How would you\nlike to continue?',
                      style: AppTextStyles.displayLarge.copyWith(
                        color: AppColors.textPrimary,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Choose your workspace to get started.',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: size.height * 0.06),

                    // Customer card
                    _RoleCard(
                      title: "I'm a Player",
                      subtitle:
                          'Discover arenas, book courts and compete in tournaments.',
                      icon: Icons.sports_tennis_rounded,
                      accent: AppColors.primary,
                      tag: 'CUSTOMER PORTAL',
                      onTap: () => _select(UserRole.customer),
                    ),
                    const SizedBox(height: 16),

                    // Owner card
                    _RoleCard(
                      title: "I'm an Owner",
                      subtitle:
                          'List your arena, manage bookings, courts and revenue.',
                      icon: Icons.stadium_rounded,
                      accent: AppColors.secondary,
                      tag: 'OWNER PORTAL',
                      onTap: () => _select(UserRole.owner),
                    ),

                    const Spacer(),

                    // Admin/Staff hint
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: TextButton(
                          onPressed: () {
                            AuthController.to.selectedRole.value =
                                UserRole.admin;
                            Get.toNamed(AppRoutes.login);
                          },
                          child: Text(
                            'Admin or Staff? Sign in here',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textDisabled,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final String tag;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.tag,
    required this.onTap,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _pressed
                ? AppColors.elevated
                : AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _pressed
                  ? widget.accent.withValues(alpha: 0.5)
                  : AppColors.border,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.accent.withValues(alpha: _pressed ? 0.15 : 0.0),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: widget.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(widget.icon, size: 32, color: widget.accent),
              ),
              const SizedBox(width: 18),

              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: widget.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        widget.tag,
                        style: AppTextStyles.caption.copyWith(
                          color: widget.accent,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(widget.title, style: AppTextStyles.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Arrow
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: widget.accent.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleSelectBg extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _BgPainter());
  }
}

class _BgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Top-right lime glow
    paint.color = AppColors.primary.withValues(alpha: 0.04);
    canvas.drawCircle(Offset(size.width, 0), 200, paint);

    // Bottom-left blue glow
    paint.color = AppColors.secondary.withValues(alpha: 0.04);
    canvas.drawCircle(Offset(0, size.height), 250, paint);

    // Subtle diagonal line pattern
    final linePaint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.3)
      ..strokeWidth = 0.5;
    for (double i = -size.height; i < size.width + size.height; i += 40) {
      canvas.drawLine(
          Offset(i, 0), Offset(i + size.height, size.height), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
