import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/finance_controller.dart';
import '../../data/models/payout_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class AdminFinanceScreen extends StatelessWidget {
  const AdminFinanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<FinanceController>()) {
      Get.put(FinanceController());
    }
    final ctrl = FinanceController.to;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Finance & Payouts'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _DateRangeBar(ctrl: ctrl),
        ),
      ),
      body: Obx(() {
        if (ctrl.isLoading.value) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primary));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SummaryCards(ctrl: ctrl),
            const SizedBox(height: 20),
            _sectionTitle('Owner Payouts'),
            const SizedBox(height: 10),
            ...ctrl.ownerSummaries.map((s) => _OwnerPayoutTile(
                  summary: s,
                  ctrl: ctrl,
                )),
            if (ctrl.ownerSummaries.isEmpty)
              _empty('No owner earnings in this period'),
            const SizedBox(height: 24),
            _sectionTitle('Payout History'),
            const SizedBox(height: 10),
            ...ctrl.payouts.map((p) => _PayoutHistoryTile(payout: p)),
            if (ctrl.payouts.isEmpty) _empty('No payouts recorded yet'),
            const SizedBox(height: 32),
          ],
        );
      }),
    );
  }

  Widget _sectionTitle(String t) => Text(t,
      style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700));

  Widget _empty(String msg) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
            child: Text(msg,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary))),
      );
}

class _DateRangeBar extends StatelessWidget {
  final FinanceController ctrl;
  const _DateRangeBar({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Obx(() => ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            children: FinanceDateRange.values.map((r) {
              final sel = ctrl.dateRange.value == r;
              return GestureDetector(
                onTap: () async {
                  if (r == FinanceDateRange.custom) {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      builder: (ctx, child) => Theme(
                        data: Theme.of(ctx).copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: AppColors.primary,
                            onPrimary: AppColors.onPrimary,
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) {
                      ctrl.customStart.value = picked.start;
                      ctrl.customEnd.value = picked.end;
                    }
                  }
                  ctrl.dateRange.value = r;
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.primary : AppColors.elevated,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: sel ? AppColors.primary : AppColors.border),
                  ),
                  alignment: Alignment.center,
                  child: Text(r.label,
                      style: AppTextStyles.caption.copyWith(
                        color: sel
                            ? AppColors.onPrimary
                            : AppColors.textSecondary,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                      )),
                ),
              );
            }).toList(),
          )),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  final FinanceController ctrl;
  const _SummaryCards({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child: _card('Total Revenue',
                    ctrl.totalRevenue, AppColors.primary, Icons.attach_money)),
            const SizedBox(width: 10),
            Expanded(
                child: _card('Platform Commission',
                    ctrl.platformCommission, AppColors.secondary, Icons.percent)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
                child: _card('Owner Earnings',
                    ctrl.ownerEarnings, AppColors.success, Icons.business)),
            const SizedBox(width: 10),
            Expanded(
                child: _card('Pending Payouts',
                    ctrl.pendingPayouts, AppColors.warning, Icons.hourglass_top)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
                child: _card('Completed Payouts',
                    ctrl.completedPayoutsTotal, AppColors.success, Icons.check_circle)),
            const SizedBox(width: 10),
            Expanded(
                child: _card('Refund Total',
                    ctrl.refundTotal, AppColors.error, Icons.replay)),
          ],
        ),
      ],
    );
  }

  Widget _card(String label, double amount, Color color, IconData icon) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(label,
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'PKR ${amount.toStringAsFixed(0)}',
              style: AppTextStyles.titleMedium.copyWith(
                  color: color, fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ],
        ),
      );
}

class _OwnerPayoutTile extends StatelessWidget {
  final OwnerFinanceSummary summary;
  final FinanceController ctrl;
  const _OwnerPayoutTile({required this.summary, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final s = summary;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text(s.ownerName,
                      style: AppTextStyles.titleMedium
                          .copyWith(fontWeight: FontWeight.w600))),
              Text('${s.bookingCount} bookings',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _fin('Earned', s.totalEarned, AppColors.textPrimary),
              _fin('Paid', s.totalPaid, AppColors.success),
              _fin('Pending', s.totalPending, AppColors.warning),
            ],
          ),
          if (s.totalPending > 0) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: Obx(() => ElevatedButton.icon(
                    onPressed: ctrl.isActionLoading.value
                        ? null
                        : () => _payDialog(context, s),
                    icon: const Icon(Icons.payments_outlined, size: 16,
                        color: AppColors.onPrimary),
                    label: Text(
                      'Mark PKR ${s.totalPending.toStringAsFixed(0)} Paid',
                      style: const TextStyle(color: AppColors.onPrimary),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  )),
            ),
          ],
        ],
      ),
    );
  }

  Widget _fin(String label, double amount, Color color) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary, fontSize: 10)),
            Text('PKR ${amount.toStringAsFixed(0)}',
                style: AppTextStyles.caption
                    .copyWith(color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  void _payDialog(BuildContext ctx, OwnerFinanceSummary s) {
    final methodCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Mark payout for ${s.ownerName}',
            style: AppTextStyles.titleMedium),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Amount: PKR ${s.totalPending.toStringAsFixed(0)}',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.primary)),
            const SizedBox(height: 12),
            TextField(
              controller: methodCtrl,
              style: AppTextStyles.bodyMedium,
              decoration: const InputDecoration(
                labelText: 'Payment method (e.g. JazzCash, Bank)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: notesCtrl,
              style: AppTextStyles.bodyMedium,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              ctrl.markPaid(
                s,
                paymentMethod: methodCtrl.text.trim(),
                notes: notesCtrl.text.trim(),
              );
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Confirm',
                style: TextStyle(color: AppColors.onPrimary)),
          ),
        ],
      ),
    );
  }
}

class _PayoutHistoryTile extends StatelessWidget {
  final PayoutModel payout;
  const _PayoutHistoryTile({required this.payout});

  @override
  Widget build(BuildContext context) {
    final p = payout;
    final color = p.status == PayoutStatus.paid
        ? AppColors.success
        : AppColors.warning;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.ownerName,
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w600)),
                Text(p.paymentMethod.isNotEmpty ? p.paymentMethod : 'N/A',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary)),
                if (p.paidAt != null)
                  Text(DateFormat('d MMM yyyy').format(p.paidAt!),
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textDisabled)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('PKR ${p.amount.toStringAsFixed(0)}',
                  style: AppTextStyles.titleMedium
                      .copyWith(fontWeight: FontWeight.w700)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(p.status.label,
                    style: AppTextStyles.caption.copyWith(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
