import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_button.dart';

class PhoneOtpScreen extends StatefulWidget {
  const PhoneOtpScreen({super.key});

  @override
  State<PhoneOtpScreen> createState() => _PhoneOtpScreenState();
}

class _PhoneOtpScreenState extends State<PhoneOtpScreen> {
  final auth = AuthController.to;
  late final String phone = (Get.arguments as String?) ?? '';

  static const int _otpLength = 6;
  final List<TextEditingController> _controllers =
      List.generate(_otpLength, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(_otpLength, (_) => FocusNode());

  String get _otp => _controllers.map((c) => c.text).join();

  void _verify() {
    if (_otp.length < _otpLength) return;
    auth.verifyOtp(phone, _otp);
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Phone')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text('Enter the code', style: AppTextStyles.headlineLarge),
              const SizedBox(height: 8),
              Text(
                'A 6-digit code was sent to $phone\n(dummy code: 123456)',
                style:
                    AppTextStyles.bodyMedium.copyWith(color: AppColors.textGrey),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(_otpLength, (i) => _otpBox(i)),
              ),
              const SizedBox(height: 40),
              Obx(
                () => AppButton(
                  label: 'Verify',
                  isLoading: auth.isLoading.value,
                  onPressed: _verify,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => auth.sendOtp(phone),
                  child: const Text('Resend Code'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _otpBox(int index) {
    return SizedBox(
      width: 48,
      height: 56,
      child: TextField(
        controller: _controllers[index],
        focusNode: _nodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: AppTextStyles.headlineMedium,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(counterText: ''),
        onChanged: (value) {
          if (value.isNotEmpty && index < _otpLength - 1) {
            _nodes[index + 1].requestFocus();
          } else if (value.isEmpty && index > 0) {
            _nodes[index - 1].requestFocus();
          }
          if (_otp.length == _otpLength) _verify();
        },
      ),
    );
  }
}
