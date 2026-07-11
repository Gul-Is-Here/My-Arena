import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/validators.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final auth = AuthController.to;

  bool _phoneMode = false;

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_phoneMode) {
      auth.sendOtp(_phoneCtrl.text.trim());
    } else {
      auth.signInWithEmail(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                Text('Welcome Back 👋', style: AppTextStyles.displayLarge),
                const SizedBox(height: 8),
                Text(
                  'Sign in to continue to My Arena',
                  style: AppTextStyles.bodyLarge
                      .copyWith(color: AppColors.textGrey),
                ),
                const SizedBox(height: 32),

                // Email / Phone mode toggle
                Row(
                  children: [
                    _modeChip('Email', !_phoneMode,
                        () => setState(() => _phoneMode = false)),
                    const SizedBox(width: 12),
                    _modeChip('Phone OTP', _phoneMode,
                        () => setState(() => _phoneMode = true)),
                  ],
                ),
                const SizedBox(height: 24),

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
                    label: 'Email',
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
                      onPressed: () => Get.toNamed(AppRoutes.forgotPassword),
                      child: const Text('Forgot Password?'),
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                Obx(
                  () => AppButton(
                    label: _phoneMode ? 'Send OTP' : 'Sign In',
                    isLoading: auth.isLoading.value,
                    onPressed: _submit,
                  ),
                ),
                const SizedBox(height: 24),

                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('OR',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textGrey)),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 24),

                AppButton(
                  label: 'Continue with Google',
                  outlined: true,
                  icon: Icons.g_mobiledata,
                  onPressed: auth.signInWithGoogle,
                ),
                const SizedBox(height: 32),

                Center(
                  child: TextButton(
                    onPressed: () => Get.toNamed(AppRoutes.signup),
                    child: RichText(
                      text: TextSpan(
                        text: "Don't have an account? ",
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.textGrey),
                        children: [
                          TextSpan(
                            text: 'Sign Up',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : AppColors.textGrey.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: AppTextStyles.label.copyWith(
            color: selected ? Colors.white : AppColors.textGrey,
          ),
        ),
      ),
    );
  }
}
