import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/analytics_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Shared date-range filter chips (+ optional arena filter) for all reports.
class ReportFilterBar extends StatelessWidget {
  final bool showArenaFilter;

  const ReportFilterBar({super.key, this.showArenaFilter = false});

  @override
  Widget build(BuildContext context) {
    final c = AnalyticsController.to;
    return Column(
      children: [
        SizedBox(
          height: 52,
          child: Obx(
            () => ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: ReportRange.values.map((r) {
                final selected = c.range.value == r;
                final label = r == ReportRange.custom && selected
                    ? c.rangeLabel
                    : r.label;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: selected,
                    selectedColor: AppColors.primary,
                    labelStyle: AppTextStyles.bodySmall.copyWith(
                      color: selected ? Colors.white : AppColors.textGrey,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) async {
                      if (r == ReportRange.custom) {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime.now()
                              .subtract(const Duration(days: 365)),
                          lastDate: DateTime.now(),
                        );
                        if (picked == null) return;
                        c.customRange.value = picked;
                      }
                      c.range.value = r;
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        if (showArenaFilter)
          SizedBox(
            height: 44,
            child: Obx(
              () => ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _arenaChip(c, null, 'All Arenas'),
                  for (final a in c.arenas) _arenaChip(c, a.id, a.name),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _arenaChip(AnalyticsController c, String? id, String label) {
    final selected = c.arenaFilter.value == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: AppColors.accent.withValues(alpha: 0.25),
        labelStyle: AppTextStyles.bodySmall.copyWith(
          color: selected ? AppColors.accent : AppColors.textGrey,
          fontWeight: FontWeight.w600,
        ),
        onSelected: (_) => c.arenaFilter.value = id,
      ),
    );
  }
}
