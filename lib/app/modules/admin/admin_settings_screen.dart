import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/admin_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';

/// Platform settings — mirrors Firestore settings/booking.
class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final admin = AdminController.to;
  late final _depositCtrl =
      TextEditingController(text: '${admin.depositPercent.value}');
  late final _deductCtrl =
      TextEditingController(text: '${admin.cancellationDeductPercent.value}');
  late final _minHoursCtrl =
      TextEditingController(text: '${admin.minCancelHoursBefore.value}');
  late final _jazzCashCtrl =
      TextEditingController(text: admin.jazzCashNumber.value);

  @override
  void dispose() {
    _depositCtrl.dispose();
    _deductCtrl.dispose();
    _minHoursCtrl.dispose();
    _jazzCashCtrl.dispose();
    super.dispose();
  }

  String? _percent(String? v) {
    final n = int.tryParse(v ?? '');
    return (n == null || n < 0 || n > 100) ? '0–100' : null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    admin.saveSettings(
      deposit: int.parse(_depositCtrl.text),
      deduct: int.parse(_deductCtrl.text),
      minHours: int.parse(_minHoursCtrl.text),
      jazzCash: _jazzCashCtrl.text.trim(),
    );
    Get.back();
    Get.snackbar('Settings saved', 'Platform booking settings updated.',
        snackPosition: SnackPosition.BOTTOM, margin: const EdgeInsets.all(16));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Platform Settings')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Booking Rules', style: AppTextStyles.titleLarge),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Deposit percent (%)',
              controller: _depositCtrl,
              keyboardType: TextInputType.number,
              validator: _percent,
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Cancellation deduction (%)',
              controller: _deductCtrl,
              keyboardType: TextInputType.number,
              validator: _percent,
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Min cancel hours before start',
              controller: _minHoursCtrl,
              keyboardType: TextInputType.number,
              validator: (v) =>
                  (int.tryParse(v ?? '') ?? -1) >= 0 ? null : 'Invalid',
            ),
            const SizedBox(height: 24),
            Text('Payments', style: AppTextStyles.titleLarge),
            const SizedBox(height: 16),
            AppTextField(
              label: 'JazzCash number',
              controller: _jazzCashCtrl,
              keyboardType: TextInputType.phone,
              validator: (v) =>
                  (v == null || v.trim().length < 7) ? 'Invalid' : null,
            ),
            const SizedBox(height: 12),
            Text(
              'Boost pricing is managed per-duration in a later iteration.',
              style:
                  AppTextStyles.bodySmall.copyWith(color: AppColors.textGrey),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: AppButton(label: 'Save Settings', onPressed: _save),
        ),
      ),
    );
  }
}
