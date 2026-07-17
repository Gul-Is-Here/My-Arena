import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/booking_controller.dart';
import '../../data/models/booking_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_text_field.dart';

/// Cancellation with deduction breakdown + refund bank details.
/// Route argument: booking id.
class CancellationScreen extends StatefulWidget {
  const CancellationScreen({super.key});

  @override
  State<CancellationScreen> createState() => _CancellationScreenState();
}

class _CancellationScreenState extends State<CancellationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bankCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();

  @override
  void dispose() {
    _bankCtrl.dispose();
    _accountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.find<BookingController>();
    final String id = Get.arguments as String;
    final booking = c.bookings.firstWhereOrNull((b) => b.id == id);

    if (booking == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Booking not found')),
      );
    }

    final deduction = booking.depositAmount *
        BookingSettings.cancellationDeductPercent /
        100;
    final refund = booking.depositAmount - deduction;

    return Scaffold(
      appBar: AppBar(title: const Text('Cancel Booking')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(booking.arenaName, style: AppTextStyles.titleMedium),
                  Text(
                    '${booking.courtName} · ${booking.timeRange}',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textGrey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Text('Refund Breakdown', style: AppTextStyles.titleMedium),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                children: [
                  _row('Deposit paid',
                      'PKR ${booking.depositAmount.toStringAsFixed(0)}'),
                  const SizedBox(height: 10),
                  _row(
                    'Cancellation fee (${BookingSettings.cancellationDeductPercent}%)',
                    '− PKR ${deduction.toStringAsFixed(0)}',
                    color: AppColors.error,
                  ),
                  const Divider(height: 24),
                  _row('Refund amount', 'PKR ${refund.toStringAsFixed(0)}',
                      color: AppColors.success, bold: true),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text('Refund Account', style: AppTextStyles.titleMedium),
            const SizedBox(height: 4),
            Text(
              'The owner will send your refund to this account.',
              style:
                  AppTextStyles.bodySmall.copyWith(color: AppColors.textGrey),
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Bank / Wallet Name',
              hint: 'e.g. HBL, JazzCash, Easypaisa',
              controller: _bankCtrl,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Account / IBAN Number',
              hint: 'e.g. 0300xxxxxxx or PKxx...',
              controller: _accountCtrl,
              keyboardType: TextInputType.text,
              validator: (v) =>
                  (v == null || v.trim().length < 8) ? 'Invalid account' : null,
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: AppButton(
            label: 'Confirm Cancellation',
            onPressed: () {
              if (!_formKey.currentState!.validate()) return;
              c.cancelBooking(
                  id, _bankCtrl.text.trim(), _accountCtrl.text.trim());
              Get.back();
              Get.snackbar(
                'Booking cancelled',
                'Refund of PKR ${refund.toStringAsFixed(0)} is pending from the owner.',
                snackPosition: SnackPosition.BOTTOM,
                margin: const EdgeInsets.all(16),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value, {Color? color, bool bold = false}) {
    final style = (bold ? AppTextStyles.titleMedium : AppTextStyles.bodyMedium)
        .copyWith(color: color);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label, style: style), Text(value, style: style)],
    );
  }
}
