import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/ticket_controller.dart';
import '../../data/models/ticket_model.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class AdminTicketsScreen extends StatelessWidget {
  const AdminTicketsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<TicketController>()) {
      Get.put(TicketController(), permanent: true);
    }
    final c = TicketController.to;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Support Tickets',
            style: AppTextStyles.headlineMedium.copyWith(
                color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
      ),
      body: Column(
        children: [
          // ── Search ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              onChanged: (v) => c.search.value = v,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search tickets…',
                hintStyle:
                    AppTextStyles.bodySmall.copyWith(color: AppColors.textGrey),
                prefixIcon: const Icon(Icons.search, color: AppColors.textGrey),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          // ── Filter chips ────────────────────────────────────────────
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                _chip(null, 'All', c),
                for (final s in TicketStatus.values) _chip(s, s.label, c),
              ],
            ),
          ),

          // ── Ticket list ─────────────────────────────────────────────
          Expanded(
            child: Obx(() {
              final items = c.filtered;
              if (items.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.confirmation_number_outlined,
                          size: 56,
                          color: AppColors.textGrey.withValues(alpha: 0.4)),
                      const SizedBox(height: 12),
                      Text('No tickets',
                          style: AppTextStyles.titleMedium
                              .copyWith(color: AppColors.textPrimary)),
                    ],
                  ),
                );
              }
              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async {},
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _ticketCard(items[i]),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _chip(TicketStatus? s, String label, TicketController c) {
    return Obx(() {
      final selected = c.filter.value == s;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () => c.filter.value = s,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border),
            ),
            child: Text(label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: selected ? Colors.black : AppColors.textGrey,
                  fontWeight: FontWeight.w600,
                )),
          ),
        ),
      );
    });
  }

  Widget _ticketCard(TicketModel t) {
    final hasUnread = t.unreadCountAdmin > 0;
    return GestureDetector(
      onTap: () =>
          Get.toNamed(AppRoutes.adminTicketDetail, arguments: t.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasUnread
                ? AppColors.primary.withValues(alpha: 0.5)
                : AppColors.border,
            width: hasUnread ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        t.ticketNumber.isNotEmpty
                            ? t.ticketNumber
                            : '#${t.id.substring(0, 6).toUpperCase()}',
                        style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(t.subject,
                        style: AppTextStyles.titleMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                _statusBadge(t.status),
                const SizedBox(height: 4),
                _priorityBadge(t.priority),
              ]),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.person_outline,
                  size: 13, color: AppColors.textGrey),
              const SizedBox(width: 4),
              Text('${t.raisedByName} · ${t.category}',
                  style:
                      AppTextStyles.caption.copyWith(color: AppColors.textGrey)),
            ]),
            if (t.bookingSnapshot != null) ...[
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.sports_soccer_outlined,
                    size: 13, color: AppColors.textGrey),
                const SizedBox(width: 4),
                Text(t.bookingSnapshot!.arenaName,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textGrey)),
              ]),
            ],
            const SizedBox(height: 10),
            Row(children: [
              Icon(
                t.assignedTo == null
                    ? Icons.person_off_outlined
                    : Icons.support_agent,
                size: 13,
                color: AppColors.textGrey,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  t.assignedTo == null
                      ? 'Unassigned'
                      : 'Assigned to ${t.assignedTo}',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textGrey),
                ),
              ),
              if (hasUnread)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${t.unreadCountAdmin} new',
                      style: AppTextStyles.caption.copyWith(
                          color: Colors.black,
                          fontWeight: FontWeight.w700)),
                )
              else
                Text(DateFormat('dd MMM, HH:mm').format(t.updatedAt),
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textGrey)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(TicketStatus s) {
    final Color color;
    switch (s) {
      case TicketStatus.open:
        color = AppColors.primary;
      case TicketStatus.inProgress:
        color = Colors.blue;
      case TicketStatus.waitingForCustomer:
        color = AppColors.warning;
      case TicketStatus.resolved:
        color = Colors.green;
      case TicketStatus.closed:
        color = AppColors.textGrey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6)),
      child: Text(s.label,
          style: AppTextStyles.caption
              .copyWith(color: color, fontWeight: FontWeight.w700)),
    );
  }

  Widget _priorityBadge(TicketPriority p) {
    final Color color;
    switch (p) {
      case TicketPriority.low:
        color = Colors.green;
      case TicketPriority.medium:
        color = Colors.blue;
      case TicketPriority.high:
        color = AppColors.warning;
      case TicketPriority.urgent:
        color = Colors.red;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6)),
      child: Text(p.label,
          style: AppTextStyles.caption
              .copyWith(color: color, fontWeight: FontWeight.w700)),
    );
  }
}
