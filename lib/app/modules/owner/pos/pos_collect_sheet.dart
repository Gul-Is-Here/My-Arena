import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../controllers/owner_booking_controller.dart';
import '../../../controllers/pos_controller.dart';
import '../../../data/models/booking_model.dart';
import '../../../data/models/pos_transaction_model.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import 'pos_receipt_service.dart';

final _pkr = NumberFormat('#,##0');

// ── Collect Balance Sheet ─────────────────────────────────────────────────

class PosCollectBalanceSheet extends StatefulWidget {
  final BookingModel booking;
  const PosCollectBalanceSheet({super.key, required this.booking});

  @override
  State<PosCollectBalanceSheet> createState() => _PosCollectBalanceSheetState();
}

class _PosCollectBalanceSheetState extends State<PosCollectBalanceSheet> {
  PosPaymentMethod _method = PosPaymentMethod.cash;
  final _refController = TextEditingController();
  final _cashReceivedController = TextEditingController();
  bool _submitting = false;

  double get _cashReceived =>
      double.tryParse(_cashReceivedController.text.replaceAll(',', '')) ?? 0;

  BookingModel get _booking {
    final live = OwnerBookingController.to.bookings
        .firstWhereOrNull((b) => b.id == widget.booking.id);
    return live ?? widget.booking;
  }

  @override
  void dispose() {
    _refController.dispose();
    _cashReceivedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final b = _booking;
      final remaining = b.remainingAmount;
      return Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text('Collect Balance',
                  style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                '${b.customerName.isNotEmpty ? b.customerName : 'Walk-in'} · ${b.courtName} · ${b.timeRange}',
                style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),

              _summaryRow('Total Amount', 'PKR ${_pkr.format(b.totalAmount)}'),
              const SizedBox(height: 6),
              _summaryRow('Already Paid', 'PKR ${_pkr.format(b.amountPaid ?? 0)}'),
              const SizedBox(height: 6),
              _summaryRow('Outstanding', 'PKR ${_pkr.format(remaining)}',
                  highlight: true),
              const Divider(height: 24, color: AppColors.border),

              Text('Payment Method',
                  style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  PosPaymentMethod.cash,
                  PosPaymentMethod.card,
                  PosPaymentMethod.jazzcash,
                  PosPaymentMethod.easypaisa,
                  PosPaymentMethod.bankTransfer,
                ].map((m) {
                  final sel = _method == m;
                  return GestureDetector(
                    onTap: () => setState(() => _method = m),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel
                            ? AppColors.warning.withValues(alpha: 0.12)
                            : AppColors.elevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: sel ? AppColors.warning : AppColors.border),
                      ),
                      child: Text(m.label,
                          style: AppTextStyles.caption.copyWith(
                            color: sel
                                ? AppColors.warning
                                : AppColors.textPrimary,
                            fontWeight:
                                sel ? FontWeight.w700 : FontWeight.w400,
                          )),
                    ),
                  );
                }).toList(),
              ),

              // Cash received + change calculator (cash only)
              if (_method == PosPaymentMethod.cash) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _cashReceivedController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: AppTextStyles.bodySmall,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Cash received from customer (optional)',
                    hintStyle: AppTextStyles.caption
                        .copyWith(color: AppColors.textDisabled),
                    prefixText: 'PKR  ',
                    prefixStyle: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.elevated,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: AppColors.warning),
                    ),
                  ),
                ),
                if (_cashReceived > 0) ...[
                  const SizedBox(height: 8),
                  Builder(builder: (context) {
                    final change = _cashReceived - remaining;
                    final isShort = change < 0;
                    final color =
                        isShort ? AppColors.error : AppColors.success;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: color.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isShort
                                ? Icons.warning_amber_rounded
                                : Icons.payments_outlined,
                            color: color,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isShort
                                ? 'Short by PKR ${_pkr.format(-change)}'
                                : 'Change: PKR ${_pkr.format(change)}',
                            style: AppTextStyles.bodySmall.copyWith(
                                color: color,
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],

              if (_method != PosPaymentMethod.cash) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _refController,
                  style: AppTextStyles.bodySmall,
                  decoration: InputDecoration(
                    hintText: 'Reference / transaction no. (optional)',
                    hintStyle: AppTextStyles.caption.copyWith(
                        color: AppColors.textDisabled),
                    filled: true,
                    fillColor: AppColors.elevated,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: AppColors.warning),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),

              if (remaining <= 0)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.3)),
                  ),
                  child: Text('No outstanding balance — fully paid.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600)),
                )
              else
                FilledButton(
                  onPressed: _submitting ? null : () => _collect(remaining),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text('Collect PKR ${_pkr.format(remaining)}'),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    });
  }

  Widget _summaryRow(String label, String value, {bool highlight = false}) =>
      Row(children: [
        Text(label,
            style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary)),
        const Spacer(),
        Text(value,
            style: AppTextStyles.bodyMedium.copyWith(
              color: highlight ? AppColors.error : AppColors.textPrimary,
              fontWeight:
                  highlight ? FontWeight.w800 : FontWeight.w600,
            )),
      ]);

  Future<void> _collect(double amount) async {
    setState(() => _submitting = true);
    try {
      final b = _booking;
      final newRemaining =
          (b.remainingAmount - amount).clamp(0.0, double.infinity);
      await PosController.to.collectBalance(
        booking: b,
        amount: amount,
        method: _method,
        refNo: _refController.text.trim().isEmpty
            ? null
            : _refController.text.trim(),
      );
      Get.back();
      Get.bottomSheet(
        isScrollControlled: true,
        PosBalanceReceiptSheet(
          booking: b,
          amountCollected: amount,
          newRemaining: newRemaining,
          method: _method,
          refNo: _refController.text.trim().isEmpty
              ? null
              : _refController.text.trim(),
          collectedAt: DateTime.now(),
        ),
      );
    } catch (e) {
      Get.snackbar('Error', e.toString(),
          backgroundColor: AppColors.error, colorText: Colors.white);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

// ── Balance Receipt Sheet ─────────────────────────────────────────────────

class PosBalanceReceiptSheet extends StatelessWidget {
  final BookingModel booking;
  final double amountCollected;
  final double newRemaining;
  final PosPaymentMethod method;
  final String? refNo;
  final DateTime collectedAt;

  const PosBalanceReceiptSheet({
    super.key,
    required this.booking,
    required this.amountCollected,
    required this.newRemaining,
    required this.method,
    required this.collectedAt,
    this.refNo,
  });

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat('d MMM yyyy  hh:mm a');
    final isPaid = newRemaining <= 0;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),

          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_outline,
                color: AppColors.success, size: 32),
          ),
          const SizedBox(height: 12),
          Text('PKR ${_pkr.format(amountCollected)} Collected',
              style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  fontSize: 20)),
          const SizedBox(height: 4),
          Text('via ${method.label}',
              style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary)),
          const SizedBox(height: 20),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.elevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row('Customer',
                    booking.customerName.isNotEmpty
                        ? booking.customerName
                        : 'Walk-in'),
                _row('Court', booking.courtName),
                _row('Slot', booking.timeRange),
                _row('Date', timeFmt.format(collectedAt)),
                if (refNo != null && refNo!.isNotEmpty)
                  _row('Ref No.', refNo!),
                const Divider(height: 20, color: AppColors.border),
                _row('Booking Total',
                    'PKR ${_pkr.format(booking.totalAmount)}'),
                _row('Previously Paid',
                    'PKR ${_pkr.format((booking.amountPaid ?? 0) - amountCollected)}'),
                _row('Now Collected', 'PKR ${_pkr.format(amountCollected)}',
                    valueColor: AppColors.success),
                const Divider(height: 20, color: AppColors.border),
                _row(
                  'Remaining Balance',
                  isPaid ? 'FULLY PAID' : 'PKR ${_pkr.format(newRemaining)}',
                  valueColor: isPaid ? AppColors.success : AppColors.warning,
                  bold: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Share PDF via WhatsApp
          FilledButton.icon(
            onPressed: () => PosReceiptService.shareBookingReceipt(
              booking: booking,
              amountCollected: amountCollected,
              method: method,
              newRemaining: newRemaining,
              refNo: refNo,
              collectedAt: collectedAt,
            ),
            icon: const Icon(Icons.share_outlined, size: 16),
            label: const Text('Share PDF Receipt'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF25D366), // WhatsApp green
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: Get.back,
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value,
      {Color? valueColor, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label,
              style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary)),
          const Spacer(),
          Text(value,
              style: AppTextStyles.bodySmall.copyWith(
                color: valueColor ?? AppColors.textPrimary,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              )),
        ],
      ),
    );
  }
}
