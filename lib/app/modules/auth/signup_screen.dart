import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../data/models/user_model.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/validators.dart';
import '../../widgets/app_text_field.dart';
import 'auth_fx.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final auth = AuthController.to;

  late UserRole _portal;
  late final AnimationController _tabCtrl;
  late final AnimationController _bgCtrl;

  @override
  void initState() {
    super.initState();
    final arg = Get.arguments;
    _portal = (arg is UserRole) ? arg : auth.selectedRole.value;

    _tabCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    if (_portal == UserRole.owner) _tabCtrl.forward();

    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _bgCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Color get _accent =>
      _portal == UserRole.owner ? AppColors.secondary : AppColors.primary;

  void _switchPortal(UserRole role) {
    if (role == _portal) return;
    setState(() => _portal = role);
    auth.selectedRole.value = role;
    role == UserRole.owner ? _tabCtrl.forward() : _tabCtrl.reverse();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    auth.signUpWithEmail(
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _bgCtrl,
              builder: (_, child) => CustomPaint(
                painter: _SignupBgPainter(
                  progress: _bgCtrl.value,
                  accent: _accent,
                ),
              ),
            ),
          ),
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StaggerIn(
                          index: 0,
                          child: AppTextField(
                            label: 'Full Name',
                            hint: 'Ahmed Khan',
                            controller: _nameCtrl,
                            prefixIcon: Icons.person_outline,
                            validator: Validators.name,
                          ),
                        ),
                        const SizedBox(height: 16),
                        StaggerIn(
                          index: 1,
                          child: AppTextField(
                            label: 'Email Address',
                            hint: 'you@example.com',
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            prefixIcon: Icons.email_outlined,
                            validator: Validators.email,
                          ),
                        ),
                        const SizedBox(height: 16),
                        StaggerIn(
                          index: 2,
                          child: AppTextField(
                            label: 'Password',
                            hint: 'Min 6 characters',
                            controller: _passwordCtrl,
                            obscureText: true,
                            prefixIcon: Icons.lock_outline,
                            validator: Validators.password,
                          ),
                        ),
                        const SizedBox(height: 16),
                        StaggerIn(
                          index: 3,
                          child: AppTextField(
                            label: 'Confirm Password',
                            hint: 'Re-enter password',
                            controller: _confirmCtrl,
                            obscureText: true,
                            prefixIcon: Icons.lock_outline,
                            validator: (v) => Validators.confirmPassword(
                              v,
                              _passwordCtrl.text,
                            ),
                            textInputAction: TextInputAction.done,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Portal context reminder
                        StaggerIn(
                          index: 4,
                          child: AnimatedBuilder(
                            animation: _tabCtrl,
                            builder: (_, child) => Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: _accent.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _accent.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _portal == UserRole.owner
                                        ? Icons.stadium_rounded
                                        : Icons.sports_tennis_rounded,
                                    color: _accent,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _portal == UserRole.owner
                                          ? 'Registering as an Arena Owner'
                                          : 'Registering as a Customer (Player)',
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: _accent,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => _switchPortal(
                                      _portal == UserRole.owner
                                          ? UserRole.customer
                                          : UserRole.owner,
                                    ),
                                    child: Text(
                                      'Switch',
                                      style: AppTextStyles.caption.copyWith(
                                        color: _accent.withValues(alpha: 0.7),
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        StaggerIn(
                          index: 5,
                          child: Obx(
                            () => ShimmerBounceButton(
                              label: 'Create Account',
                              accent: _accent,
                              isLoading: auth.isLoading.value,
                              onTap: _submit,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        StaggerIn(
                          index: 6,
                          child: Center(
                            child: GestureDetector(
                              onTap: () => Get.toNamed(
                                AppRoutes.login,
                                arguments: _portal,
                              ),
                              child: RichText(
                                text: TextSpan(
                                  text: 'Already have an account? ',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: 'Sign In',
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        color: _accent,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
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
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return AnimatedBuilder(
      animation: _tabCtrl,
      builder: (_, child) {
        final t = _tabCtrl.value;
        final bgColor = Color.lerp(
          AppColors.primary.withValues(alpha: 0.08),
          AppColors.secondary.withValues(alpha: 0.08),
          t,
        )!;

        return Container(
          color: bgColor,
          padding: const EdgeInsets.fromLTRB(24, 56, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => Get.back(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Portal tabs
              Container(
                height: 44,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    _portalTab(
                      'Customer',
                      UserRole.customer,
                      AppColors.primary,
                    ),
                    _portalTab(
                      'Arena Owner',
                      UserRole.owner,
                      AppColors.secondary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Text(
                _portal == UserRole.owner
                    ? 'Create Owner\nAccount'
                    : 'Create Your\nAccount',
                style: AppTextStyles.headlineLarge.copyWith(height: 1.15),
              ),
              const SizedBox(height: 6),
              Text(
                _portal == UserRole.owner
                    ? 'List your arena and start accepting bookings today'
                    : 'Join thousands of players booking courts near you',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _portalTab(String label, UserRole role, Color accent) {
    final selected = _portal == role;
    return Expanded(
      child: GestureDetector(
        onTap: () => _switchPortal(role),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            color: selected ? accent : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTextStyles.label.copyWith(
              color: selected ? AppColors.onPrimary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _SignupBgPainter extends CustomPainter {
  final double progress;
  final Color accent;
  const _SignupBgPainter({required this.progress, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.18)
      ..strokeWidth = 0.5;
    for (double i = -size.height; i < size.width + size.height; i += 36) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        gridPaint,
      );
    }

    final t = progress * math.pi * 2;
    _drawOrb(
      canvas,
      size,
      cx: size.width * 0.8 + math.cos(t * 0.6) * size.width * 0.1,
      cy: size.height * 0.15 + math.sin(t * 0.5) * size.height * 0.06,
      r: size.width * 0.52,
      color: accent.withValues(alpha: 0.09),
    );
    _drawOrb(
      canvas,
      size,
      cx: size.width * 0.2 + math.sin(t * 0.7) * size.width * 0.08,
      cy: size.height * 0.8 + math.cos(t * 0.4) * size.height * 0.07,
      r: size.width * 0.48,
      color: AppColors.secondary.withValues(alpha: 0.07),
    );
  }

  void _drawOrb(
    Canvas canvas,
    Size size, {
    required double cx,
    required double cy,
    required double r,
    required Color color,
  }) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, Colors.transparent],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    canvas.drawCircle(Offset(cx, cy), r, paint);
  }

  @override
  bool shouldRepaint(covariant _SignupBgPainter old) =>
      old.progress != progress || old.accent != accent;
}
