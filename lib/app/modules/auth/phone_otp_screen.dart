import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_button.dart';
import '../../widgets/otp_fields.dart';

class PhoneOtpScreen extends StatefulWidget {
  const PhoneOtpScreen({super.key});

  @override
  State<PhoneOtpScreen> createState() => _PhoneOtpScreenState();
}

class _PhoneOtpScreenState extends State<PhoneOtpScreen>
    with SingleTickerProviderStateMixin {
  final auth = AuthController.to;
  late final String phone = (Get.arguments as String?) ?? '';
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
    super.dispose();
  }

  void _verify() {
    if (_otp.length < 6) return;
    auth.verifyOtp(phone, _otp);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _ctrl,
          child: Padding(
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
                    color: AppColors.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.sms_outlined,
                      size: 36, color: AppColors.secondary),
                ),
                const SizedBox(height: 24),

                Text('Verify your\nphone number',
                    style: AppTextStyles.headlineLarge),
                const SizedBox(height: 10),
                RichText(
                  text: TextSpan(
                    text: 'A 6-digit code was sent to\n',
                    style: AppTextStyles.bodyLarge
                        .copyWith(color: AppColors.textSecondary),
                    children: [
                      TextSpan(
                        text: phone,
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),

                OtpFields(
                  onChanged: (v) => setState(() => _otp = v),
                  onCompleted: (_) => _verify(),
                ),
                const SizedBox(height: 40),

                Obx(() => AppButton(
                      label: 'Verify Phone',
                      isLoading: auth.isLoading.value,
                      onPressed: _otp.length == 6 ? _verify : null,
                    )),
                const SizedBox(height: 24),

                Center(
                  child: _countdown > 0
                      ? Text(
                          'Resend in ${_countdown}s',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textDisabled),
                        )
                      : TextButton(
                          onPressed: () {
                            auth.sendOtp(phone);
                            _startCountdown();
                          },
                          child: Text(
                            'Resend Code',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
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
}
