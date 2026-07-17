import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/tournament_controller.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/status_badge.dart';

/// Customer's registered tournaments with QR entry passes.
class MyTournamentsScreen extends StatelessWidget {
  const MyTournamentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = TournamentController.to;

    return Scaffold(
      appBar: AppBar(title: const Text('My Tournaments')),
      body: Obx(() {
        final regs = c.myRegistrations;
        if (regs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.emoji_events_outlined,
                    size: 64, color: AppColors.textGrey),
                const SizedBox(height: 16),
                Text('No tournaments yet', style: AppTextStyles.titleMedium),
                const SizedBox(height: 6),
                Text('Register for a tournament to get your pass',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textGrey)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: regs.length,
          itemBuilder: (_, i) {
            final reg = regs[i];
            final t = c.byId(reg.tournamentId);
            if (t == null) return const SizedBox.shrink();
            final confirmed = reg.status == 'confirmed';
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: AppCard(
                onTap: () =>
                    Get.toNamed(AppRoutes.tournamentDetail, arguments: t.id),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.name, style: AppTextStyles.titleMedium),
                              Text(
                                '${t.sport} · ${reg.playerName}',
                                style: AppTextStyles.bodySmall
                                    .copyWith(color: AppColors.textGrey),
                              ),
                            ],
                          ),
                        ),
                        StatusBadge(
                            status: confirmed ? 'confirmed' : reg.status),
                      ],
                    ),
                    const Divider(height: 24),
                    if (confirmed)
                      Row(
                        children: [
                          _QrStub(seed: reg.id.hashCode),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('ENTRY PASS',
                                    style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.accent,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1)),
                                const SizedBox(height: 4),
                                Text('Show this QR at the venue gate.',
                                    style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.textGrey)),
                                const SizedBox(height: 8),
                                Text(
                                  '#${reg.id.substring(reg.id.length - 6).toUpperCase()}',
                                  style: AppTextStyles.titleMedium,
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          const Icon(Icons.hourglass_top,
                              size: 18, color: AppColors.warning),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Pass activates once the organizer verifies your payment.',
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.warning),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

/// Deterministic fake QR — real QR generation comes with the backend.
class _QrStub extends StatelessWidget {
  final int seed;

  const _QrStub({required this.seed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 92,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: CustomPaint(painter: _QrPainter(seed)),
    );
  }
}

class _QrPainter extends CustomPainter {
  final int seed;

  _QrPainter(this.seed);

  @override
  void paint(Canvas canvas, Size size) {
    const n = 11;
    final cell = size.width / n;
    final paint = Paint()..color = Colors.black;
    var rand = seed;
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        rand = (rand * 1103515245 + 12345) & 0x7fffffff;
        final corner = (x < 3 && y < 3) ||
            (x >= n - 3 && y < 3) ||
            (x < 3 && y >= n - 3);
        if (corner || rand % 5 < 2) {
          canvas.drawRect(
              Rect.fromLTWH(x * cell, y * cell, cell, cell), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrPainter old) => old.seed != seed;
}
