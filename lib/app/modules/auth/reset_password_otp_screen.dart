import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/validators.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/otp_fields.dart';

/// Password reset step 2 — enter the emailed 6-digit code
/// plus the new password (no reset links).
class ResetPasswordOtpScreen extends StatefulWidget {
  const ResetPasswordOtpScreen({super.key});

  @override
  State<ResetPasswordOtpScreen> createState() => _ResetPasswordOtpScreenState();
}

class _ResetPasswordOtpScreenState extends State<ResetPasswordOtpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final auth = AuthController.to;
  late final String email = (Get.arguments as String?) ?? '';
  String _otp = '';

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_otp.length < 6) {
      Get.snackbar('Incomplete code', 'Enter the 6-digit code from the email',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    auth.confirmPasswordReset(
      email: email,
      otp: _otp,
      newPassword: _passwordCtrl.text,
    );
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enter Reset Code')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Text('Set a new password', style: AppTextStyles.headlineLarge),
                const SizedBox(height: 8),
                Text(
                  'Enter the 6-digit code we sent to $email '
                  'and choose a new password.',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textGrey),
                ),
                const SizedBox(height: 32),
                OtpFields(onChanged: (v) => _otp = v),
                const SizedBox(height: 24),
                AppTextField(
                  label: 'New Password',
                  hint: 'Min 6 characters',
                  controller: _passwordCtrl,
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
                      Validators.confirmPassword(v, _passwordCtrl.text),
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 32),
                Obx(
                  () => AppButton(
                    label: 'Reset Password',
                    isLoading: auth.isLoading.value,
                    onPressed: _submit,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () => auth.resetPassword(email),
                    child: const Text('Resend Code'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
