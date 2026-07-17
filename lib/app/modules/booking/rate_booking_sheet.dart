import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../data/models/booking_model.dart';
import '../../data/models/review_model.dart';
import '../../services/arena_service.dart';

// ── Design tokens (matches my_bookings_tab palette) ─────────────────────────
const _bg = Color(0xFF10131A);
const _surface = Color(0xFF1D2026);
const _outline = Color(0xFF3B494B);
const _cyan = Color(0xFF00DBE9);
const _cyanDim = Color(0xFF7DF4FF);
const _onSurface = Color(0xFFE1E2EB);
const _onSurfaceVar = Color(0xFFB9CACB);
const _amber = Color(0xFFFFB59C);
const _green = Color(0xFF2FF801);

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
      decoration: const BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: _cyan, width: 1.5),
          left: BorderSide(color: _outline),
          right: BorderSide(color: _outline),
        ),
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
              const Text(
                'RATE YOUR EXPERIENCE',
                style: TextStyle(
                  fontFamily: 'Archivo Narrow',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _cyanDim,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.booking.arenaName,
                style: const TextStyle(fontSize: 13, color: _onSurfaceVar),
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
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
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
                  style: const TextStyle(color: _onSurface, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Share your experience (optional)…',
                    hintStyle: TextStyle(color: _onSurfaceVar, fontSize: 14),
                    contentPadding: EdgeInsets.all(14),
                    border: InputBorder.none,
                    counterStyle: TextStyle(color: _onSurfaceVar, fontSize: 11),
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
                    backgroundColor: _cyan,
                    foregroundColor: _bg,
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
                            color: _bg,
                          ),
                        )
                      : const Text(
                          'SUBMIT REVIEW',
                          style: TextStyle(
                            fontFamily: 'Archivo Narrow',
                            fontWeight: FontWeight.w700,
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
