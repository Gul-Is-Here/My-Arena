import 'package:flutter/material.dart';

import '../utils/slot_status.dart';

/// Shared dark palette for the slot-picker UI (customer booking flow +
/// owner walk-in booking) — deliberately fixed, not theme-driven, to match
/// the booking flow's immersive dark design.
abstract final class SlotPickerColors {
  static const bg = Color(0xFF0B1120);
  static const surface = Color(0xFF112240);
  static const surface2 = Color(0xFF0D1B35);
  static const green = Color(0xFF4ADE80);
  static const greenCta = Color(0xFF39FF14);
  static const onBg = Color(0xFFFFFFFF);
  static const muted = Color(0xFF8899AA);
  static const pending = Color(0xFFFFA726);
}

String fmtHour12(int hour) {
  final h = hour % 24;
  final period = h >= 12 ? 'PM' : 'AM';
  final h12 = h == 0
      ? 12
      : h > 12
          ? h - 12
          : h;
  return '$h12:00 $period';
}

// ─────────────────────────────────────────────────────────────────────────
// Date strip — horizontal scrolling day cards
// ─────────────────────────────────────────────────────────────────────────

class SlotDateStrip extends StatelessWidget {
  final DateTime selected;
  final int days;
  final ValueChanged<DateTime> onSelect;

  const SlotDateStrip({
    super.key,
    required this.selected,
    required this.days,
    required this.onSelect,
  });

  static const _weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    return SizedBox(
      height: 82,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: days,
        itemBuilder: (_, i) {
          final d = DateTime(today.year, today.month, today.day)
              .add(Duration(days: i));
          final sel = selected.year == d.year &&
              selected.month == d.month &&
              selected.day == d.day;
          return GestureDetector(
            onTap: () => onSelect(d),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 60,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: sel ? SlotPickerColors.greenCta : SlotPickerColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: sel
                      ? SlotPickerColors.greenCta
                      : Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _weekdays[d.weekday - 1],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: sel
                          ? const Color(0xFF0A1628)
                          : SlotPickerColors.muted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${d.day}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: sel
                          ? const Color(0xFF0A1628)
                          : SlotPickerColors.onBg,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: sel
                          ? const Color(0xFF0A1628)
                          : SlotPickerColors.green,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Duration selector
// ─────────────────────────────────────────────────────────────────────────

class DurationSelector extends StatelessWidget {
  final List<int> options;
  final int selected;
  final ValueChanged<int> onSelect;

  const DurationSelector({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: options.map((h) {
        final sel = h == selected;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: h == options.last ? 0 : 10),
            child: GestureDetector(
              onTap: () => onSelect(h),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: sel
                      ? SlotPickerColors.green.withValues(alpha: 0.12)
                      : SlotPickerColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: sel
                        ? SlotPickerColors.green
                        : Colors.white.withValues(alpha: 0.06),
                    width: sel ? 1.5 : 1,
                  ),
                  boxShadow: sel
                      ? [
                          BoxShadow(
                            color: SlotPickerColors.green.withValues(alpha: 0.25),
                            blurRadius: 14,
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  h == 1 ? '1 hr' : '$h hrs',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: sel ? SlotPickerColors.green : SlotPickerColors.onBg,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Legend
// ─────────────────────────────────────────────────────────────────────────

class SlotLegend extends StatelessWidget {
  const SlotLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: const [
        _LegendItem(
          color: SlotPickerColors.green,
          label: 'Available',
          filled: false,
        ),
        _LegendItem(
          color: SlotPickerColors.greenCta,
          label: 'Selected',
          filled: true,
        ),
        _LegendItem(
          color: SlotPickerColors.pending,
          label: 'Pending',
          filled: true,
        ),
        _LegendItem(
          color: SlotPickerColors.muted,
          label: 'Booked',
          filled: true,
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool filled;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.filled,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? color : Colors.transparent,
            border: filled ? null : Border.all(color: color, width: 1.5),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: SlotPickerColors.muted),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Step indicator — shared across the booking flow's screens (e.g.
// DATE → SLOT → PAY, or DATE → SUMMARY → PAYMENT).
// ─────────────────────────────────────────────────────────────────────────

enum StepState { done, current, upcoming }

class BookingStepIndicator extends StatelessWidget {
  final List<String> labels;
  final int currentIndex;

  const BookingStepIndicator({
    super.key,
    required this.labels,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) _StepLine(active: i <= currentIndex),
          _Step(
            label: labels[i],
            state: i < currentIndex
                ? StepState.done
                : i == currentIndex
                    ? StepState.current
                    : StepState.upcoming,
          ),
        ],
      ],
    );
  }
}

class _Step extends StatelessWidget {
  final String label;
  final StepState state;
  const _Step({required this.label, required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: state == StepState.upcoming
                ? SlotPickerColors.surface
                : SlotPickerColors.greenCta,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: state == StepState.done
              ? const Icon(Icons.check, size: 18, color: Color(0xFF0A1628))
              : Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: state == StepState.current
                        ? const Color(0xFF0A1628)
                        : SlotPickerColors.muted.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: state == StepState.upcoming
                ? SlotPickerColors.muted
                : SlotPickerColors.greenCta,
          ),
        ),
      ],
    );
  }
}

class _StepLine extends StatelessWidget {
  final bool active;
  const _StepLine({required this.active});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 18),
        color: active
            ? SlotPickerColors.greenCta.withValues(alpha: 0.5)
            : SlotPickerColors.surface,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Slot tile
// ─────────────────────────────────────────────────────────────────────────

class SlotTile extends StatelessWidget {
  final int hour;
  final double pricePerHour;
  final SlotStatus status;
  final bool isSelected;
  final VoidCallback? onTap;

  const SlotTile({
    super.key,
    required this.hour,
    required this.pricePerHour,
    required this.status,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = status == SlotStatus.available;
    final time = fmtHour12(hour);

    Color border;
    Color? fill;
    Color textColor;
    Widget trailing;
    String subLabel;

    if (isSelected) {
      border = SlotPickerColors.greenCta;
      fill = SlotPickerColors.greenCta;
      textColor = const Color(0xFF0A1628);
      subLabel = 'SELECTED';
      trailing = Container(
        width: 18,
        height: 18,
        decoration: const BoxDecoration(
          color: Color(0xFF0A1628),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, size: 12, color: SlotPickerColors.greenCta),
      );
    } else {
      switch (status) {
        case SlotStatus.available:
          border = SlotPickerColors.green.withValues(alpha: 0.4);
          fill = SlotPickerColors.surface;
          textColor = SlotPickerColors.onBg;
          subLabel = 'PKR ${pricePerHour.toStringAsFixed(0)}';
          trailing = Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: SlotPickerColors.green, width: 1.2),
            ),
            child: const Icon(Icons.add, size: 12, color: SlotPickerColors.green),
          );
          break;
        case SlotStatus.pending:
          border = SlotPickerColors.pending.withValues(alpha: 0.5);
          fill = SlotPickerColors.pending.withValues(alpha: 0.08);
          textColor = SlotPickerColors.pending;
          subLabel = 'PENDING';
          trailing = const Icon(
            Icons.hourglass_bottom,
            size: 14,
            color: SlotPickerColors.pending,
          );
          break;
        case SlotStatus.booked:
        case SlotStatus.past:
          border = Colors.white.withValues(alpha: 0.06);
          fill = SlotPickerColors.surface.withValues(alpha: 0.5);
          textColor = SlotPickerColors.muted.withValues(alpha: 0.6);
          subLabel = status == SlotStatus.booked ? 'BOOKED' : 'PAST';
          trailing = Icon(
            status == SlotStatus.booked
                ? Icons.lock_outline
                : Icons.block_outlined,
            size: 14,
            color: SlotPickerColors.muted.withValues(alpha: 0.5),
          );
          break;
      }
    }

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: isSelected ? 0 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              time,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  subLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: isSelected
                        ? const Color(0xFF0A1628).withValues(alpha: 0.7)
                        : textColor.withValues(alpha: 0.85),
                  ),
                ),
                trailing,
              ],
            ),
          ],
        ),
      ),
    );
  }
}
