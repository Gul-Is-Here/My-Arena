import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models/promotion_model.dart';
import '../services/promotion_service.dart';
import '../theme/app_colors.dart';

/// Shows a horizontally scrollable row of active platform-wide promo codes.
/// Renders nothing when there are no active platform promos.
class PlatformPromoBanner extends StatefulWidget {
  const PlatformPromoBanner({super.key});

  @override
  State<PlatformPromoBanner> createState() => _PlatformPromoBannerState();
}

class _PlatformPromoBannerState extends State<PlatformPromoBanner> {
  final _service = PromotionService();
  List<PromotionModel> _promos = [];
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = _service.platformPromotions().listen((all) {
      if (mounted) {
        setState(() => _promos = all.where((p) => p.isActive).toList());
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_promos.isEmpty) return const SizedBox.shrink();

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 6),
            child: Row(
              children: [
                const Icon(Icons.local_offer,
                    size: 13, color: AppColors.primary),
                const SizedBox(width: 5),
                Text(
                  'Platform offers',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _promos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => _PromoChip(promo: _promos[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _PromoChip extends StatelessWidget {
  final PromotionModel promo;
  const _PromoChip({required this.promo});

  String get _discountLabel {
    if (promo.discountType == DiscountType.flat) {
      return 'PKR ${promo.discountValue.toStringAsFixed(0)} off';
    }
    final pct = '${promo.discountValue.toStringAsFixed(0)}% off';
    if (promo.maxDiscountAmount != null) {
      return '$pct (max PKR ${promo.maxDiscountAmount!.toStringAsFixed(0)})';
    }
    return pct;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: promo.code));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Code "${promo.code}" copied!',
              style: const TextStyle(color: Colors.black),
            ),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              promo.code,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 1,
              height: 14,
              color: AppColors.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(width: 6),
            Text(
              _discountLabel,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.copy, size: 11, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
