import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../controllers/pos_controller.dart';
import '../../../data/models/pos_transaction_model.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

final _pkr = NumberFormat('#,##0');

enum _ReportRange { today, week, month, custom }

class PosReportsScreen extends StatefulWidget {
  const PosReportsScreen({super.key});

  @override
  State<PosReportsScreen> createState() => _PosReportsScreenState();
}

class _PosReportsScreenState extends State<PosReportsScreen> {
  _ReportRange _range = _ReportRange.today;
  DateTimeRange? _custom;

  DateTimeRange get _effectiveRange {
    final now = DateTime.now();
    switch (_range) {
      case _ReportRange.today:
        return DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: now,
        );
      case _ReportRange.week:
        return DateTimeRange(
          start: now.subtract(Duration(days: now.weekday - 1)),
          end: now,
        );
      case _ReportRange.month:
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: now,
        );
      case _ReportRange.custom:
        return _custom ?? DateTimeRange(start: now, end: now);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<PosController>()) {
      Get.put(PosController(), permanent: true);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Reports'),
      ),
      body: Column(
        children: [
          _RangeSelector(
            range: _range,
            onRange: (r) async {
              if (r == _ReportRange.custom) {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2024),
                  lastDate: DateTime.now(),
                  builder: (ctx, child) => Theme(
                    data: Theme.of(ctx).copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: AppColors.primary,
                        surface: AppColors.surface,
                      ),
                    ),
                    child: child!,
                  ),
                );
                if (picked != null) {
                  setState(() {
                    _custom = picked;
                    _range = r;
                  });
                }
              } else {
                setState(() => _range = r);
              }
            },
          ),
          Expanded(
            child: Obx(() {
              final txns = PosController.to.transactions;
              final range = _effectiveRange;
              final filtered = txns.where((t) =>
                  t.createdAt.isAfter(range.start) &&
                  t.createdAt.isBefore(range.end.add(const Duration(days: 1)))).toList();

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _RevenueSummary(transactions: filtered),
                  const SizedBox(height: 16),
                  _ByMethodChart(transactions: filtered),
                  const SizedBox(height: 16),
                  _ExpensesSummary(),
                  const SizedBox(height: 16),
                  _TransactionList(transactions: filtered),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ── Range selector ────────────────────────────────────────────────────────

class _RangeSelector extends StatelessWidget {
  final _ReportRange range;
  final ValueChanged<_ReportRange> onRange;
  const _RangeSelector({required this.range, required this.onRange});

  @override
  Widget build(BuildContext context) {
    const labels = {
      _ReportRange.today: 'Today',
      _ReportRange.week: 'This Week',
      _ReportRange.month: 'This Month',
      _ReportRange.custom: 'Custom',
    };

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _ReportRange.values.map((r) {
            final active = range == r;
            return GestureDetector(
              onTap: () => onRange(r),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : AppColors.elevated,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: active ? AppColors.primary : AppColors.border),
                ),
                child: Text(labels[r]!, style: AppTextStyles.bodySmall.copyWith(
                  color: active ? AppColors.onPrimary : AppColors.textSecondary,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                )),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Revenue summary ───────────────────────────────────────────────────────

class _RevenueSummary extends StatelessWidget {
  final List<PosTransactionModel> transactions;
  const _RevenueSummary({required this.transactions});

  @override
  Widget build(BuildContext context) {
    final totalPaid = transactions.fold(0.0, (s, t) => s + t.amountPaid);
    final totalPending = transactions.fold(0.0, (s, t) => s + t.remainingAmount);
    final refunds = transactions
        .where((t) => t.type == PosTransactionType.refund)
        .fold(0.0, (s, t) => s + t.amountPaid);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Revenue Summary', style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          _statRow('Total Collected', 'PKR ${_pkr.format(totalPaid)}', AppColors.primary),
          _statRow('Pending Balance', 'PKR ${_pkr.format(totalPending)}', AppColors.warning),
          _statRow('Refunds', 'PKR ${_pkr.format(refunds)}', AppColors.error),
          const Divider(height: 20, color: AppColors.border),
          _statRow('Net Revenue', 'PKR ${_pkr.format(totalPaid - refunds)}',
              AppColors.success, bold: true),
          _statRow('Transactions', '${transactions.length}', AppColors.textSecondary),
        ],
      ),
    );
  }

  Widget _statRow(String label, String value, Color valueColor, {bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
            const Spacer(),
            Text(value, style: AppTextStyles.bodySmall.copyWith(
              color: valueColor,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            )),
          ],
        ),
      );
}

// ── By method breakdown ───────────────────────────────────────────────────

class _ByMethodChart extends StatelessWidget {
  final List<PosTransactionModel> transactions;
  const _ByMethodChart({required this.transactions});

  @override
  Widget build(BuildContext context) {
    final totals = <PosPaymentMethod, double>{};
    for (final t in transactions) {
      totals[t.paymentMethod] = (totals[t.paymentMethod] ?? 0) + t.amountPaid;
    }

    if (totals.isEmpty) return const SizedBox.shrink();

    final grandTotal = totals.values.fold(0.0, (a, b) => a + b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Revenue by Method', style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          ...totals.entries.map((e) {
            final pct = grandTotal > 0 ? e.value / grandTotal : 0.0;
            return _MethodBar(
              method: e.key.label,
              amount: e.value,
              percent: pct,
            );
          }),
        ],
      ),
    );
  }
}

class _MethodBar extends StatelessWidget {
  final String method;
  final double amount;
  final double percent;
  const _MethodBar({required this.method, required this.amount, required this.percent});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(method, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary)),
              const Spacer(),
              Text('PKR ${_pkr.format(amount)} (${(percent * 100).toStringAsFixed(1)}%)',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent,
              backgroundColor: AppColors.elevated,
              color: AppColors.primary,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Expenses summary ──────────────────────────────────────────────────────

class _ExpensesSummary extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final expenses = PosController.to.expenses;
      final total = expenses.fold(0.0, (s, e) => s + e.amount);

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.money_off, color: AppColors.error, size: 28),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Expenses', style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary)),
                Text('PKR ${_pkr.format(total)}', style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.error, fontWeight: FontWeight.w800)),
              ],
            ),
            const Spacer(),
            Text('${expenses.length} records', style: AppTextStyles.caption.copyWith(
              color: AppColors.textDisabled)),
          ],
        ),
      );
    });
  }
}

// ── Transaction list ──────────────────────────────────────────────────────

class _TransactionList extends StatelessWidget {
  final List<PosTransactionModel> transactions;
  const _TransactionList({required this.transactions});

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Text('No transactions in this period',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Transactions (${transactions.length})',
                style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700)),
          ),
          const Divider(height: 1, color: AppColors.border),
          ...transactions.take(20).map((t) => _TxnRow(txn: t)),
          if (transactions.length > 20)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('+ ${transactions.length - 20} more',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textDisabled)),
            ),
        ],
      ),
    );
  }
}

class _TxnRow extends StatelessWidget {
  final PosTransactionModel txn;
  const _TxnRow({required this.txn});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(txn.customerName.isNotEmpty ? txn.customerName : 'Walk-in',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary)),
                Text(txn.courtName ?? txn.arenaName,
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('PKR ${_pkr.format(txn.amountPaid)}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.success, fontWeight: FontWeight.w700)),
              Text(txn.paymentMethod.label,
                  style: AppTextStyles.caption.copyWith(color: AppColors.textDisabled, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}
