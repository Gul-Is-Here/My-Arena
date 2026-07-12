import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Colored pill for statuses like pending / approved / rejected / confirmed.
class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  Color get _color {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'confirmed':
      case 'completed':
      case 'active':
      case 'refund_confirmed':
        return AppColors.success;
      case 'rejected':
      case 'cancelled':
      case 'off':
      case 'banned':
      case 'suspended':
        return AppColors.error;
      case 'resolved':
        return AppColors.success;
      case 'open':
      case 'in_progress':
      case 'pending':
      case 'pending_deposit':
      case 'deposit_submitted':
      case 'pending_approval':
      case 'refund_pending':
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = status.replaceAll('_', ' ').toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppTextStyles.bodySmall.copyWith(
          color: _color,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
