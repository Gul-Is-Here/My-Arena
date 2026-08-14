import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/models/booking_model.dart';
import '../../data/models/pos_product_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/slot_picker_widgets.dart';

/// POS receipt shown immediately after a walk-in booking is confirmed.
/// Displays booking summary and allows the owner to share a text receipt.
class PosReceiptScreen extends StatelessWidget {
  final BookingModel booking;
  final String arenaName;
  final String courtName;
  final DateTime date;
  final int startHour;
  final int totalHours;
  final double total;
  final String paymentMethod;
  final String customerPhone;
  final double amountPaid;
  final double remainingAmount;
  final double discount;
  final Map<PosProductModel, int> addOns;

  const PosReceiptScreen({
    super.key,
    required this.booking,
    required this.arenaName,
    required this.courtName,
    required this.date,
    required this.startHour,
    required this.totalHours,
    required this.total,
    required this.paymentMethod,
    required this.customerPhone,
    this.amountPaid = 0,
    this.remainingAmount = 0,
    this.discount = 0,
    this.addOns = const {},
  });

  static const _paymentLabels = {
    'cash': 'Cash',
    'jazzcash': 'JazzCash',
    'easypaisa': 'Easypaisa',
    'card': 'Card',
    'bank_transfer': 'Bank Transfer',
    'other': 'Other',
  };

  static const _paymentIcons = {
    'cash': Icons.payments_outlined,
    'jazzcash': Icons.account_balance_wallet_outlined,
    'easypaisa': Icons.mobile_friendly_outlined,
    'card': Icons.credit_card_outlined,
    'bank_transfer': Icons.account_balance_outlined,
    'other': Icons.more_horiz,
  };

  String _fmtDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String _buildShareText() {
    final endHour = startHour + totalHours;
    final start = fmtHour12(startHour);
    final end = fmtHour12(endHour);
    final fmt = NumberFormat('#,##0');
    final method = _paymentLabels[paymentMethod] ?? paymentMethod;
    final now = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
    final addOnLines = addOns.entries
        .map((e) => '  ${e.key.name} ×${e.value}: PKR ${fmt.format(e.key.price * e.value)}')
        .join('\n');
    return '''
🏟️ MyArena — Walk-in Receipt
━━━━━━━━━━━━━━━━━━━
Arena   : $arenaName
Court   : $courtName
Date    : ${_fmtDate(date)}
Time    : $start – $end
Duration: $totalHours hr${totalHours > 1 ? 's' : ''}
━━━━━━━━━━━━━━━━━━━
Customer: ${booking.customerName.isEmpty ? 'Walk-in' : booking.customerName}${customerPhone.isNotEmpty ? '\nPhone   : $customerPhone' : ''}
${addOnLines.isNotEmpty ? 'Add-ons :\n$addOnLines\n' : ''}${discount > 0 ? 'Discount: -PKR ${fmt.format(discount)}\n' : ''}Payment : $method
TOTAL   : PKR ${fmt.format(total)}
Paid    : PKR ${fmt.format(amountPaid > 0 ? amountPaid : total)}${remainingAmount > 0 ? '\nBalance : PKR ${fmt.format(remainingAmount)}' : ''}
━━━━━━━━━━━━━━━━━━━
Issued  : $now
Thank you for visiting!
''';
  }

  @override
  Widget build(BuildContext context) {
    final endHour = startHour + totalHours;
    final pkr = NumberFormat('#,##0').format(total);
    final payLabel = _paymentLabels[paymentMethod] ?? paymentMethod;
    final payIcon = _paymentIcons[paymentMethod] ?? Icons.payments_outlined;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Walk-in Receipt'),
        actions: [
          TextButton.icon(
            onPressed: () => SharePlus.instance.share(
              ShareParams(text: _buildShareText()),
            ),
            icon: const Icon(Icons.share_outlined, size: 18),
            label: const Text('Share'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ── Success banner ─────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check,
                        color: Colors.white, size: 30),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Booking Confirmed',
                    style: AppTextStyles.titleLarge
                        .copyWith(color: AppColors.success, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Walk-in slot locked · Payment collected',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Receipt card ───────────────────────────────────────────
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.elevated,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.receipt_long_outlined,
                            color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Receipt',
                          style: AppTextStyles.titleMedium
                              .copyWith(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        Text(
                          DateFormat('hh:mm a').format(DateTime.now()),
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _row('Arena', arenaName),
                        _row('Court', courtName),
                        _row('Date', _fmtDate(date)),
                        _row(
                          'Time',
                          '${fmtHour12(startHour)} – ${fmtHour12(endHour)}',
                        ),
                        _row('Duration',
                            '$totalHours hr${totalHours > 1 ? 's' : ''}'),
                        const Divider(height: 24),
                        _row(
                          'Customer',
                          booking.customerName.isEmpty
                              ? 'Walk-in'
                              : booking.customerName,
                        ),
                        if (customerPhone.isNotEmpty)
                          _row('Phone', customerPhone),
                        if (addOns.isNotEmpty) ...[
                          const Divider(height: 24),
                          ...addOns.entries.map((e) => _row(
                                e.key.name + (e.value > 1 ? ' ×${e.value}' : ''),
                                'PKR ${NumberFormat('#,##0').format(e.key.price * e.value)}',
                              )),
                        ],
                        if (discount > 0) ...[
                          const SizedBox(height: 4),
                          _row('Discount', '-PKR ${NumberFormat('#,##0').format(discount)}',
                              valueColor: AppColors.success),
                        ],
                        const Divider(height: 24),
                        Row(
                          children: [
                            Icon(payIcon,
                                size: 16,
                                color: AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Text(
                              'Payment',
                              style: AppTextStyles.bodyMedium
                                  .copyWith(color: AppColors.textSecondary),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                payLabel,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Total bar
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(16)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Text(
                              'TOTAL',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'PKR $pkr',
                              style: AppTextStyles.titleLarge.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        if (remainingAmount > 0) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text('Paid now', style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary)),
                              const Spacer(),
                              Text('PKR ${NumberFormat('#,##0').format(amountPaid)}',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.success, fontWeight: FontWeight.w700)),
                            ],
                          ),
                          Row(
                            children: [
                              Text('Balance due', style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary)),
                              const Spacer(),
                              Text('PKR ${NumberFormat('#,##0').format(remainingAmount)}',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.warning, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Actions ────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => SharePlus.instance.share(
                      ShareParams(text: _buildShareText()),
                    ),
                    icon: const Icon(Icons.share_outlined, size: 16),
                    label: const Text('Share Receipt'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Get.until((r) => r.isFirst),
                    icon: const Icon(Icons.dashboard_outlined, size: 16),
                    label: const Text('Dashboard'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? AppColors.textPrimary),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
