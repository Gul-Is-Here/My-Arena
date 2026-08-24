import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageCtrl = PageController();
  late final AnimationController _entryCtrl;
  late final Animation<double> _entryOpacity;
  late final Animation<double> _entrySlide;
  int _index = 0;

  static const _pages = [
    _OPage(
      label: '01',
      title: 'Discover Arenas\nNear You',
      body:
          'Find football, padel, cricket and multi-sport venues across your city. Filter by sport, distance, or availability.',
      accent: AppColors.primary,
      artType: _ArtType.discovery,
    ),
    _OPage(
      label: '02',
      title: 'Book Courts\nInstantly',
      body:
          'Pick your date, choose a slot, pay the deposit and step onto the court. Zero waiting, zero friction.',
      accent: AppColors.secondary,
      artType: _ArtType.booking,
    ),
    _OPage(
      label: '03',
      title: 'Compete &\nClaim Glory',
      body:
          'Register for tournaments, follow live brackets and climb the leaderboard. Your arena awaits.',
      accent: AppColors.accent,
      artType: _ArtType.trophy,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _entryOpacity = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _entrySlide = Tween<double>(begin: 40, end: 0).animate(
        CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut));
    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  void _finish() {
    AuthController.to.markOnboardingSeen();
    Get.offAllNamed(AppRoutes.roleSelect);
  }

  void _next() {
    if (_index < _pages.length - 1) {
      _pageCtrl.nextPage(
          duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_index];
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Full-screen page view for art
          PageView.builder(
            controller: _pageCtrl,
            itemCount: _pages.length,
            onPageChanged: (i) {
              setState(() => _index = i);
              _entryCtrl.forward(from: 0);
            },
            itemBuilder: (_, i) => _OnboardArtPane(page: _pages[i], size: size),
          ),

          // Bottom content panel
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomPanel(
              page: page,
              index: _index,
              total: _pages.length,
              entryOpacity: _entryOpacity,
              entrySlide: _entrySlide,
              onNext: _next,
              onSkip: _finish,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  final _OPage page;
  final int index;
  final int total;
  final Animation<double> entryOpacity;
  final Animation<double> entrySlide;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _BottomPanel({
    required this.page,
    required this.index,
    required this.total,
    required this.entryOpacity,
    required this.entrySlide,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final bool isLast = index == total - 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 48),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step label
          Text(
            page.label,
            style: AppTextStyles.label.copyWith(
              color: page.accent,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 10),

          // Title
          AnimatedBuilder(
            animation: entrySlide,
            builder: (_, child) => Transform.translate(
              offset: Offset(0, entrySlide.value),
              child: FadeTransition(opacity: entryOpacity, child: child),
            ),
            child: Text(
              page.title,
              style: AppTextStyles.headlineLarge.copyWith(
                color: AppColors.textPrimary,
                height: 1.15,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Body
          AnimatedBuilder(
            animation: entryOpacity,
            builder: (_, child) => FadeTransition(opacity: entryOpacity, child: child),
            child: Text(
              page.body,
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Dots + CTA row
          Row(
            children: [
              // Progress dots
              Row(
                children: List.generate(total, (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.only(right: 6),
                  width: i == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == index
                        ? page.accent
                        : AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                )),
              ),
              const Spacer(),

              // Skip button (hidden on last page)
              if (!isLast)
                GestureDetector(
                  onTap: onSkip,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Skip',
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),

              // Next / Get Started button
              _NextButton(
                label: isLast ? 'Get Started' : 'Next',
                accent: page.accent,
                onTap: onNext,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NextButton extends StatelessWidget {
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _NextButton({
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTextStyles.button.copyWith(
                color: AppColors.onPrimary,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_rounded,
                size: 18, color: AppColors.onPrimary),
          ],
        ),
      ),
    );
  }
}

// ─── Art Pane ──────────────────────────────────────────────────────────────

class _OnboardArtPane extends StatelessWidget {
  final _OPage page;
  final Size size;

  const _OnboardArtPane({required this.page, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size.height * 0.55,
      color: AppColors.background,
      child: CustomPaint(
        painter: _ArtPainter(page: page),
        size: Size(size.width, size.height * 0.55),
      ),
    );
  }
}

enum _ArtType { discovery, booking, trophy }

class _OPage {
  final String label;
  final String title;
  final String body;
  final Color accent;
  final _ArtType artType;

  const _OPage({
    required this.label,
    required this.title,
    required this.body,
    required this.accent,
    required this.artType,
  });
}

class _ArtPainter extends CustomPainter {
  final _OPage page;

  const _ArtPainter({required this.page});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    switch (page.artType) {
      case _ArtType.discovery:
        _drawDiscovery(canvas, size, cx, cy);
      case _ArtType.booking:
        _drawBooking(canvas, size, cx, cy);
      case _ArtType.trophy:
        _drawTrophy(canvas, size, cx, cy);
    }
  }

  void _drawDiscovery(Canvas canvas, Size size, double cx, double cy) {
    final accent = page.accent;
    final fill = Paint()..style = PaintingStyle.fill;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Background glow
    fill.color = accent.withValues(alpha: 0.06);
    canvas.drawCircle(Offset(cx, cy), 160, fill);

    // Outer ring
    stroke.color = accent.withValues(alpha: 0.12);
    stroke.strokeWidth = 1;
    canvas.drawCircle(Offset(cx, cy), 150, stroke);
    canvas.drawCircle(Offset(cx, cy), 110, stroke);

    // Grid lines (map feel)
    final grid = Paint()
      ..color = accent.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    for (int i = -4; i <= 4; i++) {
      canvas.drawLine(
          Offset(cx + i * 24, cy - 120), Offset(cx + i * 24, cy + 120), grid);
      canvas.drawLine(
          Offset(cx - 120, cy + i * 24), Offset(cx + 120, cy + i * 24), grid);
    }

    // Location pins
    _drawPin(canvas, Offset(cx, cy - 20), 28, accent, 1.0);
    _drawPin(canvas, Offset(cx - 60, cy + 30), 18, accent, 0.4);
    _drawPin(canvas, Offset(cx + 70, cy + 10), 18, accent, 0.4);
    _drawPin(canvas, Offset(cx + 30, cy + 50), 14, accent, 0.25);
    _drawPin(canvas, Offset(cx - 40, cy - 50), 14, accent, 0.25);

    // Radar sweep
    stroke.color = accent.withValues(alpha: 0.15);
    stroke.strokeWidth = 2;
    canvas.drawArc(
        Rect.fromCenter(center: Offset(cx, cy), width: 120, height: 120),
        -math.pi / 2,
        math.pi * 0.7,
        true,
        Paint()
          ..color = accent.withValues(alpha: 0.07)
          ..style = PaintingStyle.fill);
  }

  void _drawPin(Canvas canvas, Offset center, double r, Color c, double a) {
    final fill = Paint()
      ..color = c.withValues(alpha: a)
      ..style = PaintingStyle.fill;
    final path = Path();
    path.addOval(Rect.fromCenter(center: center, width: r * 2, height: r * 2));
    canvas.drawPath(path, fill);

    // Inner dot
    fill.color = c.withValues(alpha: a * 0.7 + 0.2);
    canvas.drawCircle(center, r * 0.35, fill);

    // Drop shadow line
    fill.color = c.withValues(alpha: a * 0.3);
    canvas.drawOval(
        Rect.fromCenter(
            center: center.translate(0, r + 4),
            width: r * 0.8,
            height: r * 0.3),
        fill);
  }

  void _drawBooking(Canvas canvas, Size size, double cx, double cy) {
    final accent = page.accent;
    final fill = Paint()..style = PaintingStyle.fill;

    // Background glow
    fill.color = accent.withValues(alpha: 0.05);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(cx, cy), width: 200, height: 240),
            const Radius.circular(24)),
        fill);

    // Calendar card
    fill.color = AppColors.elevated;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(cx, cy - 10), width: 180, height: 200),
            const Radius.circular(20)),
        fill);

    // Calendar header
    fill.color = accent.withValues(alpha: 0.9);
    canvas.drawRRect(
        RRect.fromRectAndCorners(
            Rect.fromLTWH(cx - 90, cy - 110, 180, 40),
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20)),
        fill);

    // Calendar grid dots
    final dot = Paint()
      ..style = PaintingStyle.fill;
    for (int row = 0; row < 4; row++) {
      for (int col = 0; col < 7; col++) {
        final dx = cx - 84 + col * 28.0;
        final dy = cy - 54 + row * 30.0;
        final highlight = row == 1 && col == 3;
        dot.color = highlight
            ? accent
            : AppColors.border.withValues(alpha: 0.6);
        if (highlight) {
          canvas.drawRRect(
              RRect.fromRectAndRadius(
                  Rect.fromCenter(center: Offset(dx, dy), width: 22, height: 22),
                  const Radius.circular(6)),
              dot);
        } else {
          canvas.drawCircle(Offset(dx, dy), 6, dot);
        }
      }
    }

    // Check mark on highlighted day
    final check = Paint()
      ..color = AppColors.onPrimary
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final hx = cx - 84 + 3 * 28.0;
    final hy = cy - 54 + 1 * 30.0;
    canvas.drawLine(
        Offset(hx - 5, hy), Offset(hx - 1, hy + 5), check);
    canvas.drawLine(
        Offset(hx - 1, hy + 5), Offset(hx + 6, hy - 4), check);

    // Time slot pills below calendar
    _drawPill(canvas, Offset(cx - 52, cy + 80), '09:00 AM', accent, true);
    _drawPill(canvas, Offset(cx + 52, cy + 80), '02:00 PM', accent, false);
    _drawPill(canvas, Offset(cx - 52, cy + 108), '06:00 PM', accent, false);
    _drawPill(canvas, Offset(cx + 52, cy + 108), '08:00 PM', accent, false);
  }

  void _drawPill(Canvas canvas, Offset center, String label, Color c, bool sel) {
    final fill = Paint()
      ..color = sel ? c.withValues(alpha: 0.9) : AppColors.border.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: center, width: 88, height: 22),
            const Radius.circular(11)),
        fill);
  }

  void _drawTrophy(Canvas canvas, Size size, double cx, double cy) {
    final accent = page.accent;
    final fill = Paint()..style = PaintingStyle.fill;

    // Glow
    final glow = Paint()
      ..color = accent.withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);
    canvas.drawCircle(Offset(cx, cy - 10), 100, glow);

    // Trophy cup body
    fill.color = accent.withValues(alpha: 0.85);
    final cupPath = Path();
    cupPath.moveTo(cx - 50, cy - 60);
    cupPath.cubicTo(cx - 55, cy + 10, cx - 30, cy + 40, cx, cy + 40);
    cupPath.cubicTo(cx + 30, cy + 40, cx + 55, cy + 10, cx + 50, cy - 60);
    cupPath.close();
    canvas.drawPath(cupPath, fill);

    // Handles
    final handleStroke = Paint()
      ..color = accent.withValues(alpha: 0.6)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
        Rect.fromCenter(center: Offset(cx - 55, cy - 20), width: 24, height: 36),
        -math.pi / 2, math.pi, false, handleStroke);
    canvas.drawArc(
        Rect.fromCenter(center: Offset(cx + 55, cy - 20), width: 24, height: 36),
        math.pi / 2, math.pi, false, handleStroke);

    // Stem
    fill.color = accent.withValues(alpha: 0.6);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(cx, cy + 60), width: 16, height: 40),
            const Radius.circular(4)),
        fill);

    // Base
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(cx, cy + 84), width: 70, height: 14),
            const Radius.circular(7)),
        fill..color = accent.withValues(alpha: 0.7));

    // Stars
    for (int i = 0; i < 5; i++) {
      final angle = -math.pi / 2 + (i / 5) * math.pi * 2;
      final starX = cx + math.cos(angle) * 80;
      final starY = (cy - 10) + math.sin(angle) * 80;
      final r = i % 2 == 0 ? 5.0 : 3.0;
      fill.color = accent.withValues(alpha: (i % 2 == 0 ? 0.6 : 0.3));
      canvas.drawCircle(Offset(starX, starY), r, fill);
    }

    // Number 1 on cup
    final textPainter = TextPainter(
      text: TextSpan(
        text: '1',
        style: TextStyle(
          color: AppColors.onPrimary.withValues(alpha: 0.9),
          fontSize: 36,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
        canvas,
        Offset(cx - textPainter.width / 2, cy - 10 - textPainter.height / 2));
  }

  @override
  bool shouldRepaint(covariant _ArtPainter old) => old.page != page;
}
