import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../data/models/user_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/validators.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_text_field.dart';

/// Two-step signup: role select (Customer / Owner) → account details.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final auth = AuthController.to;

  int _step = 0; // 0 = role select, 1 = details

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
      appBar: AppBar(
        title: Text(_step == 0 ? 'Choose Your Role' : 'Create Account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_step == 1) {
              setState(() => _step = 0);
            } else {
              Get.back();
            }
          },
        ),
      ),
      body: SafeArea(
        child: _step == 0 ? _roleSelectStep() : _detailsStep(),
      ),
    );
  }

  // Step 1 — "Customer hun ya Owner?"
  Widget _roleSelectStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How will you use\nMy Arena?', style: AppTextStyles.displayLarge),
          const SizedBox(height: 8),
          Text(
            'You can always contact support to change this later.',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textGrey),
          ),
          const SizedBox(height: 32),
          Obx(
            () => Column(
              children: [
                _roleCard(
                  role: UserRole.customer,
                  icon: Icons.sports_tennis,
                  title: "I'm a Player",
                  subtitle:
                      'Discover arenas, book courts and join tournaments.',
                ),
                const SizedBox(height: 16),
                _roleCard(
                  role: UserRole.owner,
                  icon: Icons.stadium_outlined,
                  title: "I'm an Arena Owner",
                  subtitle:
                      'List your arena, manage courts, bookings and events.',
                ),
              ],
            ),
          ),
          const Spacer(),
          AppButton(
            label: 'Continue',
            onPressed: () => setState(() => _step = 1),
          ),
        ],
      ),
    );
  }

  Widget _roleCard({
    required UserRole role,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final bool selected = auth.selectedRole.value == role;
    return AppCard(
      onTap: () => auth.selectedRole.value = role,
      border: Border.all(
        color: selected ? AppColors.primary : Colors.transparent,
        width: 2,
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: (selected ? AppColors.primary : AppColors.textGrey)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              size: 32,
              color: selected ? AppColors.primary : AppColors.textGrey,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.titleLarge),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textGrey),
                ),
              ],
            ),
          ),
          Icon(
            selected ? Icons.check_circle : Icons.circle_outlined,
            color: selected ? AppColors.primary : AppColors.textGrey,
          ),
        ],
      ),
    );
  }

  // Step 2 — account details
  Widget _detailsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Obx(
              () => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  auth.selectedRole.value == UserRole.owner
                      ? '🏟 Arena Owner'
                      : '⚽ Player',
                  style:
                      AppTextStyles.label.copyWith(color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 24),
            AppTextField(
              label: 'Full Name',
              hint: 'Ahmed Khan',
              controller: _nameCtrl,
              prefixIcon: Icons.person_outline,
              validator: Validators.name,
            ),
            const SizedBox(height: 16),
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
              hint: 'Min 6 characters',
              controller: _passwordCtrl,
              obscureText: true,
              prefixIcon: Icons.lock_outline,
              validator: Validators.password,
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Confirm Password',
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
                label: 'Create Account',
                isLoading: auth.isLoading.value,
                onPressed: _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
