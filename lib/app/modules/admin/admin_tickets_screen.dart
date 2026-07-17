import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/ticket_controller.dart';
import '../../data/models/ticket_model.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/status_badge.dart';

/// Support tickets — all tickets with status filter chips.
class AdminTicketsScreen extends StatelessWidget {
  const AdminTicketsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<TicketController>()) {
      Get.put(TicketController(), permanent: true);
    }
    final c = TicketController.to;

    return Scaffold(
      appBar: AppBar(title: const Text('Support Tickets')),
      body: Column(
        children: [
          // Status filter chips
          SizedBox(
            height: 52,
            child: Obx(
              () => ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  _chip(null, 'All', c),
                  for (final s in TicketStatus.values) _chip(s, s.label, c),
                ],
              ),
            ),
          ),
          Expanded(
            child: Obx(() {
              final items = c.filtered;
              if (items.isEmpty) {
                return Center(
                  child: Text('No tickets here',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textGrey)),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (_, i) => _ticketCard(items[i]),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _chip(TicketStatus? s, String label, TicketController c) {
    final selected = c.filter.value == s;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: AppColors.primary,
        labelStyle: AppTextStyles.bodySmall.copyWith(
          color: selected ? Colors.white : AppColors.textGrey,
          fontWeight: FontWeight.w600,
        ),
        onSelected: (_) => c.filter.value = s,
      ),
    );
  }

  Widget _ticketCard(TicketModel t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        onTap: () => Get.toNamed(AppRoutes.adminTicketDetail, arguments: t.id),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(t.subject, style: AppTextStyles.titleMedium),
                ),
                StatusBadge(status: t.status.key),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${t.raisedByName} (${t.raisedByRole})'
              '${t.arenaName != null ? ' · ${t.arenaName}' : ''}'
              '${t.bookingId != null ? ' · ${t.bookingId}' : ''}',
              style:
                  AppTextStyles.bodySmall.copyWith(color: AppColors.textGrey),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  t.assignedTo == null
                      ? Icons.person_off_outlined
                      : Icons.support_agent,
                  size: 16,
                  color: AppColors.textGrey,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    t.assignedTo == null
                        ? 'Unassigned'
                        : 'Assigned to ${t.assignedTo}',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textGrey),
                  ),
                ),
                if (t.replies.isNotEmpty)
                  Text('${t.replies.length} repl${t.replies.length == 1 ? 'y' : 'ies'}',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.primary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
