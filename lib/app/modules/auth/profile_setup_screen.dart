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

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final auth = AuthController.to;
  late final _nameCtrl =
      TextEditingController(text: auth.currentUser.value?.name ?? '');
  late final _phoneCtrl =
      TextEditingController(text: auth.currentUser.value?.phone ?? '');

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
      appBar: AppBar(title: const Text('Set Up Profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 16),
                // Avatar picker (image upload wired in backend phase)
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 56,
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.15),
                      child: const Icon(
                        Icons.person,
                        size: 56,
                        color: AppColors.primary,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () => Get.snackbar(
                          'Coming soon',
                          'Avatar upload will be added with Firebase Storage',
                          snackPosition: SnackPosition.BOTTOM,
                          margin: const EdgeInsets.all(16),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Add a profile photo',
                  style:
                      AppTextStyles.bodySmall.copyWith(color: AppColors.textGrey),
                ),
                const SizedBox(height: 32),
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
                const SizedBox(height: 40),
                Obx(
                  () => AppButton(
                    label: 'Finish',
                    isLoading: auth.isLoading.value,
                    onPressed: _submit,
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
