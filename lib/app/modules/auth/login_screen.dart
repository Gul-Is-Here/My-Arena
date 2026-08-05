import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../data/models/user_model.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/validators.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import 'auth_fx.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final auth = AuthController.to;

  late UserRole _portal;
  bool _phoneMode = false;
  late final AnimationController _tabCtrl;
  late final Animation<double> _tabSlide;
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
    _tabSlide = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _tabCtrl, curve: Curves.easeInOut));

    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    if (_portal == UserRole.owner) _tabCtrl.forward();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _bgCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Color get _accent =>
      _portal == UserRole.owner ? AppColors.secondary : AppColors.primary;

  void _switchPortal(UserRole role) {
    if (role == _portal) return;
    setState(() => _portal = role);
    auth.selectedRole.value = role;
    if (role == UserRole.owner) {
      _tabCtrl.forward();
    } else {
      _tabCtrl.reverse();
    }
  }

  void _submit() {
    if (_phoneMode) {
      if (_phoneCtrl.text.trim().isEmpty) return;
      auth.sendOtp(_phoneCtrl.text.trim());
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    auth.signInWithEmail(
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
          // Animated background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _bgCtrl,
              builder: (_, child) => CustomPaint(
                painter: _AuthBgPainter(
                  progress: _bgCtrl.value,
                  accent: _accent,
                ),
              ),
            ),
          ),
          CustomScrollView(
            slivers: [
              // Header sliver with portal tabs
              SliverToBoxAdapter(child: _buildHeader()),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Email / Phone mode chips
                      StaggerIn(
                        index: 0,
                        child: Row(
                          children: [
                            _modeChip(
                              'Email',
                              !_phoneMode,
                              () => setState(() => _phoneMode = false),
                            ),
                            const SizedBox(width: 10),
                            _modeChip(
                              'Phone OTP',
                              _phoneMode,
                              () => setState(() => _phoneMode = true),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Form
                      StaggerIn(
                        index: 1,
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              if (_phoneMode) ...[
                                AppTextField(
                                  label: 'Phone Number',
                                  hint: '03XX-XXXXXXX',
                                  controller: _phoneCtrl,
                                  keyboardType: TextInputType.phone,
                                  prefixIcon: Icons.phone_outlined,
                                  validator: Validators.phone,
                                  textInputAction: TextInputAction.done,
                                ),
                              ] else ...[
                                AppTextField(
                                  label: 'Email Address',
                                  hint: 'you@example.com',
                                  controller: _emailCtrl,
                                  keyboardType: TextInputType.emailAddress,
                                  prefixIcon: Icons.email_outlined,
                                  validator: Validators.email,
                                ),
                                const SizedBox(height: 16),
                                AppTextField(
                                  label: 'Password',
                                  hint: '••••••••',
                                  controller: _passwordCtrl,
                                  obscureText: true,
                                  prefixIcon: Icons.lock_outline,
                                  validator: Validators.password,
                                  textInputAction: TextInputAction.done,
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () =>
                                        Get.toNamed(AppRoutes.forgotPassword),
                                    child: Text(
                                      'Forgot Password?',
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: _accent,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),

                              // Primary CTA
                              Obx(
                                () => ShimmerBounceButton(
                                  label: _phoneMode ? 'Send OTP' : 'Sign In',
                                  accent: _accent,
                                  isLoading: auth.isLoading.value,
                                  onTap: _submit,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Divider
                      StaggerIn(
                        index: 2,
                        child: Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              child: Text(
                                'or continue with',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textDisabled,
                                ),
                              ),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Social buttons
                      StaggerIn(
                        index: 3,
                        child: AppButton(
                          label: 'Continue with Google',
                          outlined: true,
                          icon: Icons.g_mobiledata,
                          onPressed: auth.signInWithGoogle,
                        ),
                      ),
                      if (auth.isAppleAvailable) ...[
                        const SizedBox(height: 12),
                        StaggerIn(
                          index: 4,
                          child: AppButton(
                            label: 'Continue with Apple',
                            outlined: true,
                            icon: Icons.apple,
                            onPressed: auth.signInWithApple,
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),

                      // Sign up link
                      StaggerIn(
                        index: 5,
                        child: Center(
                          child: GestureDetector(
                            onTap: () => Get.toNamed(
                              AppRoutes.signup,
                              arguments: _portal,
                            ),
                            child: RichText(
                              text: TextSpan(
                                text: "Don't have an account? ",
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Sign Up',
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
                      const SizedBox(height: 12),

                      // Activate owner account — only shown to owner portal
                      if (_portal == UserRole.owner) ...[
                        Center(
                          child: TextButton(
                            onPressed: () =>
                                Get.toNamed(AppRoutes.activateOwner),
                            child: Text(
                              'Have an owner invitation? Activate Account',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textDisabled,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        Center(
                          child: TextButton(
                            onPressed: () =>
                                Get.toNamed(AppRoutes.activateStaff),
                            child: Text(
                              'Have a staff invitation? Activate Staff Account',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textDisabled,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ],
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
        final t = _tabSlide.value;
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
              // Back button
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
                      t,
                    ),
                    _portalTab(
                      'Arena Owner',
                      UserRole.owner,
                      AppColors.secondary,
                      t,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Heading
              Text(
                _portal == UserRole.owner ? 'Welcome Back' : 'Welcome Back',
                style: AppTextStyles.headlineLarge,
              ),
              const SizedBox(height: 6),
              Text(
                _portal == UserRole.owner
                    ? 'Sign in to manage your arenas and bookings'
                    : 'Sign in to discover and book sports venues',
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

  Widget _portalTab(String label, UserRole role, Color accent, double t) {
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

  Widget _modeChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? _accent.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? _accent : AppColors.border),
        ),
        child: Text(
          label,
          style: AppTextStyles.label.copyWith(
            color: selected ? _accent : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Animated background: slow-drifting orbs + diagonal line grid.
class _AuthBgPainter extends CustomPainter {
  final double progress;
  final Color accent;
  const _AuthBgPainter({required this.progress, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    // Diagonal grid
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

    // Drifting glow blobs — two large, slow, sinusoidal
    final t = progress * math.pi * 2;
    _drawOrb(
      canvas,
      size,
      cx: size.width * 0.15 + math.sin(t * 0.7) * size.width * 0.1,
      cy: size.height * 0.18 + math.cos(t * 0.5) * size.height * 0.06,
      r: size.width * 0.55,
      color: accent.withValues(alpha: 0.09),
    );
    _drawOrb(
      canvas,
      size,
      cx: size.width * 0.85 + math.cos(t * 0.6) * size.width * 0.08,
      cy: size.height * 0.72 + math.sin(t * 0.4) * size.height * 0.07,
      r: size.width * 0.5,
      color: AppColors.secondary.withValues(alpha: 0.07),
    );
    // Small accent orb top-right
    _drawOrb(
      canvas,
      size,
      cx: size.width * 0.9 + math.sin(t * 1.1) * size.width * 0.05,
      cy: size.height * 0.1 + math.cos(t * 0.9) * size.height * 0.04,
      r: size.width * 0.22,
      color: accent.withValues(alpha: 0.11),
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
  bool shouldRepaint(covariant _AuthBgPainter old) =>
      old.progress != progress || old.accent != accent;
}
