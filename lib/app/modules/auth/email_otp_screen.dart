import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_button.dart';
import '../../widgets/otp_fields.dart';

class EmailOtpScreen extends StatefulWidget {
  const EmailOtpScreen({super.key});

  @override
  State<EmailOtpScreen> createState() => _EmailOtpScreenState();
}

class _EmailOtpScreenState extends State<EmailOtpScreen>
    with SingleTickerProviderStateMixin {
  final auth = AuthController.to;
  late final String email = (Get.arguments as String?) ?? '';
  String _otp = '';

  // Countdown for resend
  int _countdown = 60;
  Timer? _timer;

  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<double>(begin: 30, end: 0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
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
    auth.verifyEmailOtp(_otp);
  }

  Future<void> _resend() async {
    await auth.resendEmailOtp();
    _startCountdown();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) => Opacity(
            opacity: _opacity.value,
            child: Transform.translate(
                offset: Offset(0, _slide.value), child: child),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),

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
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 16, color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 40),

                // Email icon
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.mark_email_unread_outlined,
                      size: 36, color: AppColors.primary),
                ),
                const SizedBox(height: 24),

                Text('Check your\ninbox', style: AppTextStyles.headlineLarge),
                const SizedBox(height: 10),
                RichText(
                  text: TextSpan(
                    text: 'We sent a 6-digit code to\n',
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
                const SizedBox(height: 48),

                OtpFields(
                  onChanged: (v) => setState(() => _otp = v),
                  onCompleted: (_) => _verify(),
                ),
                const SizedBox(height: 40),

                Obx(() => AppButton(
                      label: 'Verify Email',
                      isLoading: auth.isLoading.value,
                      onPressed: _otp.length == 6 ? _verify : null,
                    )),
                const SizedBox(height: 24),

                Center(
                  child: _countdown > 0
                      ? Text(
                          'Resend code in ${_countdown}s',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textDisabled),
                        )
                      : TextButton(
                          onPressed: _resend,
                          child: Text(
                            'Resend Code',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                ),

                const Spacer(),

                // Info hint
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 18, color: AppColors.textDisabled),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Check your spam folder if you don\'t see the email within a minute.',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textDisabled),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
