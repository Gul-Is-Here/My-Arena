import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../controllers/owner_booking_controller.dart';
import '../../data/models/booking_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Owner QR scanner — camera view that reads a customer's booking QR code and
/// marks the booking as checked-in in Firestore.
class OwnerQrScannerScreen extends StatefulWidget {
  const OwnerQrScannerScreen({super.key});

  @override
  State<OwnerQrScannerScreen> createState() => _OwnerQrScannerScreenState();
}

class _OwnerQrScannerScreenState extends State<OwnerQrScannerScreen> {
  final MobileScannerController _cam = MobileScannerController();
  bool _processing = false;
  String? _resultMessage;
  bool _success = false;
  BookingModel? _scannedBooking;

  @override
  void dispose() {
    _cam.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || code.isEmpty) return;

    setState(() => _processing = true);
    await _cam.stop();

    final controller = OwnerBookingController.to;
    final booking = controller.bookings.firstWhereOrNull((b) => b.id == code);
    final error = await controller.checkIn(code);

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _processing = false;
        _success = false;
        _resultMessage = error;
        _scannedBooking = booking;
      });
    } else {
      final updatedBooking =
          controller.bookings.firstWhereOrNull((b) => b.id == code) ?? booking;
      setState(() {
        _success = true;
        _resultMessage = null;
        _scannedBooking = updatedBooking;
      });
    }
  }

  void _reset() {
    setState(() {
      _processing = false;
      _resultMessage = null;
      _success = false;
      _scannedBooking = null;
    });
    _cam.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera
          if (!_success && _resultMessage == null)
            MobileScanner(
              controller: _cam,
              onDetect: _onDetect,
            ),

          // Overlay — viewfinder
          if (!_success && _resultMessage == null)
            _ScanOverlay(),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white),
                  ),
                  const Expanded(
                    child: Text('Scan Booking QR',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center),
                  ),
                  IconButton(
                    onPressed: () => _cam.toggleTorch(),
                    icon: const Icon(Icons.flashlight_on, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),

          // Result overlay
          if (_success || _resultMessage != null)
            _ResultPanel(
              success: _success,
              errorMessage: _resultMessage,
              booking: _scannedBooking,
              onReset: _reset,
              onClose: () => Get.back(),
            ),

          // Processing spinner
          if (_processing && !_success && _resultMessage == null)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScanOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Dark surround
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: 0.55),
            BlendMode.srcOut,
          ),
          child: Stack(
            children: [
              Container(decoration: const BoxDecoration(color: Colors.black)),
              Center(
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Corner markers
        Center(
          child: SizedBox(
            width: 260,
            height: 260,
            child: CustomPaint(painter: _CornerPainter()),
          ),
        ),
        // Hint text
        Positioned(
          bottom: 100,
          left: 0,
          right: 0,
          child: Text(
            'Align the customer\'s QR code within the frame',
            style: AppTextStyles.bodySmall
                .copyWith(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const len = 28.0;
    const r = 12.0;

    void corner(double x, double y, double dx, double dy) {
      final path = Path();
      path.moveTo(x + dx * len, y);
      path.lineTo(x + dx * r, y);
      path.arcToPoint(Offset(x, y + dy * r),
          radius: const Radius.circular(r), clockwise: dy > 0 ? dx < 0 : dx > 0);
      path.lineTo(x, y + dy * len);
      canvas.drawPath(path, paint);
    }

    corner(0, 0, 1, 1);
    corner(size.width, 0, -1, 1);
    corner(0, size.height, 1, -1);
    corner(size.width, size.height, -1, -1);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ResultPanel extends StatelessWidget {
  final bool success;
  final String? errorMessage;
  final BookingModel? booking;
  final VoidCallback onReset;
  final VoidCallback onClose;

  const _ResultPanel({
    required this.success,
    required this.errorMessage,
    required this.booking,
    required this.onReset,
    required this.onClose,
  });

  static const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final color = success ? AppColors.success : AppColors.error;
    final icon = success ? Icons.check_circle_rounded : Icons.error_rounded;
    final title = success ? 'Check-In Successful!' : 'Check-In Failed';

    return Container(
      color: Colors.black87,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Icon(icon, color: color, size: 72),
              const SizedBox(height: 16),
              Text(title,
                  style: TextStyle(
                      color: color,
                      fontSize: 24,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              if (errorMessage != null)
                Text(errorMessage!,
                    style: const TextStyle(color: Colors.white70, fontSize: 15),
                    textAlign: TextAlign.center),
              if (booking != null) ...[
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      _bookingRow('Arena', booking!.arenaName),
                      _bookingRow('Court', booking!.courtName),
                      _bookingRow('Customer', booking!.customerName),
                      _bookingRow(
                          'Date',
                          '${booking!.date.day} '
                          '${months[booking!.date.month - 1]} '
                          '${booking!.date.year}'),
                      _bookingRow('Time', booking!.timeRange),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              if (!success)
                ElevatedButton.icon(
                  onPressed: onReset,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              if (success)
                ElevatedButton.icon(
                  onPressed: onClose,
                  icon: const Icon(Icons.done),
                  label: const Text('Done'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: Get.back,
                child: const Text('Close',
                    style: TextStyle(color: Colors.white60)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bookingRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ',
              style: const TextStyle(
                  color: Colors.white54, fontSize: 13)),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
