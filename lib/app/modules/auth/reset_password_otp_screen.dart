import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/validators.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/otp_fields.dart';

class ResetPasswordOtpScreen extends StatefulWidget {
  const ResetPasswordOtpScreen({super.key});

  @override
  State<ResetPasswordOtpScreen> createState() =>
      _ResetPasswordOtpScreenState();
}

class _ResetPasswordOtpScreenState extends State<ResetPasswordOtpScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final auth = AuthController.to;

  late final String email = (Get.arguments as String?) ?? '';
  String _otp = '';

  int _countdown = 60;
  Timer? _timer;

  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _ctrl.forward();
    _startCountdown();
  }

  void _startCountdown() {
    _countdown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_otp.length < 6) {
      Get.snackbar('Enter the code', 'Enter the 6-digit code first.',
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16));
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    auth.confirmPasswordReset(
      email: email,
      otp: _otp,
      newPassword: _passCtrl.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _ctrl,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
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
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 16, color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 40),

                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.shield_outlined,
                      size: 36, color: AppColors.primary),
                ),
                const SizedBox(height: 24),

                Text('Set new\npassword', style: AppTextStyles.headlineLarge),
                const SizedBox(height: 10),
                RichText(
                  text: TextSpan(
                    text: 'Enter the code sent to ',
                    style: AppTextStyles.bodyLarge
                        .copyWith(color: AppColors.textSecondary),
                    children: [
                      TextSpan(
                        text: email,
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // OTP fields
                OtpFields(
                  onChanged: (v) => setState(() => _otp = v),
                ),
                const SizedBox(height: 10),

                // Resend countdown
                _countdown > 0
                    ? Text(
                        'Resend code in ${_countdown}s',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textDisabled),
                      )
                    : TextButton(
                        style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                        onPressed: () {
                          auth.resetPassword(email);
                          _startCountdown();
                        },
                        child: Text(
                          'Resend Code',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                const SizedBox(height: 32),

                // New password fields
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      AppTextField(
                        label: 'New Password',
                        hint: 'Min 6 characters',
                        controller: _passCtrl,
                        obscureText: true,
                        prefixIcon: Icons.lock_outline,
                        validator: Validators.password,
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        label: 'Confirm New Password',
                        hint: 'Re-enter password',
                        controller: _confirmCtrl,
                        obscureText: true,
                        prefixIcon: Icons.lock_outline,
                        validator: (v) =>
                            Validators.confirmPassword(v, _passCtrl.text),
                        textInputAction: TextInputAction.done,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                Obx(() => AppButton(
                      label: 'Update Password',
                      isLoading: auth.isLoading.value,
                      onPressed: _submit,
                    )),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
