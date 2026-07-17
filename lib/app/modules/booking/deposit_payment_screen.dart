import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../controllers/booking_controller.dart';
import '../../routes/app_routes.dart';
import '../../widgets/slot_picker_widgets.dart';

class DepositPaymentScreen extends StatefulWidget {
  const DepositPaymentScreen({super.key});

  @override
  State<DepositPaymentScreen> createState() => _DepositPaymentScreenState();
}

class _DepositPaymentScreenState extends State<DepositPaymentScreen> {
  XFile? _screenshot;
  bool _submitting = false;
  bool _copied = false;

  Future<void> _pickScreenshot() async {
    final picked = await Get.find<BookingController>().pickDepositScreenshot();
    if (picked != null) setState(() => _screenshot = picked);
  }

  Future<void> _copyNumber(String number) async {
    await Clipboard.setData(ClipboardData(text: number));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.find<BookingController>();
    final b = c.draft;

    if (b == null) {
      return Scaffold(
        backgroundColor: SlotPickerColors.bg,
        body: const Center(
          child: Text(
            'No booking in progress',
            style: TextStyle(color: SlotPickerColors.muted),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: SlotPickerColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.arrow_back,
                        color: SlotPickerColors.onBg),
                  ),
                  const Expanded(
                    child: Text(
                      'Deposit Payment',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: SlotPickerColors.onBg,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: BookingStepIndicator(
                labels: const ['DATE', 'SUMMARY', 'PAYMENT'],
                currentIndex: 2,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      'DEPOSIT DUE',
                      style: TextStyle(
                        color: SlotPickerColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      'PKR ${b.depositAmount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: SlotPickerColors.green,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Obx(() => Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: SlotPickerColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.06)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE9432E)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.account_balance_wallet_outlined,
                                    color: Color(0xFFE9432E),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'JazzCash',
                                        style: TextStyle(
                                          color: SlotPickerColors.muted,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        c.jazzCashNumber.value,
                                        style: const TextStyle(
                                          color: SlotPickerColors.onBg,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy_outlined,
                                      size: 20, color: SlotPickerColors.green),
                                  onPressed: () =>
                                      _copyNumber(c.jazzCashNumber.value),
                                ),
                              ],
                            ),
                          )),
                      if (_copied)
                        Positioned(
                          top: -14,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: SlotPickerColors.greenCta,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'COPIED!',
                              style: TextStyle(
                                color: Color(0xFF0A1628),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: _pickScreenshot,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: _screenshot != null
                            ? SlotPickerColors.green.withValues(alpha: 0.06)
                            : SlotPickerColors.surface2,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _screenshot != null
                              ? SlotPickerColors.green
                              : Colors.white.withValues(alpha: 0.15),
                          width: _screenshot != null ? 1.5 : 1,
                          strokeAlign: BorderSide.strokeAlignInside,
                        ),
                      ),
                      child: _screenshot != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.file(
                                File(_screenshot!.path),
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 32, horizontal: 16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: Colors.white
                                          .withValues(alpha: 0.06),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.cloud_upload_outlined,
                                      color: SlotPickerColors.muted,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Attach Payment Screenshot',
                                    style: TextStyle(
                                      color: SlotPickerColors.onBg,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'JPG, PNG up to 5MB',
                                    style: TextStyle(
                                      color: SlotPickerColors.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'How it works',
                    style: TextStyle(
                      color: SlotPickerColors.onBg,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _step(1, 'Send the deposit to the JazzCash number above'),
                  _step(2, 'Take a screenshot of the payment confirmation'),
                  _step(3, 'Attach it below and submit for owner approval'),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: SlotPickerColors.bg,
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                ),
              ),
              child: Material(
                color: _screenshot == null
                    ? SlotPickerColors.surface
                    : SlotPickerColors.greenCta,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _screenshot == null || _submitting
                      ? null
                      : () async {
                          setState(() => _submitting = true);
                          try {
                            await c.submitDeposit(
                              File(_screenshot!.path),
                              c.jazzCashNumber.value,
                            );
                            Get.offNamed(AppRoutes.bookingConfirmation);
                          } catch (e) {
                            if (!mounted) return;
                            setState(() => _submitting = false);
                            Get.snackbar('Submission failed', e.toString(),
                                snackPosition: SnackPosition.BOTTOM,
                                margin: const EdgeInsets.all(16));
                          }
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    alignment: Alignment.center,
                    child: _submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Color(0xFF0A1628),
                            ),
                          )
                        : Text(
                            'SUBMIT FOR APPROVAL',
                            style: TextStyle(
                              color: _screenshot == null
                                  ? SlotPickerColors.muted
                                  : const Color(0xFF0A1628),
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              letterSpacing: 0.4,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _step(int n, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: SlotPickerColors.green.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$n',
                style: const TextStyle(
                  color: SlotPickerColors.green,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                text,
                style: const TextStyle(
                  color: SlotPickerColors.muted,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
