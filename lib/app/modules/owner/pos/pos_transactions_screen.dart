import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../controllers/pos_controller.dart';
import '../../../data/models/pos_transaction_model.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

final _pkr = NumberFormat('#,##0');
final _dtFmt = DateFormat('d MMM, hh:mm a');

class PosTransactionsScreen extends StatefulWidget {
  const PosTransactionsScreen({super.key});

  @override
  State<PosTransactionsScreen> createState() => _PosTransactionsScreenState();
}

class _PosTransactionsScreenState extends State<PosTransactionsScreen> {
  String _search = '';
  PosPaymentMethod? _methodFilter;
  PosTransactionType? _typeFilter;

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<PosController>()) {
      Get.put(PosController(), permanent: true);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Transactions'),
      ),
      body: Column(
        children: [
          _Filters(
            search: _search,
            methodFilter: _methodFilter,
            typeFilter: _typeFilter,
            onSearch: (v) => setState(() => _search = v),
            onMethod: (m) => setState(() => _methodFilter = m),
            onType: (t) => setState(() => _typeFilter = t),
          ),
          Expanded(
            child: Obx(() {
              final all = PosController.to.transactions;
              final filtered = all.where((t) {
                if (_search.isNotEmpty &&
                    !t.customerName.toLowerCase().contains(_search.toLowerCase()) &&
                    !(t.courtName ?? '').toLowerCase().contains(_search.toLowerCase())) {
                  return false;
                }
                if (_methodFilter != null && t.paymentMethod != _methodFilter) return false;
                if (_typeFilter != null && t.type != _typeFilter) return false;
                return true;
              }).toList();

              if (filtered.isEmpty) {
                return const Center(
                  child: Text('No transactions', style: TextStyle(color: AppColors.textSecondary)),
                );
              }

              // Summary row
              final totalPaid = filtered.fold(0.0, (s, t) => s + t.amountPaid);
              final totalPending = filtered.fold(0.0, (s, t) => s + t.remainingAmount);

              return Column(
                children: [
                  _SummaryBar(totalPaid: totalPaid, totalPending: totalPending, count: filtered.length),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (ctx, constraints) {
                        return constraints.maxWidth >= 720
                            ? _DesktopTable(transactions: filtered)
                            : _MobileList(transactions: filtered);
                      },
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  final String search;
  final PosPaymentMethod? methodFilter;
  final PosTransactionType? typeFilter;
  final ValueChanged<String> onSearch;
  final ValueChanged<PosPaymentMethod?> onMethod;
  final ValueChanged<PosTransactionType?> onType;

  const _Filters({
    required this.search,
    required this.methodFilter,
    required this.typeFilter,
    required this.onSearch,
    required this.onMethod,
    required this.onType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        children: [
          TextField(
            onChanged: onSearch,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search by customer or court...',
              hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.textDisabled),
              prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary, size: 18),
              filled: true,
              fillColor: AppColors.elevated,
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary)),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip('All Methods', methodFilter == null, () => onMethod(null)),
                ...PosPaymentMethod.values.map((m) => _chip(
                      m.label, methodFilter == m, () => onMethod(methodFilter == m ? null : m))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool active, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: active ? AppColors.primary.withValues(alpha: 0.12) : AppColors.elevated,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: active ? AppColors.primary.withValues(alpha: 0.4) : AppColors.border),
          ),
          child: Text(label, style: AppTextStyles.caption.copyWith(
            color: active ? AppColors.primary : AppColors.textSecondary,
            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
          )),
        ),
      );
}

class _SummaryBar extends StatelessWidget {
  final double totalPaid, totalPending;
  final int count;
  const _SummaryBar({required this.totalPaid, required this.totalPending, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.elevated,
      child: Row(
        children: [
          _stat('$count transactions', AppColors.textSecondary),
          const Spacer(),
          _stat('Paid: PKR ${_pkr.format(totalPaid)}', AppColors.success),
          const SizedBox(width: 16),
          if (totalPending > 0)
            _stat('Pending: PKR ${_pkr.format(totalPending)}', AppColors.warning),
        ],
      ),
    );
  }

  Widget _stat(String text, Color color) => Text(text,
      style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w600));
}

class _MobileList extends StatelessWidget {
  final List<PosTransactionModel> transactions;
  const _MobileList({required this.transactions});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: transactions.length,
      itemBuilder: (_, i) => _TxnCard(txn: transactions[i]),
    );
  }
}

class _TxnCard extends StatelessWidget {
  final PosTransactionModel txn;
  const _TxnCard({required this.txn});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  txn.customerName.isNotEmpty ? txn.customerName : 'Walk-in',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                'PKR ${_pkr.format(txn.amountPaid)}',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.success, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(txn.courtName ?? txn.arenaName,
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.elevated,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(txn.paymentMethod.label,
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontSize: 10)),
              ),
              const Spacer(),
              Text(_dtFmt.format(txn.createdAt),
                  style: AppTextStyles.caption.copyWith(color: AppColors.textDisabled, fontSize: 11)),
            ],
          ),
          if (txn.remainingAmount > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Balance: PKR ${_pkr.format(txn.remainingAmount)}',
              style: AppTextStyles.caption.copyWith(color: AppColors.warning, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }
}

class _DesktopTable extends StatelessWidget {
  final List<PosTransactionModel> transactions;
  const _DesktopTable({required this.transactions});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2),
          1: FlexColumnWidth(2),
          2: FlexColumnWidth(1.5),
          3: FlexColumnWidth(1.5),
          4: FlexColumnWidth(1.5),
          5: FlexColumnWidth(2),
        },
        children: [
          TableRow(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            children: ['Customer', 'Court', 'Method', 'Paid', 'Balance', 'Date/Time']
                .map((h) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      child: Text(h, style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
                    ))
                .toList(),
          ),
          ...transactions.map((t) => TableRow(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                children: [
                  _cell(t.customerName.isNotEmpty ? t.customerName : 'Walk-in'),
                  _cell(t.courtName ?? t.arenaName),
                  _cell(t.paymentMethod.label),
                  _cell('PKR ${_pkr.format(t.amountPaid)}', color: AppColors.success),
                  _cell(
                    t.remainingAmount > 0 ? 'PKR ${_pkr.format(t.remainingAmount)}' : '—',
                    color: t.remainingAmount > 0 ? AppColors.warning : AppColors.textDisabled,
                  ),
                  _cell(_dtFmt.format(t.createdAt)),
                ],
              )),
        ],
      ),
    );
  }

  Widget _cell(String text, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Text(text, style: AppTextStyles.bodySmall.copyWith(
          color: color ?? AppColors.textPrimary)),
      );
}
