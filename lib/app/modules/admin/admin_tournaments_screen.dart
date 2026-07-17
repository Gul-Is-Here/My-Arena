import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/tournament_controller.dart';
import '../../data/models/tournament_model.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/status_badge.dart';

/// Admin tournament oversight — approvals + platform-wide creation.
class AdminTournamentsScreen extends StatefulWidget {
  const AdminTournamentsScreen({super.key});

  @override
  State<AdminTournamentsScreen> createState() => _AdminTournamentsScreenState();
}

class _AdminTournamentsScreenState extends State<AdminTournamentsScreen> {
  late final TournamentController c;

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<TournamentController>()) {
      Get.put(TournamentController(), permanent: true);
    }
    c = TournamentController.to;
    c.listenAllTournaments();
  }

  @override
  Widget build(BuildContext context) {

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tournaments'),
          bottom: TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textGrey,
            tabs: [
              Obx(() => Tab(text: 'Pending (${c.pendingApproval.length})')),
              const Tab(text: 'All'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('Create'),
          onPressed: () =>
              Get.toNamed(AppRoutes.createTournament, arguments: 'admin'),
        ),
        body: Obx(() {
          c.tournaments.length;
          return TabBarView(
            children: [
              _list(c.pendingApproval, c, pending: true),
              _list(c.tournaments.toList(), c, pending: false),
            ],
          );
        }),
      ),
    );
  }

  Widget _list(List<TournamentModel> items, TournamentController c,
      {required bool pending}) {
    if (items.isEmpty) {
      return Center(
          child: Text(pending ? 'No tournaments awaiting approval' : 'None',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textGrey)));
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
                            '${t.sport} · ${t.arenaName} · by ${t.createdByRole}',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textGrey),
                          ),
                        ],
                      ),
                    ),
                    StatusBadge(status: t.status.key),
                  ],
                ),
                if (pending) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async =>
                              await c.setStatus(t.id, TournamentStatus.rejected),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                          ),
                          child: const Text('Reject'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () async => await c.setStatus(
                              t.id, TournamentStatus.registrationOpen),
                          style: FilledButton.styleFrom(
                              backgroundColor: AppColors.success),
                          child: const Text('Approve'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
