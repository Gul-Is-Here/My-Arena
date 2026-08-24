import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../controllers/pos_controller.dart';
import '../../../data/models/pos_shift_model.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import 'pos_receipt_service.dart';

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
          if (shift.cashIn > 0)
            _shiftRow('Cash In', 'PKR ${_pkr.format(shift.cashIn)}',
                valueColor: AppColors.success),
          _shiftRow('Expected Cash', 'PKR ${_pkr.format(shift.expectedCash)}',
              valueColor: AppColors.warning),
          const SizedBox(height: 16),
          // Cash In / Cash Out quick actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showCashDialog(context, isIn: true),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Cash In'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.success,
                    side: const BorderSide(color: AppColors.success),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showCashDialog(context, isIn: false),
                  icon: const Icon(Icons.remove, size: 16),
                  label: const Text('Cash Out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
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
    Get.bottomSheet(
      isScrollControlled: true,
      _CloseShiftSheet(shift: shift),
    );
  }

  void _showCashDialog(BuildContext context, {required bool isIn}) {
    Get.bottomSheet(
      isScrollControlled: true,
      _CashInOutSheet(isIn: isIn),
    );
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

// ── Close Shift Reconciliation Sheet ─────────────────────────────────────

class _CloseShiftSheet extends StatefulWidget {
  final PosShiftModel shift;
  const _CloseShiftSheet({required this.shift});

  @override
  State<_CloseShiftSheet> createState() => _CloseShiftSheetState();
}

class _CloseShiftSheetState extends State<_CloseShiftSheet> {
  final _cashCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _submitting = false;
  double _counted = 0;

  double get _expected => widget.shift.expectedCash;
  double get _variance => _counted - _expected;

  @override
  void initState() {
    super.initState();
    _cashCtrl.addListener(() {
      setState(() => _counted = double.tryParse(_cashCtrl.text) ?? 0);
    });
  }

  @override
  void dispose() {
    _cashCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.shift;
    final hasInput = _cashCtrl.text.isNotEmpty;
    Color varianceColor;
    String varianceLabel;
    if (!hasInput) {
      varianceColor = AppColors.textDisabled;
      varianceLabel = '—';
    } else if (_variance.abs() < 50) {
      varianceColor = AppColors.success;
      varianceLabel = 'Balanced';
    } else if (_variance < 0) {
      varianceColor = AppColors.error;
      varianceLabel = 'Short by PKR ${_pkr.format(-_variance)}';
    } else {
      varianceColor = AppColors.warning;
      varianceLabel = 'Over by PKR ${_pkr.format(_variance)}';
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
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
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Row(
              children: [
                const Icon(Icons.lock_clock, color: AppColors.error, size: 20),
                const SizedBox(width: 8),
                Text('Close Shift',
                    style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                const Spacer(),
                Text(_dtFmt.format(s.openedAt),
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 20),

            // Shift summary
            _reconcileRow('Opening Cash', s.openingCash),
            _reconcileRow('Cash Sales', s.cashSales, color: AppColors.success),
            _reconcileRow('Card Sales', s.cardSales, color: AppColors.secondary),
            _reconcileRow('Other Sales', s.otherSales, color: AppColors.accent),
            _reconcileRow('Expenses', s.expenses, color: AppColors.error, minus: true),
            const Divider(height: 20, color: AppColors.border),
            _reconcileRow('Expected Cash in Drawer', _expected,
                color: AppColors.warning, bold: true),
            const SizedBox(height: 16),

            // Cash count input
            Text('Count the physical cash in the drawer',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            TextField(
              controller: _cashCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.textDisabled),
                prefixText: 'PKR ',
                prefixStyle: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.elevated,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: varianceColor, width: 2)),
              ),
            ),
            const SizedBox(height: 12),

            // Live variance badge
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: varianceColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: varianceColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    !hasInput
                        ? Icons.calculate_outlined
                        : _variance.abs() < 50
                            ? Icons.check_circle_outline
                            : _variance < 0
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                    color: varianceColor,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasInput
                              ? 'Variance: ${_variance >= 0 ? '+' : ''}PKR ${_pkr.format(_variance)}'
                              : 'Enter counted cash to see variance',
                          style: AppTextStyles.bodyMedium.copyWith(
                              color: varianceColor, fontWeight: FontWeight.w700),
                        ),
                        if (hasInput)
                          Text(varianceLabel,
                              style: AppTextStyles.caption.copyWith(
                                  color: varianceColor)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Notes
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Notes — explain any variance (optional)',
                hintStyle: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textDisabled),
                filled: true,
                fillColor: AppColors.elevated,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
            const SizedBox(height: 20),

            // Confirm button
            FilledButton(
              onPressed: _submitting || !hasInput ? null : _close,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
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
                  : Text(
                      hasInput
                          ? 'Close Shift  ·  ${_variance >= 0 ? '+' : ''}PKR ${_pkr.format(_variance)} variance'
                          : 'Enter counted cash first',
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reconcileRow(String label, double amount,
      {Color? color, bool minus = false, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(label,
              style: AppTextStyles.bodySmall.copyWith(
                  color: bold ? AppColors.textPrimary : AppColors.textSecondary,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
          const Spacer(),
          Text(
            '${minus ? '- ' : ''}PKR ${_pkr.format(amount)}',
            style: AppTextStyles.bodySmall.copyWith(
              color: color ?? AppColors.textPrimary,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _close() async {
    setState(() => _submitting = true);
    final closingShift = widget.shift;
    try {
      await PosController.to.closeCurrentShift(
          _counted, _notesCtrl.text.trim());
      Get.back();
      // Show daily closing report
      Get.bottomSheet(
        isScrollControlled: true,
        _DailyClosingReport(
          shift: closingShift,
          closingCash: _counted,
          variance: _variance,
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

// ── Cash In / Cash Out Sheet ──────────────────────────────────────────────

class _CashInOutSheet extends StatefulWidget {
  final bool isIn;
  const _CashInOutSheet({required this.isIn});

  @override
  State<_CashInOutSheet> createState() => _CashInOutSheetState();
}

class _CashInOutSheetState extends State<_CashInOutSheet> {
  final _amtCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _amtCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amtCtrl.text) ?? 0;
    if (amount <= 0) return;
    setState(() => _submitting = true);
    try {
      final reason = _reasonCtrl.text.trim();
      if (widget.isIn) {
        await PosController.to.addCashIn(amount, reason);
      } else {
        await PosController.to.addCashOut(amount, reason);
      }
      Get.back();
      Get.snackbar(
        widget.isIn ? 'Cash Added' : 'Cash Out Recorded',
        'PKR ${_pkr.format(amount)} ${widget.isIn ? 'added to drawer' : 'removed from drawer'}',
        backgroundColor:
            widget.isIn ? AppColors.success : AppColors.warning,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar('Error', e.toString(),
          backgroundColor: AppColors.error, colorText: Colors.white);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isIn ? AppColors.success : AppColors.error;
    final label = widget.isIn ? 'Cash In' : 'Cash Out';

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(widget.isIn ? Icons.add_circle_outline : Icons.remove_circle_outline,
                  color: color, size: 20),
              const SizedBox(width: 8),
              Text(label,
                  style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            widget.isIn
                ? 'Add cash to the drawer (e.g. change from bank)'
                : 'Remove cash from drawer (e.g. petty cash, supplies)',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amtCtrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.textPrimary, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              hintText: '0',
              prefixText: 'PKR ',
              prefixStyle: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.elevated,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: color)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: color, width: 2)),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _reasonCtrl,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Reason (optional) — e.g. supplies, petty cash',
              hintStyle: AppTextStyles.caption.copyWith(color: AppColors.textDisabled),
              filled: true,
              fillColor: AppColors.elevated,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: color,
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
                : Text('Confirm $label'),
          ),
        ],
      ),
    );
  }
}

// ── Daily Closing Report ──────────────────────────────────────────────────

class _DailyClosingReport extends StatelessWidget {
  final PosShiftModel shift;
  final double closingCash;
  final double variance;

  const _DailyClosingReport({
    required this.shift,
    required this.closingCash,
    required this.variance,
  });

  @override
  Widget build(BuildContext context) {
    final varColor = variance.abs() < 50
        ? AppColors.success
        : variance < 0
            ? AppColors.error
            : AppColors.warning;
    final varLabel = variance.abs() < 50
        ? 'Balanced'
        : variance < 0
            ? 'Short by PKR ${_pkr.format(-variance)}'
            : 'Over by PKR ${_pkr.format(variance)}';
    final dateFmt = DateFormat('d MMM yyyy');
    final timeFmt = DateFormat('hh:mm a');

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
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              const Icon(Icons.summarize_outlined,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Daily Closing Report',
                        style: AppTextStyles.titleMedium.copyWith(
                            fontWeight: FontWeight.w800)),
                    Text(
                      '${dateFmt.format(shift.openedAt)}  ·  ${timeFmt.format(shift.openedAt)} – ${timeFmt.format(DateTime.now())}',
                      style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Revenue card
          _section(
            title: 'Revenue',
            color: AppColors.primary,
            rows: [
              _reportRow('Cash Sales', shift.cashSales, AppColors.success),
              _reportRow('Card Sales', shift.cardSales, AppColors.secondary),
              _reportRow('Other (Online/Transfer)', shift.otherSales, AppColors.accent),
              _reportRow('Total Revenue', shift.totalRevenue, AppColors.primary, bold: true),
            ],
          ),
          const SizedBox(height: 10),

          // Cash drawer card
          _section(
            title: 'Cash Drawer',
            color: AppColors.warning,
            rows: [
              _reportRow('Opening Cash', shift.openingCash, null),
              if (shift.cashIn > 0)
                _reportRow('Cash In', shift.cashIn, AppColors.success),
              _reportRow('Cash Sales', shift.cashSales, AppColors.success),
              _reportRow('Cash Refunds', shift.cashRefunds, AppColors.error, minus: true),
              _reportRow('Expenses / Cash Out', shift.expenses, AppColors.error, minus: true),
              _reportRow('Expected in Drawer', shift.expectedCash, AppColors.warning, bold: true),
              _reportRow('You Counted', closingCash, null, bold: true),
              _reportRow(
                variance >= 0 ? 'Over' : 'Short',
                variance.abs(),
                varColor,
                bold: true,
                prefix: variance >= 0 ? '+' : '-',
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Expenses + Net
          _section(
            title: 'Summary',
            color: AppColors.textSecondary,
            rows: [
              _reportRow('Gross Revenue', shift.totalRevenue, AppColors.primary),
              _reportRow('Expenses', shift.expenses, AppColors.error, minus: true),
              _reportRow('Net Revenue', shift.netRevenue, AppColors.success, bold: true),
            ],
          ),
          const SizedBox(height: 10),

          // Variance badge
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: varColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: varColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  variance.abs() < 50
                      ? Icons.check_circle_outline
                      : variance < 0
                          ? Icons.arrow_downward
                          : Icons.arrow_upward,
                  color: varColor,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(varLabel,
                    style: AppTextStyles.bodyMedium.copyWith(
                        color: varColor, fontWeight: FontWeight.w700)),
                if (shift.notes.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('· ${shift.notes}',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Share PDF button
          FilledButton.icon(
            onPressed: () => PosReceiptService.shareShiftReport(shift, closingCash, variance),
            icon: const Icon(Icons.share_outlined, size: 16),
            label: const Text('Share via WhatsApp / PDF'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
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

  Widget _section({
    required String title,
    required Color color,
    required List<Widget> rows,
  }) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.elevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title.toUpperCase(),
                style: AppTextStyles.caption.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6)),
            const SizedBox(height: 8),
            ...rows,
          ],
        ),
      );

  Widget _reportRow(String label, double amount, Color? valueColor,
      {bool bold = false, bool minus = false, String prefix = ''}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(label,
              style: AppTextStyles.bodySmall.copyWith(
                  color: bold
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontWeight:
                      bold ? FontWeight.w700 : FontWeight.w400)),
          const Spacer(),
          Text(
            '${minus ? '- ' : prefix}PKR ${_pkr.format(amount)}',
            style: AppTextStyles.bodySmall.copyWith(
              color: valueColor ?? AppColors.textPrimary,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
