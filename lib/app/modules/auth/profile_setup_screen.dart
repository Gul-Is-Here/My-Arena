import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/validators.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final auth = AuthController.to;

  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl =
        TextEditingController(text: auth.currentUser.value?.name ?? '');
    _phoneCtrl =
        TextEditingController(text: auth.currentUser.value?.phone ?? '');
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    auth.completeProfile(
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
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
                const SizedBox(height: 32),

                // Progress indicator
                Row(
                  children: List.generate(3, (i) => Expanded(
                    child: Container(
                      height: 3,
                      margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                      decoration: BoxDecoration(
                        color: i == 0
                            ? AppColors.primary
                            : AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  )),
                ),
                const SizedBox(height: 32),

                // Header
                Text('Almost there!',
                    style: AppTextStyles.headlineLarge),
                const SizedBox(height: 8),
                Text(
                  'Set up your profile so others can recognise you.',
                  style: AppTextStyles.bodyLarge
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 40),

                const SizedBox(height: 8),

                // Form
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      AppTextField(
                        label: 'Full Name',
                        hint: 'Ahmed Khan',
                        controller: _nameCtrl,
                        prefixIcon: Icons.person_outline,
                        validator: Validators.name,
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        label: 'Phone Number',
                        hint: '03XX-XXXXXXX',
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        prefixIcon: Icons.phone_outlined,
                        validator: Validators.phone,
                        textInputAction: TextInputAction.done,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                Obx(() => AppButton(
                      label: 'Complete Setup',
                      isLoading: auth.isLoading.value,
                      onPressed: _submit,
                    )),
                const SizedBox(height: 16),

                Center(
                  child: TextButton(
                    onPressed: () {
                      auth.completeProfile(
                        name: auth.currentUser.value?.name ?? '',
                        phone: '',
                      );
                    },
                    child: Text(
                      'Skip for now',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textDisabled),
                    ),
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
