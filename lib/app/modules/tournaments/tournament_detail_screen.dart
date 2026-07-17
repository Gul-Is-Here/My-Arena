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

/// Public tournament detail. Route argument: tournament id.
class TournamentDetailScreen extends StatelessWidget {
  const TournamentDetailScreen({super.key});

  static String _fmtDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final c = TournamentController.to;
    final String id = Get.arguments as String;

    return Scaffold(
      body: Obx(() {
        final t = c.byId(id);
        if (t == null) {
          return const Center(child: Text('Tournament not found'));
        }
        return CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 180,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                      gradient: AppColors.darkHeaderGradient),
                  child: Center(
                    child: Icon(Icons.emoji_events_outlined,
                        size: 72,
                        color: AppColors.accent.withValues(alpha: 0.5)),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child:
                              Text(t.name, style: AppTextStyles.headlineLarge),
                        ),
                        StatusBadge(status: t.status.key),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(t.arenaName,
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.textGrey)),
                    const SizedBox(height: 12),
                    Text(t.description, style: AppTextStyles.bodyMedium),
                    const SizedBox(height: 20),

                    AppCard(
                      child: Column(
                        children: [
                          _row('Sport', t.sport),
                          const SizedBox(height: 10),
                          _row('Format', t.format.label),
                          const SizedBox(height: 10),
                          _row('Participation', t.participationType.label),
                          const SizedBox(height: 10),
                          _row('Dates',
                              '${_fmtDate(t.startDate)} – ${_fmtDate(t.endDate)}'),
                          const SizedBox(height: 10),
                          _row('Register by', _fmtDate(t.registrationDeadline)),
                          const SizedBox(height: 10),
                          _row('Slots',
                              '${t.registeredCount} of ${t.maxParticipants} filled'),
                          const SizedBox(height: 10),
                          _row(
                              'Entry',
                              t.isFree
                                  ? 'Free'
                                  : 'PKR ${t.registrationFee.toStringAsFixed(0)}'),
                          if (t.prizeDetails.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            _row('Prize', t.prizeDetails),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (c.brackets.containsKey(t.id))
                      AppButton(
                        label: t.format == TournamentFormat.elimination
                            ? 'View Live Bracket'
                            : 'View Points Table',
                        outlined: true,
                        icon: Icons.account_tree_outlined,
                        onPressed: () =>
                            Get.toNamed(AppRoutes.bracket, arguments: t.id),
                      ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
      bottomNavigationBar: Obx(() {
        final t = c.byId(id);
        if (t == null) return const SizedBox.shrink();
        final registered = c.isRegistered(id);
        final open = t.status == TournamentStatus.registrationOpen &&
            t.registeredCount < t.maxParticipants;
        if (!open && !registered) return const SizedBox.shrink();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: registered
                ? AppButton(
                    label: 'Registered — View Pass',
                    icon: Icons.qr_code_2,
                    onPressed: () => Get.toNamed(AppRoutes.myTournaments),
                  )
                : AppButton(
                    label: t.isFree
                        ? 'Register — Free'
                        : 'Register — PKR ${t.registrationFee.toStringAsFixed(0)}',
                    icon: Icons.how_to_reg_outlined,
                    onPressed: () => Get.toNamed(
                        AppRoutes.tournamentRegistration,
                        arguments: t.id),
                  ),
          ),
        );
      }),
    );
  }

  Widget _row(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textGrey)),
        const SizedBox(width: 16),
        Flexible(
          child: Text(value,
              textAlign: TextAlign.end, style: AppTextStyles.titleMedium),
        ),
      ],
    );
  }
}
