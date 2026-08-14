import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../controllers/pos_controller.dart';
import '../../../data/models/pos_shift_model.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

final _pkr = NumberFormat('#,##0');
final _dtFmt = DateFormat('d MMM, hh:mm a');

class PosShiftScreen extends StatelessWidget {
  const PosShiftScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<PosController>()) {
      Get.put(PosController(), permanent: true);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Shift Management'),
      ),
      body: Obx(() {
        final pos = PosController.to;
        final openShift = pos.openShift.value;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (openShift != null)
              _OpenShiftCard(shift: openShift)
            else
              _StartShiftCard(),
            const SizedBox(height: 20),
            Text('Shift History', style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ...pos.shifts.where((s) => s.status == ShiftStatus.closed).map(
                (s) => _ShiftHistoryCard(shift: s)),
          ],
        );
      }),
    );
  }
}

// ── Open Shift Card ───────────────────────────────────────────────────────

class _OpenShiftCard extends StatelessWidget {
  final PosShiftModel shift;
  const _OpenShiftCard({required this.shift});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10, height: 10,
                decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text('Shift Open', style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.success, fontWeight: FontWeight.w800)),
              const Spacer(),
              Text(_dtFmt.format(shift.openedAt),
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          _shiftRow('Staff', shift.staffName),
          _shiftRow('Opening Cash', 'PKR ${_pkr.format(shift.openingCash)}'),
          _shiftRow('Cash Sales', 'PKR ${_pkr.format(shift.cashSales)}'),
          _shiftRow('Card Sales', 'PKR ${_pkr.format(shift.cardSales)}'),
          _shiftRow('Other Sales', 'PKR ${_pkr.format(shift.otherSales)}'),
          _shiftRow('Expenses', 'PKR ${_pkr.format(shift.expenses)}'),
          const Divider(color: AppColors.border),
          _shiftRow('Net Revenue', 'PKR ${_pkr.format(shift.netRevenue)}',
              valueColor: AppColors.primary),
          _shiftRow('Expected Cash', 'PKR ${_pkr.format(shift.expectedCash)}',
              valueColor: AppColors.warning),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => _showCloseShiftDialog(context),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Close Shift'),
          ),
        ],
      ),
    );
  }

  Widget _shiftRow(String label, String value, {Color? valueColor}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
            const Spacer(),
            Text(value, style: AppTextStyles.bodySmall.copyWith(
              color: valueColor ?? AppColors.textPrimary, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  void _showCloseShiftDialog(BuildContext context) {
    final cashCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    Get.dialog(AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Close Shift', style: TextStyle(color: AppColors.textPrimary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Expected cash: PKR ${_pkr.format(shift.expectedCash)}',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          TextField(
            controller: cashCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Actual Cash Count',
              labelStyle: TextStyle(color: AppColors.textSecondary),
              enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primary)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: notesCtrl,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              labelStyle: TextStyle(color: AppColors.textSecondary),
              enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primary)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: Get.back, child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () async {
            final cash = double.tryParse(cashCtrl.text) ?? 0;
            Get.back();
            await PosController.to.closeCurrentShift(cash, notesCtrl.text.trim());
            Get.snackbar('Shift Closed', 'Your shift has been closed.',
                backgroundColor: AppColors.success, colorText: Colors.white);
          },
          child: const Text('Close Shift'),
        ),
      ],
    ));
  }
}

// ── Start Shift Card ──────────────────────────────────────────────────────

class _StartShiftCard extends StatelessWidget {
  final _cashCtrl = TextEditingController();

  _StartShiftCard();

  @override
  Widget build(BuildContext context) {
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
          const Icon(Icons.access_time, color: AppColors.textSecondary, size: 32),
          const SizedBox(height: 12),
          Text('No Active Shift', style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Open a shift to start tracking POS transactions.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          Text('Opening Cash (PKR)',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          TextField(
            controller: _cashCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: '0',
              hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textDisabled),
              prefixText: 'PKR ',
              prefixStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
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
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              final cash = double.tryParse(_cashCtrl.text) ?? 0;
              await PosController.to.openNewShift(cash);
              Get.snackbar('Shift Opened', 'Your shift is now active.',
                  backgroundColor: AppColors.success, colorText: Colors.white);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Open Shift'),
          ),
        ],
      ),
    );
  }
}

// ── Shift History Card ────────────────────────────────────────────────────

class _ShiftHistoryCard extends StatelessWidget {
  final PosShiftModel shift;
  const _ShiftHistoryCard({required this.shift});

  @override
  Widget build(BuildContext context) {
    final diff = shift.cashDifference;
    final diffColor = diff.abs() < 10
        ? AppColors.success
        : diff < 0
            ? AppColors.error
            : AppColors.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
              Text(_dtFmt.format(shift.openedAt),
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
              const Spacer(),
              Text('Net: PKR ${_pkr.format(shift.netRevenue)}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primary, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _badge('Revenue: ${_pkr.format(shift.totalRevenue)}', AppColors.success),
              const SizedBox(width: 8),
              _badge('Exp: ${_pkr.format(shift.expenses)}', AppColors.error),
              const SizedBox(width: 8),
              _badge('Diff: ${diff >= 0 ? '+' : ''}${_pkr.format(diff)}', diffColor),
            ],
          ),
          if (shift.notes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(shift.notes, style: AppTextStyles.caption.copyWith(color: AppColors.textDisabled)),
          ],
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text, style: AppTextStyles.caption.copyWith(
          color: color, fontWeight: FontWeight.w600, fontSize: 11)),
      );
}
