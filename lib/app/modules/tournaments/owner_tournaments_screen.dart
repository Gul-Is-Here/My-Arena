import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/tournament_controller.dart';
import '../../data/models/tournament_model.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/status_badge.dart';

/// Owner's tournaments — create new, open manage per tournament.
class OwnerTournamentsScreen extends StatefulWidget {
  const OwnerTournamentsScreen({super.key});

  @override
  State<OwnerTournamentsScreen> createState() => _OwnerTournamentsScreenState();
}

class _OwnerTournamentsScreenState extends State<OwnerTournamentsScreen> {
  late final TournamentController c;

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<TournamentController>()) {
      Get.put(TournamentController(), permanent: true);
    }
    c = TournamentController.to;
    c.listenOwnerTournaments();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: const Text('My Tournaments')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Create'),
        onPressed: () => Get.toNamed(AppRoutes.createTournament),
      ),
      body: Obx(() {
        final items = c.ownerTournaments;
        if (items.isEmpty) {
          return const Center(child: Text('No tournaments yet'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (_, i) {
            final t = items[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppCard(
                onTap: () =>
                    Get.toNamed(AppRoutes.tournamentManage, arguments: t.id),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.emoji_events_outlined,
                          color: AppColors.accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.name, style: AppTextStyles.titleMedium),
                          Text(
                            '${t.sport} · ${t.registeredCount}/${t.maxParticipants} registered',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textGrey),
                          ),
                        ],
                      ),
                    ),
                    StatusBadge(status: t.status.key),
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
