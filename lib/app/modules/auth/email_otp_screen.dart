import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_button.dart';
import '../../widgets/otp_fields.dart';

/// Signup email verification — the user enters the 6-digit code
/// emailed by the sendEmailOtp cloud function.
class EmailOtpScreen extends StatefulWidget {
  const EmailOtpScreen({super.key});

  @override
  State<EmailOtpScreen> createState() => _EmailOtpScreenState();
}

class _EmailOtpScreenState extends State<EmailOtpScreen> {
  final auth = AuthController.to;
  late final String email = (Get.arguments as String?) ?? '';
  String _otp = '';

  void _verify() {
    if (_otp.length < 6) return;
    auth.verifyEmailOtp(_otp);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Email')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text('Check your inbox', style: AppTextStyles.headlineLarge),
              const SizedBox(height: 8),
              Text(
                'Enter the 6-digit code we sent to\n$email',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textGrey),
              ),
              const SizedBox(height: 40),
              OtpFields(
                onChanged: (v) => _otp = v,
                onCompleted: (_) => _verify(),
              ),
              const SizedBox(height: 40),
              Obx(
                () => AppButton(
                  label: 'Verify Email',
                  isLoading: auth.isLoading.value,
                  onPressed: _verify,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: auth.resendEmailOtp,
                  child: const Text('Resend Code'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
