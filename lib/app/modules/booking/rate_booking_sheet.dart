import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../data/models/booking_model.dart';
import '../../data/models/review_model.dart';
import '../../services/arena_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

// ── Design tokens (matches my_bookings_tab palette) ─────────────────────────
const _bg = AppColors.background;
const _surface = AppColors.surface;
const _outline = AppColors.border;
const _cyan = AppColors.secondary;
const _cyanDim = AppColors.secondary;
const _ctaColor = AppColors.primary;
const _onSurface = AppColors.textPrimary;
const _onSurfaceVar = AppColors.textSecondary;
const _amber = AppColors.warning;
const _green = AppColors.success;

class RateBookingSheet extends StatefulWidget {
  final BookingModel booking;
  const RateBookingSheet({super.key, required this.booking});

  static Future<void> show(BookingModel booking) => showModalBottomSheet(
        context: Get.context!,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => RateBookingSheet(booking: booking),
      );

  @override
  State<RateBookingSheet> createState() => _RateBookingSheetState();
}

class _RateBookingSheetState extends State<RateBookingSheet> {
  int _stars = 0;
  final _commentCtrl = TextEditingController();
  bool _submitting = false;

  final _service = ArenaService();

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_stars == 0) {
      Get.snackbar('Rating required', 'Please select at least 1 star.',
          backgroundColor: _surface,
          colorText: _onSurface,
          duration: const Duration(seconds: 2));
      return;
    }
    setState(() => _submitting = true);
    try {
      final user = AuthController.to.currentUser.value;
      final review = ReviewModel(
        id: '',
        bookingId: widget.booking.id,
        arenaId: widget.booking.arenaId,
        customerId: user?.uid ?? '',
        customerName: user?.name ?? '',
        rating: _stars.toDouble(),
        comment: _commentCtrl.text.trim(),
        createdAt: DateTime.now(),
      );
      await _service.submitReview(review);
      if (mounted) Navigator.of(context).pop();
      Get.snackbar(
        'Thank you!',
        'Your review has been submitted.',
        backgroundColor: _green.withValues(alpha: 0.15),
        colorText: _green,
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      Get.snackbar('Error', 'Could not submit review. Try again.',
          backgroundColor: _surface, colorText: _onSurface);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: EdgeInsets.only(bottom: bottom),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        // A borderRadius requires uniform border colors, so a single cyan
        // hairline stands in for the old cyan-top / grey-sides mix.
        border: Border.all(color: _cyan.withValues(alpha: 0.6), width: 1.2),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Title
              Text(
                'RATE YOUR EXPERIENCE',
                style: AppTextStyles.titleLarge.copyWith(
                  fontSize: 18,
                  color: _cyanDim,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.booking.arenaName,
                style: AppTextStyles.bodySmall.copyWith(
                    fontSize: 13, color: _onSurfaceVar),
              ),
              const SizedBox(height: 24),
              // Star row
              Center(child: _StarRow(value: _stars, onChanged: (v) => setState(() => _stars = v))),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _stars == 0
                      ? 'Tap to rate'
                      : ['', 'Poor', 'Fair', 'Good', 'Very Good', 'Excellent'][_stars],
                  style: AppTextStyles.label.copyWith(
                    fontSize: 13,
                    color: _stars == 0 ? _onSurfaceVar : _amber,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Comment field
              Container(
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _outline.withValues(alpha: 0.5)),
                ),
                child: TextField(
                  controller: _commentCtrl,
                  maxLines: 3,
                  maxLength: 300,
                  style: AppTextStyles.bodyMedium.copyWith(color: _onSurface, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Share your experience (optional)…',
                    hintStyle: AppTextStyles.bodyMedium.copyWith(color: _onSurfaceVar, fontSize: 14),
                    contentPadding: const EdgeInsets.all(14),
                    border: InputBorder.none,
                    counterStyle: AppTextStyles.caption.copyWith(color: _onSurfaceVar, fontSize: 11),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Submit button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _ctaColor,
                    foregroundColor: AppColors.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.onPrimary,
                          ),
                        )
                      : Text(
                          'SUBMIT REVIEW',
                          style: AppTextStyles.button.copyWith(
                            fontSize: 15,
                            letterSpacing: 1.2,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Star row widget ───────────────────────────────────────────────────────────
class _StarRow extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _StarRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < value;
        return GestureDetector(
          onTap: () => onChanged(i + 1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Icon(
              filled ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 40,
              color: filled ? _amber : _outline,
            ),
          ),
        );
      }),
    );
  }
}
