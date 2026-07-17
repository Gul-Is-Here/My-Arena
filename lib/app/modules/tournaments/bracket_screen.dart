import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/tournament_controller.dart';
import '../../data/models/tournament_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';

/// Public live bracket — elimination tree or round-robin points table.
/// Route argument: tournament id.
class BracketScreen extends StatefulWidget {
  const BracketScreen({super.key});

  @override
  State<BracketScreen> createState() => _BracketScreenState();
}

class _BracketScreenState extends State<BracketScreen> {
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
        title: Obx(() => Text(c.byId(id)?.name ?? 'Bracket')),
      ),
      body: Obx(() {
        final t = c.byId(id);
        final rounds = c.brackets[id];
        if (t == null || rounds == null) {
          return const Center(child: Text('Bracket not generated yet'));
        }
        return t.format == TournamentFormat.elimination
            ? _EliminationTree(rounds: rounds)
            : _PointsTable(entries: c.leaderboard(id), rounds: rounds);
      }),
    );
  }
}

// ── Elimination tree ──────────────────────────────────────────────────

class _EliminationTree extends StatelessWidget {
  final List<BracketRound> rounds;

  const _EliminationTree({required this.rounds});

  String _roundName(int idx) {
    final fromEnd = rounds.length - idx;
    if (fromEnd == 1) return 'Final';
    if (fromEnd == 2) return 'Semi-finals';
    if (fromEnd == 3) return 'Quarter-finals';
    return 'Round ${idx + 1}';
  }

  @override
  Widget build(BuildContext context) {
    // Each round's match slot doubles in height so matches line up
    // with the pair that feeds them.
    const baseSlot = 106.0;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var r = 0; r < rounds.length; r++) ...[
              SizedBox(
                width: 210,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_roundName(r), style: AppTextStyles.titleMedium),
                    const SizedBox(height: 12),
                    ...rounds[r].matches.map(
                          (m) => SizedBox(
                            height: baseSlot * (1 << r),
                            child: Center(child: _MatchCard(match: m)),
                          ),
                        ),
                  ],
                ),
              ),
              if (r < rounds.length - 1) const SizedBox(width: 16),
            ],
          ],
        ),
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final MatchModel match;

  const _MatchCard({required this.match});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            _slot(match.participant1, match.score1,
                match.winner != null && match.winner == match.participant1),
            const Divider(height: 14),
            _slot(match.participant2, match.score2,
                match.winner != null && match.winner == match.participant2),
          ],
        ),
      ),
    );
  }

  Widget _slot(String? name, int? score, bool isWinner) {
    return Row(
      children: [
        Expanded(
          child: Text(
            name ?? 'TBD',
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyMedium.copyWith(
              color: name == null ? AppColors.textGrey : null,
              fontWeight: isWinner ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
        ),
        if (isWinner)
          const Padding(
            padding: EdgeInsets.only(right: 6),
            child:
                Icon(Icons.emoji_events, size: 14, color: AppColors.warning),
          ),
        Text(
          score?.toString() ?? '–',
          style: AppTextStyles.titleMedium.copyWith(
            color: isWinner ? AppColors.primary : AppColors.textGrey,
          ),
        ),
      ],
    );
  }
}

// ── Round-robin points table ──────────────────────────────────────────

class _PointsTable extends StatelessWidget {
  final List<LeaderboardEntry> entries;
  final List<BracketRound> rounds;

  const _PointsTable({required this.entries, required this.rounds});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Points Table', style: AppTextStyles.titleLarge),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  const SizedBox(width: 28),
                  Expanded(
                      child: Text('Team',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textGrey))),
                  ...['P', 'W', 'D', 'L', 'Pts'].map(
                    (h) => SizedBox(
                      width: 30,
                      child: Text(h,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textGrey)),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              for (var i = 0; i < entries.length; i++) ...[
                Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text('${i + 1}',
                          style: AppTextStyles.titleMedium.copyWith(
                            color: i == 0
                                ? AppColors.warning
                                : AppColors.textGrey,
                          )),
                    ),
                    Expanded(
                      child: Text(entries[i].name,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight:
                                i == 0 ? FontWeight.w700 : FontWeight.normal,
                          )),
                    ),
                    _cell('${entries[i].played}'),
                    _cell('${entries[i].won}'),
                    _cell('${entries[i].drawn}'),
                    _cell('${entries[i].lost}'),
                    SizedBox(
                      width: 30,
                      child: Text('${entries[i].points}',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.titleMedium
                              .copyWith(color: AppColors.primary)),
                    ),
                  ],
                ),
                if (i < entries.length - 1) const Divider(height: 18),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('Matches', style: AppTextStyles.titleLarge),
        const SizedBox(height: 12),
        ...rounds.first.matches.map(
          (m) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(m.participant1 ?? 'TBD',
                        textAlign: TextAlign.end,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: m.status == 'completed'
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : AppColors.textGrey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      m.status == 'completed'
                          ? '${m.score1} – ${m.score2}'
                          : 'vs',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: m.status == 'completed'
                            ? AppColors.primary
                            : AppColors.textGrey,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(m.participant2 ?? 'TBD',
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _cell(String v) => SizedBox(
        width: 30,
        child: Text(v,
            textAlign: TextAlign.center, style: AppTextStyles.bodyMedium),
      );
}
