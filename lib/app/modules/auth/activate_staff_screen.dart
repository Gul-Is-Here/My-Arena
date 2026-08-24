import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../../controllers/auth_controller.dart';
import '../../data/models/user_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';

class ActivateStaffScreen extends StatefulWidget {
  const ActivateStaffScreen({super.key});

  @override
  State<ActivateStaffScreen> createState() => _ActivateStaffScreenState();
}

class _ActivateStaffScreenState extends State<ActivateStaffScreen> {
  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  bool _loading = false;
  String _error = '';

  static const String _baseUrl =
      'https://us-central1-arena-managment-system.cloudfunctions.net';

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    _passwordCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    final email = _emailCtrl.text.trim();
    final code = _codeCtrl.text.trim().toUpperCase();
    final name = _nameCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || !GetUtils.isEmail(email)) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    if (code.length < 8) {
      setState(() => _error = 'Enter the full 8-character activation code.');
      return;
    }
    if (name.isEmpty) {
      setState(() => _error = 'Enter your name.');
      return;
    }
    if (password.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters.');
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final resp = await http
          .post(
            Uri.parse('$_baseUrl/staffManagement'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'action': 'accept_staff_invitation',
              'email': email,
              'code': code,
              'name': name,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 30));

      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      if (resp.statusCode != 200 || json['success'] != true) {
        throw Exception(json['message'] ?? 'Activation failed');
      }

      // Staff belong to the owner portal — set the portal before signing in
      // so _isPortalMismatch doesn't treat them as a customer.
      AuthController.to.selectedRole.value = UserRole.owner;
      await AuthController.to.signInWithEmail(email: email, password: password);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Activate Staff Account'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.badge_outlined,
                        color: AppColors.primary, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Staff Invitation',
                              style: AppTextStyles.titleMedium
                                  .copyWith(color: AppColors.primary)),
                          Text(
                            'Enter the code from your invitation email to activate your account.',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              AppTextField(
                label: 'Email Address',
                hint: 'your@email.com',
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              Text('Activation Code', style: AppTextStyles.label),
              const SizedBox(height: 8),
              TextField(
                controller: _codeCtrl,
                textCapitalization: TextCapitalization.characters,
                style: AppTextStyles.titleLarge.copyWith(
                    letterSpacing: 6, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'XXXXXXXX',
                  hintStyle: AppTextStyles.titleLarge.copyWith(
                      letterSpacing: 6, color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.elevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                ),
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Your Name',
                hint: 'Full name',
                controller: _nameCtrl,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Create Password',
                hint: 'Min 8 characters',
                controller: _passwordCtrl,
                obscureText: true,
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.error, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error,
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.error)),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 28),
              AppButton(
                label: 'Activate Account',
                onPressed: _loading ? null : _activate,
                isLoading: _loading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
