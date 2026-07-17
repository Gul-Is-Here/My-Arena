import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/tournament_controller.dart';
import '../../data/models/tournament_model.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/status_badge.dart';

/// Owner management — registrations & payment verify, bracket
/// generation, live score entry. Route argument: tournament id.
class TournamentManageScreen extends StatefulWidget {
  const TournamentManageScreen({super.key});

  @override
  State<TournamentManageScreen> createState() => _TournamentManageScreenState();
}

class _TournamentManageScreenState extends State<TournamentManageScreen> {
  late final String id = Get.arguments as String;

  @override
  void initState() {
    super.initState();
    TournamentController.to.listenBracket(id);
  }

  @override
  Widget build(BuildContext context) {
    final c = TournamentController.to;

    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(c.byId(id)?.name ?? 'Manage')),
      ),
      body: Obx(() {
        final t = c.byId(id);
        if (t == null) {
          return const Center(child: Text('Tournament not found'));
        }
        final regs = c.registrationsFor(id);
        final rounds = c.brackets[id];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${t.registeredCount}/${t.maxParticipants} registered',
                    style: AppTextStyles.titleMedium),
                StatusBadge(status: t.status.key),
              ],
            ),
            const SizedBox(height: 16),

            // ── Registrations ─────────────────────────────────────────
            Text('Registrations', style: AppTextStyles.titleLarge),
            const SizedBox(height: 12),
            if (regs.isEmpty)
              Text('No registrations yet',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textGrey))
            else
              ...regs.map((r) => _regCard(context, c, r)),
            const SizedBox(height: 20),

            // ── Bracket / scores ──────────────────────────────────────
            if (rounds == null &&
                t.status != TournamentStatus.completed) ...[
              AppButton(
                label: 'Generate Bracket',
                icon: Icons.shuffle,
                onPressed: regs.where((r) => r.status == 'confirmed').length <
                        2
                    ? null
                    : () async {
                        await c.generateBracket(id);
                        Get.snackbar('Bracket ready',
                            'Participants shuffled — tournament is live.',
                            snackPosition: SnackPosition.BOTTOM,
                            margin: const EdgeInsets.all(16));
                      },
              ),
              const SizedBox(height: 8),
              Text(
                'Needs at least 2 confirmed participants. Shuffles entries and opens the public bracket.',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textGrey),
              ),
            ] else if (rounds != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Live Scores', style: AppTextStyles.titleLarge),
                  TextButton.icon(
                    onPressed: () =>
                        Get.toNamed(AppRoutes.bracket, arguments: id),
                    icon: const Icon(Icons.account_tree_outlined, size: 18),
                    label: Text(t.format == TournamentFormat.elimination
                        ? 'Bracket'
                        : 'Table'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (var r = 0; r < rounds.length; r++)
                for (var m = 0; m < rounds[r].matches.length; m++)
                  if (rounds[r].matches[m].participant1 != null &&
                      rounds[r].matches[m].participant2 != null)
                    _matchTile(context, c, id, r, m, rounds[r].matches[m]),
            ],
            const SizedBox(height: 24),
          ],
        );
      }),
    );
  }

  Widget _regCard(
      BuildContext context, TournamentController c, RegistrationModel r) {
    final needsVerify = r.paymentStatus == 'pending';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              r.type == ParticipationType.team
                  ? Icons.groups_outlined
                  : Icons.person_outline,
              color: AppColors.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.playerName, style: AppTextStyles.titleMedium),
                  Text(
                    r.type == ParticipationType.team
                        ? '${r.members.length} members'
                        : (r.phone.isEmpty ? 'Individual' : r.phone),
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textGrey),
                  ),
                ],
              ),
            ),
            if (needsVerify)
              FilledButton(
                onPressed: () async {
                  await c.verifyPayment(r.id);
                  Get.snackbar('Payment verified',
                      '${r.playerName} is confirmed — pass activated.',
                      snackPosition: SnackPosition.BOTTOM,
                      margin: const EdgeInsets.all(16));
                },
                style:
                    FilledButton.styleFrom(backgroundColor: AppColors.success),
                child: const Text('Verify'),
              )
            else
              StatusBadge(status: r.status),
          ],
        ),
      ),
    );
  }

  Widget _matchTile(BuildContext context, TournamentController c, String id,
      int roundIdx, int matchIdx, MatchModel m) {
    final done = m.status == 'completed';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        onTap: done ? null : () => _scoreDialog(context, c, id, roundIdx, matchIdx, m),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${m.participant1} vs ${m.participant2}',
                style: AppTextStyles.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (done)
              Text('${m.score1} – ${m.score2}',
                  style: AppTextStyles.titleMedium
                      .copyWith(color: AppColors.primary))
            else
              const Row(
                children: [
                  Icon(Icons.scoreboard_outlined,
                      size: 18, color: AppColors.accent),
                  SizedBox(width: 6),
                  Text('Enter score',
                      style: TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _scoreDialog(BuildContext context, TournamentController c, String id,
      int roundIdx, int matchIdx, MatchModel m) {
    final s1Ctrl = TextEditingController();
    final s2Ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Enter Score'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _scoreField(m.participant1!, s1Ctrl),
            const SizedBox(height: 12),
            _scoreField(m.participant2!, s2Ctrl),
          ],
        ),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final s1 = int.tryParse(s1Ctrl.text);
              final s2 = int.tryParse(s2Ctrl.text);
              if (s1 == null || s2 == null) return;
              final t = c.byId(id)!;
              if (t.format == TournamentFormat.elimination && s1 == s2) {
                Get.snackbar('No draws',
                    'Elimination matches need a winner.',
                    snackPosition: SnackPosition.BOTTOM,
                    margin: const EdgeInsets.all(16));
                return;
              }
              await c.enterScore(id, roundIdx, matchIdx, s1, s2);
              Get.back();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _scoreField(String name, TextEditingController ctrl) {
    return Row(
      children: [
        Expanded(
          child: Text(name,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyMedium),
        ),
        SizedBox(
          width: 70,
          child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(hintText: '0'),
          ),
        ),
      ],
    );
  }
}
