import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../controllers/auth_controller.dart';
import '../../../controllers/pos_controller.dart';
import '../../../data/models/pos_expense_model.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

final _pkr = NumberFormat('#,##0');

class PosExpensesScreen extends StatelessWidget {
  const PosExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<PosController>()) {
      Get.put(PosController(), permanent: true);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Expenses'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
        onPressed: () => _showAddExpenseSheet(context),
      ),
      body: Obx(() {
        final expenses = PosController.to.expenses;
        if (expenses.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, color: AppColors.textDisabled, size: 48),
                SizedBox(height: 12),
                Text('No expenses recorded', style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          );
        }

        final total = expenses.fold(0.0, (s, e) => s + e.amount);
        return Column(
          children: [
            _SummaryRow(total: total, count: expenses.length),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: expenses.length,
                itemBuilder: (_, i) => _ExpenseCard(
                  expense: expenses[i],
                  onDelete: () => _confirmDelete(context, expenses[i].id),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  void _showAddExpenseSheet(BuildContext context) {
    Get.bottomSheet(
      isScrollControlled: true,
      _AddExpenseSheet(),
    );
  }

  void _confirmDelete(BuildContext context, String id) {
    Get.dialog(AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Delete Expense?', style: TextStyle(color: AppColors.textPrimary)),
      content: const Text('This action cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary)),
      actions: [
        TextButton(onPressed: Get.back, child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            PosController.to.deleteExpense(id);
            Get.back();
          },
          child: const Text('Delete', style: TextStyle(color: AppColors.error)),
        ),
      ],
    ));
  }
}

class _SummaryRow extends StatelessWidget {
  final double total;
  final int count;
  const _SummaryRow({required this.total, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      color: AppColors.elevated,
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total Expenses', style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary)),
              Text('PKR ${_pkr.format(total)}', style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.error, fontWeight: FontWeight.w800)),
            ],
          ),
          const Spacer(),
          Text('$count record${count == 1 ? '' : 's'}',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  final PosExpenseModel expense;
  final VoidCallback onDelete;
  const _ExpenseCard({required this.expense, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.money_off, color: AppColors.error, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(expense.description, style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                Text('${expense.category.label} · ${DateFormat('d MMM yyyy').format(expense.date)}',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                Text('Added by ${expense.addedByName}',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textDisabled, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('PKR ${_pkr.format(expense.amount)}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.error, fontWeight: FontWeight.w800)),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.textDisabled, size: 18),
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddExpenseSheet extends StatefulWidget {
  @override
  State<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<_AddExpenseSheet> {
  ExpenseCategory _category = ExpenseCategory.other;
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text);
    final desc = _descCtrl.text.trim();
    if (amount == null || amount <= 0 || desc.isEmpty) {
      Get.snackbar('Error', 'Please fill all fields',
          backgroundColor: AppColors.error, colorText: Colors.white);
      return;
    }
    setState(() => _submitting = true);
    try {
      final pos = PosController.to;
      final user = AuthController.to.currentUser.value;
      final arena = pos.selectedArena.value;
      if (arena == null) return;

      await pos.addExpense(PosExpenseModel(
        id: '',
        arenaId: arena.id,
        arenaName: arena.name,
        category: _category,
        amount: amount,
        description: desc,
        date: DateTime.now(),
        addedById: user?.uid ?? '',
        addedByName: user?.name ?? '',
        shiftId: pos.openShift.value?.id,
      ));
      Get.back();
    } catch (e) {
      Get.snackbar('Error', e.toString(),
          backgroundColor: AppColors.error, colorText: Colors.white);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text('Add Expense', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),

          // Category
          Text('Category', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: ExpenseCategory.values.map((c) {
              final sel = _category == c;
              return GestureDetector(
                onTap: () => setState(() => _category = c),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.primary.withValues(alpha: 0.12) : AppColors.elevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: sel ? AppColors.primary : AppColors.border),
                  ),
                  child: Text(c.label, style: AppTextStyles.caption.copyWith(
                    color: sel ? AppColors.primary : AppColors.textPrimary,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                  )),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Amount
          Text('Amount (PKR)', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          _textField(_amountCtrl, 'e.g. 500', TextInputType.number, [FilteringTextInputFormatter.digitsOnly]),
          const SizedBox(height: 14),

          // Description
          Text('Description', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          _textField(_descCtrl, 'e.g. Monthly electricity bill', TextInputType.text, []),
          const SizedBox(height: 20),

          FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _submitting
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary))
                : const Text('Add Expense'),
          ),
        ],
        ),
      ),
    );
  }

  Widget _textField(TextEditingController ctrl, String hint, TextInputType type,
      List<TextInputFormatter> formatters) =>
      TextField(
        controller: ctrl,
        keyboardType: type,
        inputFormatters: formatters,
        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textDisabled),
          filled: true,
          fillColor: AppColors.elevated,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
      );
}
