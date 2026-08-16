import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../controllers/pos_controller.dart';
import '../../../data/models/pos_transaction_model.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

final _pkr = NumberFormat('#,##0');
final _timeFmt = DateFormat('h:mm a');

enum _ReportRange { today, week, month, custom }

class PosReportsScreen extends StatefulWidget {
  const PosReportsScreen({super.key});

  @override
  State<PosReportsScreen> createState() => _PosReportsScreenState();
}

class _PosReportsScreenState extends State<PosReportsScreen> {
  _ReportRange _range = _ReportRange.today;
  DateTimeRange? _custom;
  LedgerSource? _sourceFilter; // null = All

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
          _SourceFilter(
            selected: _sourceFilter,
            onSelected: (s) => setState(() => _sourceFilter = s),
          ),
          Expanded(
            child: Obx(() {
              final txns = PosController.to.transactions;
              final range = _effectiveRange;
              var filtered = txns.where((t) =>
                  t.createdAt.isAfter(range.start) &&
                  t.createdAt.isBefore(
                      range.end.add(const Duration(days: 1)))).toList();

              if (_sourceFilter != null) {
                filtered =
                    filtered.where((t) => t.source == _sourceFilter).toList();
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _RevenueSummary(transactions: filtered),
                  const SizedBox(height: 16),
                  _SourceBreakdown(transactions: txns.where((t) =>
                      t.createdAt.isAfter(range.start) &&
                      t.createdAt.isBefore(
                          range.end.add(const Duration(days: 1)))).toList()),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : AppColors.elevated,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: active ? AppColors.primary : AppColors.border),
                ),
                child: Text(labels[r]!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: active
                          ? AppColors.onPrimary
                          : AppColors.textSecondary,
                      fontWeight:
                          active ? FontWeight.w700 : FontWeight.w400,
                    )),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Source filter ─────────────────────────────────────────────────────────

class _SourceFilter extends StatelessWidget {
  final LedgerSource? selected;
  final ValueChanged<LedgerSource?> onSelected;
  const _SourceFilter({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final options = <LedgerSource?>[null, ...LedgerSource.values];
    final labels = <LedgerSource?, String>{
      null: 'All Sources',
      LedgerSource.pos: 'POS Walk-in',
      LedgerSource.online: 'Online Booking',
      LedgerSource.adjustment: 'Adjustment',
    };
    final colors = <LedgerSource?, Color>{
      null: AppColors.primary,
      LedgerSource.pos: AppColors.accent,
      LedgerSource.online: AppColors.secondary,
      LedgerSource.adjustment: AppColors.warning,
    };

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: options.map((s) {
            final active = selected == s;
            final color = colors[s]!;
            return GestureDetector(
              onTap: () => onSelected(s),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: active
                      ? color.withValues(alpha: 0.15)
                      : AppColors.elevated,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: active ? color : AppColors.border, width: 1.2),
                ),
                child: Text(labels[s]!,
                    style: AppTextStyles.caption.copyWith(
                      color: active ? color : AppColors.textSecondary,
                      fontWeight:
                          active ? FontWeight.w700 : FontWeight.w400,
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
    final totalPending =
        transactions.fold(0.0, (s, t) => s + t.remainingAmount);
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
          Text('Revenue Summary',
              style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          _statRow('Total Collected', 'PKR ${_pkr.format(totalPaid)}',
              AppColors.primary),
          _statRow('Pending Balance', 'PKR ${_pkr.format(totalPending)}',
              AppColors.warning),
          _statRow(
              'Refunds', 'PKR ${_pkr.format(refunds)}', AppColors.error),
          const Divider(height: 20, color: AppColors.border),
          _statRow(
              'Net Revenue',
              'PKR ${_pkr.format(totalPaid - refunds)}',
              AppColors.success,
              bold: true),
          _statRow('Transactions', '${transactions.length}',
              AppColors.textSecondary),
        ],
      ),
    );
  }

  Widget _statRow(String label, String value, Color valueColor,
          {bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(label,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary)),
            const Spacer(),
            Text(value,
                style: AppTextStyles.bodySmall.copyWith(
                  color: valueColor,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                )),
          ],
        ),
      );
}

// ── Source breakdown (always shows all sources regardless of filter) ───────

class _SourceBreakdown extends StatelessWidget {
  final List<PosTransactionModel> transactions;
  const _SourceBreakdown({required this.transactions});

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) return const SizedBox.shrink();

    final totals = <LedgerSource, double>{};
    final counts = <LedgerSource, int>{};
    for (final t in transactions) {
      totals[t.source] = (totals[t.source] ?? 0) + t.amountPaid;
      counts[t.source] = (counts[t.source] ?? 0) + 1;
    }

    final grandTotal = totals.values.fold(0.0, (a, b) => a + b);
    if (grandTotal == 0) return const SizedBox.shrink();

    final colors = {
      LedgerSource.pos: AppColors.accent,
      LedgerSource.online: AppColors.secondary,
      LedgerSource.adjustment: AppColors.warning,
    };

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
          Text('Revenue by Source',
              style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          ...totals.entries.map((e) {
            final pct = e.value / grandTotal;
            final color = colors[e.key] ?? AppColors.primary;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(e.key.label,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textPrimary)),
                      const Spacer(),
                      Text(
                        'PKR ${_pkr.format(e.value)}  ·  ${counts[e.key]} txn',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: AppColors.elevated,
                      color: color,
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text('${(pct * 100).toStringAsFixed(1)}% of revenue',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textDisabled, fontSize: 10)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── By method breakdown ───────────────────────────────────────────────────

class _ByMethodChart extends StatelessWidget {
  final List<PosTransactionModel> transactions;
  const _ByMethodChart({required this.transactions});

  @override
  Widget build(BuildContext context) {
    final totals = <PosPaymentMethod, double>{};
    for (final t in transactions) {
      totals[t.paymentMethod] =
          (totals[t.paymentMethod] ?? 0) + t.amountPaid;
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
          Text('Revenue by Method',
              style: AppTextStyles.titleMedium.copyWith(
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
  const _MethodBar(
      {required this.method, required this.amount, required this.percent});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(method,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textPrimary)),
              const Spacer(),
              Text(
                  'PKR ${_pkr.format(amount)} (${(percent * 100).toStringAsFixed(1)}%)',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary)),
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
                Text('Total Expenses',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary)),
                Text('PKR ${_pkr.format(total)}',
                    style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w800)),
              ],
            ),
            const Spacer(),
            Text('${expenses.length} records',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textDisabled)),
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
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary)),
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
                style: AppTextStyles.titleMedium
                    .copyWith(fontWeight: FontWeight.w700)),
          ),
          const Divider(height: 1, color: AppColors.border),
          ...transactions.take(30).map((t) => _TxnRow(txn: t)),
          if (transactions.length > 30)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('+ ${transactions.length - 30} more',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textDisabled)),
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
    final sourceColor = switch (txn.source) {
      LedgerSource.pos => AppColors.accent,
      LedgerSource.online => AppColors.secondary,
      LedgerSource.adjustment => AppColors.warning,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 40,
            decoration: BoxDecoration(
              color: sourceColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  txn.customerName.isNotEmpty ? txn.customerName : 'Walk-in',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textPrimary),
                ),
                Row(
                  children: [
                    Text(txn.courtName ?? txn.arenaName,
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textSecondary)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: sourceColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(txn.source.label,
                          style: AppTextStyles.caption.copyWith(
                              color: sourceColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('PKR ${_pkr.format(txn.amountPaid)}',
                  style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.success, fontWeight: FontWeight.w700)),
              Text(
                '${txn.paymentMethod.label} · ${_timeFmt.format(txn.createdAt)}',
                style: AppTextStyles.caption.copyWith(
                    color: AppColors.textDisabled, fontSize: 10),
              ),
              if (txn.remainingAmount > 0)
                Text('Due: PKR ${_pkr.format(txn.remainingAmount)}',
                    style: AppTextStyles.caption.copyWith(
                        color: AppColors.warning,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}
