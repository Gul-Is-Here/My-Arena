import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../controllers/owner_booking_controller.dart';
import '../../../controllers/pos_controller.dart';
import '../../../data/models/booking_model.dart';
import '../../../data/models/pos_product_model.dart';
import '../../../data/models/pos_transaction_model.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

final _pkr = NumberFormat('#,##0');
final _dateFmt = DateFormat('d MMM yyyy');

// ── Entry point ───────────────────────────────────────────────────────────────

class PosBookingSaleScreen extends StatefulWidget {
  final BookingModel? initialBooking;
  const PosBookingSaleScreen({super.key, this.initialBooking});

  @override
  State<PosBookingSaleScreen> createState() => _PosBookingSaleScreenState();
}

class _PosBookingSaleScreenState extends State<PosBookingSaleScreen> {
  // Steps: 0=select booking  1=cart  2=payment  3=success
  int _step = 0;

  BookingModel? _booking;
  final Map<PosProductModel, int> _cart = {};
  PosPaymentMethod _method = PosPaymentMethod.cash;
  bool _fullPayment = true;
  final _amountPaidCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  final _refNoCtrl = TextEditingController();
  bool _submitting = false;
  String? _createdOrderId;

  double get _subtotal => _cart.entries
      .fold(0, (s, e) => s + e.key.price * e.value);

  double get _discountValue {
    final raw = double.tryParse(_discountCtrl.text) ?? 0;
    return raw.clamp(0, _subtotal);
  }

  double get _total => (_subtotal - _discountValue).clamp(0, double.infinity);

  double get _amountPaid {
    if (_fullPayment) return _total;
    return (double.tryParse(_amountPaidCtrl.text.replaceAll(',', '')) ?? 0)
        .clamp(0, _total);
  }

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<OwnerBookingController>()) {
      Get.put(OwnerBookingController(), permanent: true);
    }
    if (!Get.isRegistered<PosController>()) {
      Get.put(PosController(), permanent: true);
    }
    if (widget.initialBooking != null) {
      _booking = widget.initialBooking;
      _step = 1;
    }
  }

  @override
  void dispose() {
    _amountPaidCtrl.dispose();
    _discountCtrl.dispose();
    _refNoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: _step == 3
            ? const SizedBox.shrink()
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (_step == 0) {
                    Get.back();
                  } else {
                    setState(() => _step--);
                  }
                },
              ),
        title: Text(_appBarTitle),
        actions: [
          if (_step == 3)
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('Done'),
            ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: _buildStep(),
      ),
    );
  }

  String get _appBarTitle => switch (_step) {
        0 => 'Select Booking',
        1 => 'Add Products',
        2 => 'Checkout',
        _ => 'Order Created',
      };

  Widget _buildStep() {
    return switch (_step) {
      0 => _BookingPickerStep(
          key: const ValueKey(0),
          onSelected: (b) => setState(() {
            _booking = b;
            _step = 1;
          }),
        ),
      1 => _CartStep(
          key: const ValueKey(1),
          booking: _booking!,
          cart: _cart,
          subtotal: _subtotal,
          onCartChanged: () => setState(() {}),
          onNext: _subtotal > 0
              ? () => setState(() => _step = 2)
              : null,
        ),
      2 => _PaymentStep(
          key: const ValueKey(2),
          booking: _booking!,
          subtotal: _subtotal,
          discountCtrl: _discountCtrl,
          discountValue: _discountValue,
          total: _total,
          method: _method,
          fullPayment: _fullPayment,
          amountPaidCtrl: _amountPaidCtrl,
          refNoCtrl: _refNoCtrl,
          submitting: _submitting,
          amountPaid: _amountPaid,
          onMethodChanged: (m) => setState(() => _method = m),
          onFullPaymentChanged: (v) => setState(() => _fullPayment = v),
          onChanged: () => setState(() {}),
          onConfirm: _confirm,
        ),
      _ => _SuccessStep(
          key: const ValueKey(3),
          booking: _booking!,
          total: _total,
          amountPaid: _amountPaid,
          remaining: _total - _amountPaid,
          method: _method,
          orderId: _createdOrderId ?? '',
          onAddAnother: () => setState(() {
            _cart.clear();
            _discountCtrl.clear();
            _amountPaidCtrl.clear();
            _refNoCtrl.clear();
            _fullPayment = true;
            _step = 1;
          }),
        ),
    };
  }

  Future<void> _confirm() async {
    setState(() => _submitting = true);
    try {
      final items = _cart.entries
          .map((e) => {
                'name': e.key.name,
                'qty': e.value,
                'unitPrice': e.key.price,
              })
          .toList();
      final id = await PosController.to.createBookingLinkedSale(
        booking: _booking!,
        items: items,
        subtotal: _subtotal,
        discount: _discountValue,
        total: _total,
        method: _method,
        amountPaid: _amountPaid,
        refNo: _refNoCtrl.text.trim().isEmpty ? null : _refNoCtrl.text.trim(),
      );
      setState(() {
        _createdOrderId = id;
        _step = 3;
      });
    } catch (e) {
      Get.snackbar('Error', e.toString(),
          backgroundColor: AppColors.error, colorText: Colors.white);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

// ── Step 0: Booking picker ────────────────────────────────────────────────────

class _BookingPickerStep extends StatefulWidget {
  final void Function(BookingModel) onSelected;
  const _BookingPickerStep({super.key, required this.onSelected});

  @override
  State<_BookingPickerStep> createState() => _BookingPickerStepState();
}

class _BookingPickerStepState extends State<_BookingPickerStep> {
  String _search = '';

  List<BookingModel> _filtered(List<BookingModel> all) {
    final q = _search.toLowerCase().trim();
    final now = DateTime.now();
    return all.where((b) {
      if (b.isCancelled) return false;
      // Active bookings: today or recent (past 7 days)
      final diff = now.difference(b.date).inDays;
      if (diff > 7) return false;
      if (q.isEmpty) return true;
      return b.customerName.toLowerCase().contains(q) ||
          b.courtName.toLowerCase().contains(q) ||
          b.id.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            autofocus: true,
            onChanged: (v) => setState(() => _search = v),
            style: AppTextStyles.bodySmall,
            decoration: InputDecoration(
              hintText: 'Search by customer name, court, or booking ID',
              hintStyle:
                  AppTextStyles.caption.copyWith(color: AppColors.textDisabled),
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: AppColors.elevated,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                borderSide: const BorderSide(color: AppColors.warning),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            'Showing active bookings from the past 7 days',
            style: AppTextStyles.caption
                .copyWith(color: AppColors.textSecondary),
          ),
        ),
        Expanded(
          child: Obx(() {
            final all = OwnerBookingController.to.all;
            final filtered = _filtered(all);
            if (filtered.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.search_off_outlined,
                        size: 48, color: AppColors.textDisabled),
                    const SizedBox(height: 12),
                    Text(
                      _search.isEmpty
                          ? 'No recent bookings found'
                          : 'No bookings match "$_search"',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) =>
                  _BookingCard(booking: filtered[i], onTap: widget.onSelected),
            );
          }),
        ),
      ],
    );
  }
}

class _BookingCard extends StatelessWidget {
  final BookingModel booking;
  final void Function(BookingModel) onTap;
  const _BookingCard({required this.booking, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final isPaid = b.remainingAmount <= 0;
    return GestureDetector(
      onTap: () => onTap(b),
      child: Container(
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
                  child: Text(
                    b.customerName.isNotEmpty ? b.customerName : 'Walk-in',
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isPaid
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isPaid ? 'Paid' : 'Balance Due',
                    style: AppTextStyles.caption.copyWith(
                      color:
                          isPaid ? AppColors.success : AppColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _infoRow(Icons.stadium_outlined, b.courtName),
            const SizedBox(height: 2),
            _infoRow(
                Icons.calendar_today_outlined,
                '${_dateFmt.format(b.date)}  ·  ${b.timeRange}'),
            const SizedBox(height: 6),
            Row(
              children: [
                _amtChip('Total', b.totalAmount, AppColors.textSecondary),
                const SizedBox(width: 8),
                _amtChip('Paid', b.amountPaid ?? 0, AppColors.success),
                if (!isPaid) ...[
                  const SizedBox(width: 8),
                  _amtChip('Due', b.remainingAmount, AppColors.error),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) => Row(
        children: [
          Icon(icon, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Expanded(
            child: Text(text,
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary)),
          ),
        ],
      );

  Widget _amtChip(String label, double amount, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '$label: PKR ${_pkr.format(amount)}',
          style: AppTextStyles.caption
              .copyWith(color: color, fontWeight: FontWeight.w600),
        ),
      );
}

// ── Step 1: Cart ──────────────────────────────────────────────────────────────

class _CartStep extends StatelessWidget {
  final BookingModel booking;
  final Map<PosProductModel, int> cart;
  final double subtotal;
  final VoidCallback onCartChanged;
  final VoidCallback? onNext;

  const _CartStep({
    super.key,
    required this.booking,
    required this.cart,
    required this.subtotal,
    required this.onCartChanged,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final pos = PosController.to;
    final b = booking;

    return Column(
      children: [
        // Booking info banner
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
                  const Icon(Icons.bookmark_outline,
                      size: 15, color: AppColors.textSecondary),
                  const SizedBox(width: 5),
                  Text('Linked Booking',
                      style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                b.customerName.isNotEmpty ? b.customerName : 'Walk-in',
                style: AppTextStyles.bodyMedium
                    .copyWith(fontWeight: FontWeight.w700),
              ),
              Text('${b.courtName}  ·  ${b.timeRange}  ·  ${_dateFmt.format(b.date)}',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _chip('Booking: PKR ${_pkr.format(b.totalAmount)}',
                      AppColors.textSecondary),
                  const SizedBox(width: 6),
                  _chip('Paid: PKR ${_pkr.format(b.amountPaid ?? 0)}',
                      AppColors.success),
                  const SizedBox(width: 6),
                  _chip('Due: PKR ${_pkr.format(b.remainingAmount)}',
                      b.remainingAmount > 0 ? AppColors.error : AppColors.success),
                ],
              ),
            ],
          ),
        ),

        Expanded(
          child: Obx(() {
            final products = pos.products.where((p) => p.isActive).toList();
            if (products.isEmpty) {
              return const Center(
                child: Text('No products configured.\nAdd products in POS → Products.',
                    textAlign: TextAlign.center),
              );
            }
            // Group by category
            final Map<String, List<PosProductModel>> byCategory = {};
            for (final p in products) {
              byCategory.putIfAbsent(p.category.label, () => []).add(p);
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              children: byCategory.entries.map((entry) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        entry.key.toUpperCase(),
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8),
                      ),
                    ),
                    ...entry.value.map((p) => _ProductRow(
                          product: p,
                          qty: cart[p] ?? 0,
                          onQtyChanged: (q) {
                            if (q <= 0) {
                              cart.remove(p);
                            } else {
                              cart[p] = q;
                            }
                            onCartChanged();
                          },
                        )),
                    const SizedBox(height: 4),
                  ],
                );
              }).toList(),
            );
          }),
        ),

        // Cart summary + next button
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            children: [
              if (cart.isNotEmpty) ...[
                ...cart.entries.map((e) => _cartRow(
                      '${e.key.name} × ${e.value}',
                      'PKR ${_pkr.format(e.key.price * e.value)}',
                    )),
                const Divider(height: 16, color: AppColors.border),
              ],
              Row(
                children: [
                  Text('Subtotal',
                      style: AppTextStyles.bodyMedium
                          .copyWith(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text('PKR ${_pkr.format(subtotal)}',
                      style: AppTextStyles.bodyMedium
                          .copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: onNext,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(subtotal > 0
                    ? 'Proceed to Checkout — PKR ${_pkr.format(subtotal)}'
                    : 'Add at least one product'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(text,
            style: AppTextStyles.caption
                .copyWith(color: color, fontWeight: FontWeight.w600)),
      );

  Widget _cartRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Text(label,
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary)),
            const Spacer(),
            Text(value, style: AppTextStyles.caption),
          ],
        ),
      );
}

class _ProductRow extends StatelessWidget {
  final PosProductModel product;
  final int qty;
  final void Function(int) onQtyChanged;
  const _ProductRow(
      {required this.product, required this.qty, required this.onQtyChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: qty > 0 ? AppColors.warning : AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name,
                    style: AppTextStyles.bodySmall
                        .copyWith(fontWeight: FontWeight.w600)),
                Text('PKR ${_pkr.format(product.price)}',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          _QtyControl(qty: qty, onChanged: onQtyChanged),
        ],
      ),
    );
  }
}

class _QtyControl extends StatelessWidget {
  final int qty;
  final void Function(int) onChanged;
  const _QtyControl({required this.qty, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (qty > 0) ...[
          _btn(Icons.remove, () => onChanged(qty - 1)),
          const SizedBox(width: 8),
          SizedBox(
            width: 24,
            child: Text('$qty',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall
                    .copyWith(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
        ],
        _btn(Icons.add, () => onChanged(qty + 1),
            filled: true),
      ],
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap, {bool filled = false}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: filled ? AppColors.warning : AppColors.elevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: filled ? AppColors.warning : AppColors.border),
          ),
          child: Icon(icon,
              size: 16, color: filled ? Colors.white : AppColors.textPrimary),
        ),
      );
}

// ── Step 2: Payment ───────────────────────────────────────────────────────────

class _PaymentStep extends StatelessWidget {
  final BookingModel booking;
  final double subtotal;
  final TextEditingController discountCtrl;
  final double discountValue;
  final double total;
  final PosPaymentMethod method;
  final bool fullPayment;
  final TextEditingController amountPaidCtrl;
  final TextEditingController refNoCtrl;
  final bool submitting;
  final double amountPaid;
  final void Function(PosPaymentMethod) onMethodChanged;
  final void Function(bool) onFullPaymentChanged;
  final VoidCallback onChanged;
  final VoidCallback onConfirm;

  const _PaymentStep({
    super.key,
    required this.booking,
    required this.subtotal,
    required this.discountCtrl,
    required this.discountValue,
    required this.total,
    required this.method,
    required this.fullPayment,
    required this.amountPaidCtrl,
    required this.refNoCtrl,
    required this.submitting,
    required this.amountPaid,
    required this.onMethodChanged,
    required this.onFullPaymentChanged,
    required this.onChanged,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = (total - amountPaid).clamp(0.0, double.infinity);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Booking ref
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.bookmark_outline,
                    size: 15, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${booking.customerName.isNotEmpty ? booking.customerName : "Walk-in"}  ·  ${booking.courtName}  ·  ${booking.timeRange}',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _sectionLabel('Discount'),
          const SizedBox(height: 8),
          TextField(
            controller: discountCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => onChanged(),
            style: AppTextStyles.bodySmall,
            decoration: _inputDec('Discount amount (optional)', prefixText: 'PKR  '),
          ),
          const SizedBox(height: 16),

          // Summary
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _summaryRow('Subtotal', 'PKR ${_pkr.format(subtotal)}'),
                if (discountValue > 0)
                  _summaryRow('Discount', '- PKR ${_pkr.format(discountValue)}',
                      valueColor: AppColors.success),
                const Divider(height: 16, color: AppColors.border),
                _summaryRow('POS Total', 'PKR ${_pkr.format(total)}',
                    bold: true),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _sectionLabel('Payment Method'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: PosPaymentMethod.values
                .where((m) => m != PosPaymentMethod.other)
                .map((m) {
              final sel = method == m;
              return GestureDetector(
                onTap: () => onMethodChanged(m),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: sel
                        ? AppColors.warning.withValues(alpha: 0.12)
                        : AppColors.elevated,
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: sel ? AppColors.warning : AppColors.border),
                  ),
                  child: Text(m.label,
                      style: AppTextStyles.caption.copyWith(
                        color: sel ? AppColors.warning : AppColors.textPrimary,
                        fontWeight:
                            sel ? FontWeight.w700 : FontWeight.w400,
                      )),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Full vs partial
          _sectionLabel('Amount Collected'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _toggleChip(
                  'Full Payment',
                  fullPayment,
                  () => onFullPaymentChanged(true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _toggleChip(
                  'Partial / Unpaid',
                  !fullPayment,
                  () => onFullPaymentChanged(false),
                ),
              ),
            ],
          ),
          if (!fullPayment) ...[
            const SizedBox(height: 10),
            TextField(
              controller: amountPaidCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => onChanged(),
              style: AppTextStyles.bodySmall,
              decoration: _inputDec('Amount collected now', prefixText: 'PKR  '),
            ),
            if (remaining > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 15, color: AppColors.warning),
                    const SizedBox(width: 8),
                    Text(
                      'Remaining: PKR ${_pkr.format(remaining)} — will be recorded as unpaid',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.warning),
                    ),
                  ],
                ),
              ),
            ],
          ],

          if (method != PosPaymentMethod.cash) ...[
            const SizedBox(height: 12),
            TextField(
              controller: refNoCtrl,
              style: AppTextStyles.bodySmall,
              decoration: _inputDec('Ref / transaction no. (optional)'),
            ),
          ],
          const SizedBox(height: 24),

          FilledButton(
            onPressed: submitting ? null : onConfirm,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text('Create POS Order — PKR ${_pkr.format(total)}'),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary, fontWeight: FontWeight.w600),
      );

  Widget _summaryRow(String label, String value,
          {bool bold = false, Color? valueColor}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Text(label,
                style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
            const Spacer(),
            Text(value,
                style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                    color: valueColor ?? AppColors.textPrimary)),
          ],
        ),
      );

  Widget _toggleChip(String label, bool active, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? AppColors.warning.withValues(alpha: 0.12)
                : AppColors.elevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: active ? AppColors.warning : AppColors.border),
          ),
          child: Center(
            child: Text(label,
                style: AppTextStyles.caption.copyWith(
                  color: active ? AppColors.warning : AppColors.textSecondary,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                )),
          ),
        ),
      );

  InputDecoration _inputDec(String hint, {String? prefixText}) =>
      InputDecoration(
        hintText: hint,
        hintStyle:
            AppTextStyles.caption.copyWith(color: AppColors.textDisabled),
        prefixText: prefixText,
        prefixStyle:
            AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.elevated,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
          borderSide: const BorderSide(color: AppColors.warning),
        ),
      );
}

// ── Step 3: Success ───────────────────────────────────────────────────────────

class _SuccessStep extends StatelessWidget {
  final BookingModel booking;
  final double total;
  final double amountPaid;
  final double remaining;
  final PosPaymentMethod method;
  final String orderId;
  final VoidCallback onAddAnother;

  const _SuccessStep({
    super.key,
    required this.booking,
    required this.total,
    required this.amountPaid,
    required this.remaining,
    required this.method,
    required this.orderId,
    required this.onAddAnother,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_outline,
                color: AppColors.success, size: 40),
          ),
          const SizedBox(height: 16),
          Text('POS Order Created',
              style: AppTextStyles.titleLarge
                  .copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            'Additional charges linked to booking',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 28),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
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
                const Divider(height: 20, color: AppColors.border),
                _row('Linked Booking', '#${booking.id.substring(0, 8)}…',
                    valueColor: AppColors.primary),
                const Divider(height: 20, color: AppColors.border),
                _row('POS Total', 'PKR ${_pkr.format(total)}', bold: true),
                _row('Payment Method', method.label),
                _row('Collected', 'PKR ${_pkr.format(amountPaid)}',
                    valueColor: AppColors.success),
                if (remaining > 0)
                  _row('Remaining', 'PKR ${_pkr.format(remaining)}',
                      valueColor: AppColors.warning, bold: true),
                if (remaining <= 0)
                  _row('Status', 'Fully Paid ✓', valueColor: AppColors.success),
              ],
            ),
          ),
          const SizedBox(height: 24),

          FilledButton(
            onPressed: onAddAnother,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Add Another Order for this Booking'),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: Get.back,
            child: const Text('Back to POS'),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value,
      {Color? valueColor, bool bold = false}) =>
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
                  color: valueColor ?? AppColors.textPrimary,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                )),
          ],
        ),
      );
}

// ── Linked POS sales list (embedded in booking detail) ───────────────────────

class BookingLinkedSalesList extends StatelessWidget {
  final String bookingId;
  const BookingLinkedSalesList({super.key, required this.bookingId});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<PosController>()) {
      Get.put(PosController(), permanent: true);
    }
    return StreamBuilder<List<PosTransactionModel>>(
      stream: PosController.to.bookingLinkedSalesStream(bookingId),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final list = snap.data ?? [];
        if (list.isEmpty) return const SizedBox.shrink();

        final total = list.fold(0.0, (s, t) => s + t.totalAmount);
        final paid = list.fold(0.0, (s, t) => s + t.amountPaid);
        final remaining = list.fold(0.0, (s, t) => s + t.remainingAmount);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text('Additional POS Charges',
                      style: AppTextStyles.bodyMedium
                          .copyWith(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text('${list.length} order${list.length != 1 ? 's' : ''}',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ...list.map((t) => _SaleTile(txn: t)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _totalRow('POS Total', total, AppColors.textPrimary),
                    _totalRow('Collected', paid, AppColors.success),
                    if (remaining > 0)
                      _totalRow('Unpaid', remaining, AppColors.error,
                          bold: true),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _totalRow(String label, double amount, Color color,
      {bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Text(label,
                style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
            const Spacer(),
            Text('PKR ${_pkr.format(amount)}',
                style: AppTextStyles.bodySmall.copyWith(
                    color: color,
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
          ],
        ),
      );
}

class _SaleTile extends StatelessWidget {
  final PosTransactionModel txn;
  const _SaleTile({required this.txn});

  @override
  Widget build(BuildContext context) {
    final dtFmt = DateFormat('d MMM, hh:mm a');
    final isPaid = txn.remainingAmount <= 0;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  txn.notes.isNotEmpty ? txn.notes : 'POS Order',
                  style: AppTextStyles.bodySmall
                      .copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: isPaid
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  isPaid ? 'Paid' : 'Unpaid',
                  style: AppTextStyles.caption.copyWith(
                    color: isPaid ? AppColors.success : AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(dtFmt.format(txn.createdAt),
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(width: 8),
              Text('· ${txn.paymentMethod.label}',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary)),
              const Spacer(),
              Text('PKR ${_pkr.format(txn.totalAmount)}',
                  style: AppTextStyles.bodySmall
                      .copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}
