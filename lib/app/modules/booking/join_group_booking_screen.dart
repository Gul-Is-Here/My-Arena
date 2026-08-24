import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/booking_controller.dart';
import '../../data/models/booking_model.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class JoinGroupBookingScreen extends StatefulWidget {
  const JoinGroupBookingScreen({super.key});

  @override
  State<JoinGroupBookingScreen> createState() => _JoinGroupBookingScreenState();
}

class _JoinGroupBookingScreenState extends State<JoinGroupBookingScreen> {
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  BookingModel? _found;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _error = 'Join code must be 6 characters');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _found = null;
    });
    final booking = await Get.find<BookingController>().joinGroupBooking(code);
    if (!mounted) return;
    if (booking == null) {
      setState(() {
        _loading = false;
        _error = 'Code not found or booking is full';
      });
    } else {
      setState(() {
        _loading = false;
        _found = booking;
      });
    }
  }

  void _openDetail() {
    if (_found == null) return;
    Get.toNamed(AppRoutes.bookingDetail, arguments: _found);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text('Join Group Booking',
            style: AppTextStyles.titleMedium.copyWith(color: AppColors.textPrimary)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary),
          onPressed: Get.back,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter Join Code',
                style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Ask the organiser for the 6-character code.',
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _codeCtrl,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
              ],
              decoration: InputDecoration(
                hintText: 'e.g. A3K7WP',
                hintStyle: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary.withValues(alpha: 0.5)),
                counterText: '',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
                errorText: _error,
              ),
              style: AppTextStyles.scoreboard.copyWith(
                  fontSize: 28,
                  letterSpacing: 8,
                  color: AppColors.textPrimary),
              textAlign: TextAlign.center,
              onSubmitted: (_) => _lookup(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _lookup,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text('Find Booking',
                        style: AppTextStyles.button.copyWith(color: AppColors.onPrimary)),
              ),
            ),
            if (_found != null) ...[
              const SizedBox(height: 32),
              _FoundCard(booking: _found!),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _openDetail,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF43C59E),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('View & Join',
                      style: AppTextStyles.button.copyWith(color: Colors.black)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FoundCard extends StatelessWidget {
  final BookingModel booking;
  const _FoundCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('EEE, d MMM').format(booking.date);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF43C59E).withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline,
                  color: Color(0xFF43C59E), size: 18),
              const SizedBox(width: 6),
              Text('Group Booking Found',
                  style: AppTextStyles.caption.copyWith(
                      color: const Color(0xFF43C59E),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 12),
          Text(booking.arenaName,
              style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(booking.courtName,
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _InfoPill(icon: Icons.calendar_today_outlined, label: date),
              _InfoPill(icon: Icons.access_time_outlined, label: booking.timeRange),
              _InfoPill(
                  icon: Icons.group_outlined,
                  label: '${booking.groupSize} players'),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Split: PKR ${booking.splitAmount.toStringAsFixed(0)} / person',
            style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.primary, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.textPrimary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(label,
            style: AppTextStyles.caption
                .copyWith(fontSize: 11, color: AppColors.textPrimary)),
      ]),
    );
  }
}
