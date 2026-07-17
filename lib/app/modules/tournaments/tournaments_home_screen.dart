import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/tournament_controller.dart';
import '../../data/models/tournament_model.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/status_badge.dart';

/// Customer tournaments tab — filters + public tournament list.
class TournamentsHomeScreen extends StatefulWidget {
  const TournamentsHomeScreen({super.key});

  @override
  State<TournamentsHomeScreen> createState() => _TournamentsHomeScreenState();
}

class _TournamentsHomeScreenState extends State<TournamentsHomeScreen> {
  String _sport = 'All';
  String _fee = 'All'; // All | Free | Paid

  static const _sports = ['All', 'Padel', 'Football', 'Cricket'];

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<TournamentController>()) {
      Get.put(TournamentController(), permanent: true);
    }
    final c = TournamentController.to;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tournaments'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.confirmation_number_outlined),
            tooltip: 'My tournaments',
            onPressed: () => Get.toNamed(AppRoutes.myTournaments),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Filters ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ..._sports.map((s) => _chip(s, _sport == s,
                      (v) => setState(() => _sport = v))),
                  Container(
                    width: 1,
                    height: 24,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    color: AppColors.textGrey.withValues(alpha: 0.3),
                  ),
                  ...['All', 'Free', 'Paid'].map((f) => _chip(
                      f, _fee == f, (v) => setState(() => _fee = v))),
                ],
              ),
            ),
          ),
          Expanded(
            child: Obx(() {
              final items = c.publicTournaments.where((t) {
                if (_sport != 'All' && t.sport != _sport) return false;
                if (_fee == 'Free' && !t.isFree) return false;
                if (_fee == 'Paid' && t.isFree) return false;
                return true;
              }).toList();

              if (items.isEmpty) {
                return const Center(child: Text('No tournaments found'));
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: items.length,
                itemBuilder: (_, i) => _TournamentCard(tournament: items[i]),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool sel, void Function(String) onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: sel,
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(
          color: sel ? Colors.white : null,
          fontWeight: FontWeight.w600,
        ),
        onSelected: (_) => onTap(label),
      ),
    );
  }
}

class _TournamentCard extends StatelessWidget {
  final TournamentModel tournament;

  const _TournamentCard({required this.tournament});

  static String _fmtDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final t = tournament;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: EdgeInsets.zero,
        onTap: () =>
            Get.toNamed(AppRoutes.tournamentDetail, arguments: t.id),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner strip
            Container(
              height: 90,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: AppColors.darkHeaderGradient,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(Icons.emoji_events_outlined,
                        size: 44,
                        color: AppColors.accent.withValues(alpha: 0.6)),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: StatusBadge(status: t.status.key),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.name, style: AppTextStyles.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    '${t.sport} · ${t.format.label} · ${t.participationType.label}',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textGrey),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 14, color: AppColors.primary),
                      const SizedBox(width: 5),
                      Text('${_fmtDate(t.startDate)} – ${_fmtDate(t.endDate)}',
                          style: AppTextStyles.bodySmall),
                      const SizedBox(width: 14),
                      const Icon(Icons.group_outlined,
                          size: 14, color: AppColors.primary),
                      const SizedBox(width: 5),
                      Text('${t.registeredCount}/${t.maxParticipants}',
                          style: AppTextStyles.bodySmall),
                      const Spacer(),
                      Text(
                        t.isFree
                            ? 'FREE'
                            : 'PKR ${t.registrationFee.toStringAsFixed(0)}',
                        style: AppTextStyles.titleMedium.copyWith(
                          color: t.isFree
                              ? AppColors.success
                              : AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
