import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../controllers/booking_controller.dart';
import '../../data/models/booking_model.dart';
import '../../data/models/court_model.dart';
import '../../data/models/promotion_model.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../widgets/arena_image.dart';
import '../../widgets/slot_picker_widgets.dart';

class BookingSummaryScreen extends StatelessWidget {
  const BookingSummaryScreen({super.key});

  static const _weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday',
  ];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _fmtDate(DateTime d) =>
      '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]} ${d.year}';

  static Color _statusColor(BookingStatus s) {
    switch (s) {
      case BookingStatus.confirmed:
      case BookingStatus.completed:
        return SlotPickerColors.green;
      case BookingStatus.rejected:
      case BookingStatus.cancelled:
        return AppColors.error;
      default:
        return SlotPickerColors.pending;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.find<BookingController>();
    final b = c.draft;

    if (b == null) {
      return Scaffold(
        backgroundColor: SlotPickerColors.bg,
        body: const Center(
          child: Text(
            'No booking in progress',
            style: TextStyle(color: SlotPickerColors.muted),
          ),
        ),
      );
    }

    final arena = c.arena.value;
    final court = c.court.value;
    final statusColor = _statusColor(b.status);

    return Scaffold(
      backgroundColor: SlotPickerColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              onCopy: () {
                final text =
                    '${b.arenaName} — ${b.courtName}\n${_fmtDate(b.date)}\n${b.timeRange} (${b.totalHours} hr${b.totalHours > 1 ? 's' : ''})\nTotal: PKR ${b.totalAmount.toStringAsFixed(0)}';
                Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Booking details copied')),
                );
              },
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: ArenaImage(
                      path: arena?.images.isNotEmpty == true
                          ? arena!.images.first
                          : null,
                      height: 170,
                      width: double.infinity,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        b.status.label,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    b.arenaName,
                    style: const TextStyle(
                      color: SlotPickerColors.onBg,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _iconLine(
                    Icons.sports_soccer,
                    court != null
                        ? '${court.type.label} · ${b.courtName}'
                        : b.courtName,
                  ),
                  if (arena != null && arena.location.address.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _iconLine(Icons.location_on_outlined, arena.location.address),
                  ],
                  const SizedBox(height: 20),
                  _InfoTile(
                    icon: Icons.calendar_today_outlined,
                    label: 'DATE',
                    value: _fmtDate(b.date),
                  ),
                  const SizedBox(height: 12),
                  _InfoTile(
                    icon: Icons.access_time_rounded,
                    label: 'TIME',
                    value: b.timeRange,
                  ),
                  const SizedBox(height: 12),
                  _InfoTile(
                    icon: Icons.timer_outlined,
                    label: 'DURATION',
                    value:
                        '${b.totalHours} Hour${b.totalHours > 1 ? 's' : ''}',
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Payment Details',
                    style: TextStyle(
                      color: SlotPickerColors.greenCta,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: SlotPickerColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    child: Column(
                      children: [
                        _amountRow('Price per hour',
                            'PKR ${b.pricePerHour.toStringAsFixed(0)}'),
                        const SizedBox(height: 10),
                        Obx(() {
                          final discount = c.promoDiscount;
                          final base = (b.totalAmountStored ?? b.pricePerHour * b.totalHours) +
                              b.posAddOnsTotal - b.posDiscount;
                          return Column(
                            children: [
                              _amountRow(
                                'Subtotal (${b.totalHours} hr${b.totalHours > 1 ? 's' : ''})',
                                'PKR ${base.toStringAsFixed(0)}',
                              ),
                              if (discount > 0) ...[
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(children: [
                                      const Icon(Icons.local_offer_rounded,
                                          size: 13, color: SlotPickerColors.green),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Promo (${c.appliedPromo.value?.code ?? ''})',
                                        style: const TextStyle(
                                          color: SlotPickerColors.green,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ]),
                                    Text(
                                      '− PKR ${discount.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        color: SlotPickerColors.green,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          );
                        }),
                        Divider(
                          height: 24,
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'DEPOSIT DUE NOW',
                              style: TextStyle(
                                color: SlotPickerColors.onBg,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: SlotPickerColors.green
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.lock_outline,
                                      size: 11, color: SlotPickerColors.green),
                                  SizedBox(width: 4),
                                  Text(
                                    'SECURED',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: SlotPickerColors.green,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Obx(() {
                          final disc = c.promoDiscount;
                          final base = (b.totalAmountStored ?? b.pricePerHour * b.totalHours) +
                              b.posAddOnsTotal - b.posDiscount;
                          final total = (base - disc).clamp(0, double.infinity);
                          final deposit = total * BookingSettings.depositPercent / 100;
                          final remaining = total - deposit;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'PKR ${deposit.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      color: SlotPickerColors.greenCta,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    '${BookingSettings.depositPercent}% of total',
                                    style: const TextStyle(
                                      color: SlotPickerColors.muted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'PKR ${remaining.toStringAsFixed(0)} remaining, payable at the venue',
                                style: const TextStyle(
                                  color: SlotPickerColors.muted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _PromoSection(),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: SlotPickerColors.pending.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: SlotPickerColors.pending.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline,
                            size: 18, color: SlotPickerColors.pending),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Cancellation Policy',
                                style: TextStyle(
                                  color: SlotPickerColors.pending,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Booking is confirmed after the owner verifies your deposit. Free cancellation up to ${BookingSettings.minCancelHoursBefore} hour before start time (${BookingSettings.cancellationDeductPercent}% deposit deduction applies after that).',
                                style: const TextStyle(
                                  color: SlotPickerColors.muted,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // ── Recurring toggle ─────────────────────────────────
                  Obx(() => _OptionCard(
                    icon: Icons.repeat_rounded,
                    title: 'Recurring weekly',
                    subtitle: c.isRecurring.value
                        ? '${c.recurringWeeks.value} weeks — every ${_weekdayOf(b.date)}'
                        : 'Book the same slot every week',
                    enabled: c.isRecurring.value,
                    onToggle: (v) => c.isRecurring.value = v,
                    child: c.isRecurring.value
                        ? Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [4, 8, 12].map((w) {
                                final sel = c.recurringWeeks.value == w;
                                return GestureDetector(
                                  onTap: () => c.recurringWeeks.value = w,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: sel
                                          ? SlotPickerColors.greenCta.withValues(alpha: 0.18)
                                          : SlotPickerColors.surface,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: sel
                                            ? SlotPickerColors.greenCta
                                            : Colors.white.withValues(alpha: 0.1),
                                      ),
                                    ),
                                    child: Text(
                                      '$w wks',
                                      style: TextStyle(
                                        color: sel
                                            ? SlotPickerColors.greenCta
                                            : SlotPickerColors.muted,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          )
                        : null,
                  )),
                  const SizedBox(height: 12),
                  // ── Group booking toggle ──────────────────────────────
                  Obx(() => _OptionCard(
                    icon: Icons.group_rounded,
                    title: 'Group / team booking',
                    subtitle: c.isGroupBooking.value
                        ? 'Split: PKR ${(b.totalAmount / c.groupSize.value).toStringAsFixed(0)} per player'
                        : 'Share the slot and split the bill',
                    enabled: c.isGroupBooking.value,
                    onToggle: (v) => c.isGroupBooking.value = v,
                    child: c.isGroupBooking.value
                        ? Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Row(
                              children: [
                                const Text('Players:',
                                    style: TextStyle(
                                        color: SlotPickerColors.muted,
                                        fontSize: 13)),
                                const Spacer(),
                                _Stepper(
                                  value: c.groupSize.value,
                                  min: 2,
                                  max: 20,
                                  onChanged: (v) => c.groupSize.value = v,
                                ),
                              ],
                            ),
                          )
                        : null,
                  )),
                ],
              ),
            ),
            Obx(() {
              final deposit = c.depositAmount;
              final perPerson = c.isGroupBooking.value
                  ? deposit / c.groupSize.value
                  : deposit;
              final weeks = c.isRecurring.value ? c.recurringWeeks.value : 1;
              final label = c.isRecurring.value
                  ? 'Pay Week 1 of $weeks Deposit — PKR ${deposit.toStringAsFixed(0)}'
                  : c.isGroupBooking.value
                      ? 'Pay Deposit — PKR ${perPerson.toStringAsFixed(0)}/person'
                      : 'Pay Deposit — PKR ${deposit.toStringAsFixed(0)}';
              return _BottomBar(
                label: label,
                onPressed: () async {
                  final error = await c.validateSlots();
                  if (error != null) {
                    Get.snackbar(
                      'Slot Unavailable',
                      error,
                      snackPosition: SnackPosition.TOP,
                      duration: const Duration(seconds: 4),
                      backgroundColor: AppColors.error.withValues(alpha: 0.9),
                      colorText: Colors.white,
                    );
                    Get.back(); // return to slot picker
                    return;
                  }
                  c.buildDraft();
                  Get.toNamed(AppRoutes.depositPayment);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  static String _weekdayOf(DateTime d) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[d.weekday - 1];
  }

  Widget _iconLine(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: SlotPickerColors.muted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: SlotPickerColors.muted,
              fontSize: 12.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _amountRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style:
                const TextStyle(color: SlotPickerColors.muted, fontSize: 13)),
        Text(
          value,
          style: const TextStyle(
            color: SlotPickerColors.onBg,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onCopy;
  const _Header({required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Get.back(),
            icon: const Icon(Icons.arrow_back, color: SlotPickerColors.onBg),
          ),
          const Expanded(
            child: Text(
              'Booking Summary',
              style: TextStyle(
                color: SlotPickerColors.onBg,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: onCopy,
            tooltip: 'Copy details',
            icon: const Icon(Icons.share_outlined, color: SlotPickerColors.onBg),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SlotPickerColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: SlotPickerColors.greenCta.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: SlotPickerColors.greenCta),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: SlotPickerColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: SlotPickerColors.onBg,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final String label;
  final Future<void> Function() onPressed;

  const _BottomBar({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: SlotPickerColors.bg,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Material(
        color: SlotPickerColors.greenCta,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async => onPressed(),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.payments_outlined,
                    size: 18, color: AppColors.onPrimary),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.onPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Reusable toggle option card ────────────────────────────────────────────────

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final Widget? child;

  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onToggle,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: enabled
            ? SlotPickerColors.greenCta.withValues(alpha: 0.07)
            : SlotPickerColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: enabled
              ? SlotPickerColors.greenCta.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon,
                  size: 20,
                  color: enabled
                      ? SlotPickerColors.greenCta
                      : SlotPickerColors.muted),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: enabled
                            ? SlotPickerColors.greenCta
                            : SlotPickerColors.onBg,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: SlotPickerColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: enabled,
                onChanged: onToggle,
                activeColor: SlotPickerColors.greenCta,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
          if (child != null) child!,
        ],
      ),
    );
  }
}

// ── Numeric stepper ────────────────────────────────────────────────────────────

class _Stepper extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _Stepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _btn(Icons.remove, value > min ? () => onChanged(value - 1) : null),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '$value',
            style: const TextStyle(
              color: SlotPickerColors.onBg,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ),
        _btn(Icons.add, value < max ? () => onChanged(value + 1) : null),
      ],
    );
  }

  Widget _btn(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: onTap != null
              ? SlotPickerColors.greenCta.withValues(alpha: 0.15)
              : SlotPickerColors.surface,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 16,
          color: onTap != null
              ? SlotPickerColors.greenCta
              : SlotPickerColors.muted,
        ),
      ),
    );
  }
}

class _PromoSection extends StatefulWidget {
  const _PromoSection();

  @override
  State<_PromoSection> createState() => _PromoSectionState();
}

class _PromoSectionState extends State<_PromoSection> {
  final _ctrl = TextEditingController();
  bool _showManualEntry = false;
  late final BookingController _c;

  @override
  void initState() {
    super.initState();
    _c = Get.find<BookingController>();
    // Load available offers if not already loaded.
    if (_c.arenaOffers.isEmpty && !_c.offersLoading.value) {
      _c.loadOffersForArena();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _openManualEntry() {
    setState(() => _showManualEntry = true);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final applied = _c.appliedPromo.value;
      final error = _c.promoError.value;
      final loading = _c.promoLoading.value;
      final offers = _c.arenaOffers;
      final offersLoading = _c.offersLoading.value;
      final recommended = _c.recommendedOffer;
      final almostUnlocked = _c.almostUnlockedOffer;

      // ── Applied state ───────────────────────────────────────────────
      if (applied != null) {
        final saving = _c.promoDiscount;
        return _AppliedOfferTile(
          promo: applied,
          saving: saving,
          onRemove: () {
            _ctrl.clear();
            _c.clearPromo();
            setState(() => _showManualEntry = false);
          },
        );
      }

      // ── Offer discovery + manual entry ──────────────────────────────
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          const Row(
            children: [
              Icon(Icons.local_offer_rounded,
                  color: SlotPickerColors.greenCta, size: 16),
              SizedBox(width: 6),
              Text(
                'Available Offers',
                style: TextStyle(
                  color: SlotPickerColors.greenCta,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Loading state
          if (offersLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: SlotPickerColors.greenCta,
                  ),
                ),
              ),
            )

          // "Almost unlocked" hint (shown when no eligible offers exist)
          else if (offers.isEmpty && almostUnlocked != null)
            _AlmostUnlockedBanner(
              offer: almostUnlocked,
              currentTotal: _c.totalAmount,
            )

          // No offers at all
          else if (offers.isEmpty)
            const SizedBox.shrink()

          // Offer cards
          else ...[
            // Recommended offer (first eligible)
            if (recommended != null)
              _OfferSuggestionCard(
                promo: recommended,
                isRecommended: true,
                bookingTotal: _c.totalAmount,
                onApply: () => _c.applyOffer(recommended),
              ),
            // Remaining offers
            ...offers
                .where((o) => o.id != recommended?.id)
                .map((o) => _OfferSuggestionCard(
                      promo: o,
                      isRecommended: false,
                      bookingTotal: _c.totalAmount,
                      onApply: () => _c.applyOffer(o),
                    )),
            // Almost unlocked (shown alongside other offers)
            if (almostUnlocked != null)
              _AlmostUnlockedBanner(
                offer: almostUnlocked,
                currentTotal: _c.totalAmount,
              ),
          ],

          // Error from manual code entry
          if (error != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppColors.error.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: AppColors.error, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      error,
                      style: const TextStyle(
                          color: AppColors.error, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Manual code entry — secondary action
          if (!_showManualEntry)
            GestureDetector(
              onTap: _openManualEntry,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.keyboard_outlined,
                      size: 14, color: SlotPickerColors.muted),
                  const SizedBox(width: 6),
                  Text(
                    'Have a promo code?',
                    style: TextStyle(
                      color: SlotPickerColors.muted
                          .withValues(alpha: 0.7),
                      fontSize: 12,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            )
          else
            _ManualCodeEntry(
              ctrl: _ctrl,
              loading: loading,
              onApply: () {
                final code = _ctrl.text.trim();
                if (code.isEmpty) return;
                _c.applyPromoCode(code);
              },
              onDismiss: () {
                setState(() => _showManualEntry = false);
                _ctrl.clear();
                _c.promoError.value = null;
              },
            ),
        ],
      );
    });
  }
}

// ── Applied offer tile ────────────────────────────────────────────────────────

class _AppliedOfferTile extends StatelessWidget {
  final PromotionModel promo;
  final double saving;
  final VoidCallback onRemove;
  const _AppliedOfferTile(
      {required this.promo, required this.saving, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SlotPickerColors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: SlotPickerColors.green.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: SlotPickerColors.green, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Offer Applied — ${promo.sourceLabel}',
                      style: const TextStyle(
                        color: SlotPickerColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${promo.code} · ${promo.discountLabel}',
                      style: const TextStyle(
                        color: SlotPickerColors.green,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: SlotPickerColors.muted.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close,
                      color: SlotPickerColors.muted, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: SlotPickerColors.green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'You\'re saving Rs. ${saving.toStringAsFixed(0)} 🎉',
              style: const TextStyle(
                color: SlotPickerColors.green,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Offer suggestion card ─────────────────────────────────────────────────────

class _OfferSuggestionCard extends StatelessWidget {
  final PromotionModel promo;
  final bool isRecommended;
  final double bookingTotal;
  final VoidCallback onApply;

  const _OfferSuggestionCard({
    required this.promo,
    required this.isRecommended,
    required this.bookingTotal,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final eligible = promo.isEligibleFor(bookingTotal);
    final saving = promo.discountFor(bookingTotal);
    final accentColor = promo.isPlatform
        ? const Color(0xFF6C63FF)
        : SlotPickerColors.greenCta;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SlotPickerColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isRecommended
              ? accentColor.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.07),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isRecommended) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'RECOMMENDED',
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        promo.sourceLabel.toUpperCase(),
                        style: const TextStyle(
                          color: SlotPickerColors.muted,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  promo.discountLabel,
                  style: TextStyle(
                    color: eligible ? accentColor : SlotPickerColors.muted,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  promo.title,
                  style: const TextStyle(
                    color: SlotPickerColors.onBg,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (eligible && saving > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'You save Rs. ${saving.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: SlotPickerColors.green,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (!eligible && promo.minBookingAmount != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Min Rs. ${promo.minBookingAmount!.toStringAsFixed(0)} required',
                    style: const TextStyle(
                      color: SlotPickerColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (eligible)
            GestureDetector(
              onTap: onApply,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'Apply',
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Almost unlocked banner ────────────────────────────────────────────────────

class _AlmostUnlockedBanner extends StatelessWidget {
  final PromotionModel offer;
  final double currentTotal;
  const _AlmostUnlockedBanner(
      {required this.offer, required this.currentTotal});

  @override
  Widget build(BuildContext context) {
    final gap = (offer.minBookingAmount! - currentTotal).ceil();
    final savingLabel = offer.discountLabel;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF3D2A00).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFFFFB946).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Text('🔓', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Add Rs. $gap more to unlock $savingLabel',
              style: const TextStyle(
                color: Color(0xFFFFB946),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Manual code entry ─────────────────────────────────────────────────────────

class _ManualCodeEntry extends StatelessWidget {
  final TextEditingController ctrl;
  final bool loading;
  final VoidCallback onApply;
  final VoidCallback onDismiss;

  const _ManualCodeEntry({
    required this.ctrl,
    required this.loading,
    required this.onApply,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: ctrl,
                textCapitalization: TextCapitalization.characters,
                autofocus: true,
                style: const TextStyle(
                    color: SlotPickerColors.onBg, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Enter promo code',
                  hintStyle: const TextStyle(
                      color: SlotPickerColors.muted, fontSize: 14),
                  filled: true,
                  fillColor: SlotPickerColors.surface,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: SlotPickerColors.greenCta),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: loading ? null : onApply,
              style: ElevatedButton.styleFrom(
                backgroundColor: SlotPickerColors.greenCta,
                foregroundColor: Colors.black,
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black))
                  : const Text('Apply',
                      style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onDismiss,
              child: const Icon(Icons.close,
                  color: SlotPickerColors.muted, size: 20),
            ),
          ],
        ),
      ],
    );
  }
}
