import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/admin_controller.dart';
import '../../controllers/ticket_controller.dart';
import '../../data/models/ticket_model.dart';
import '../../data/models/user_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/status_badge.dart';

/// Ticket detail — full thread, reply box, assign / resolve / close / reopen.
class AdminTicketDetailScreen extends StatelessWidget {
  const AdminTicketDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = TicketController.to;
    final id = Get.arguments as String;
    final replyCtrl = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ticket Detail'),
        actions: [
          Obx(() {
            final t = c.byId(id);
            if (t == null) return const SizedBox.shrink();
            return PopupMenuButton<String>(
              onSelected: (v) {
                switch (v) {
                  case 'assign':
                    _assignSheet(c, t);
                  case 'resolve':
                    c.setStatus(id, TicketStatus.resolved);
                  case 'close':
                    c.setStatus(id, TicketStatus.closed);
                  case 'reopen':
                    c.setStatus(id, TicketStatus.open);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'assign', child: Text('Assign to staff')),
                if (t.status != TicketStatus.resolved)
                  const PopupMenuItem(
                      value: 'resolve', child: Text('Mark resolved')),
                if (t.status != TicketStatus.closed)
                  const PopupMenuItem(
                      value: 'close', child: Text('Close ticket')),
                if (t.status == TicketStatus.closed ||
                    t.status == TicketStatus.resolved)
                  const PopupMenuItem(
                      value: 'reopen', child: Text('Reopen ticket')),
              ],
            );
          }),
        ],
      ),
      body: Obx(() {
        final t = c.byId(id);
        if (t == null) {
          return const Center(child: Text('Ticket not found'));
        }
        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                                child: Text(t.subject,
                                    style: AppTextStyles.titleMedium)),
                            StatusBadge(status: t.status.key),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (t.description.isNotEmpty) ...[
                          Text(t.description, style: AppTextStyles.bodyMedium),
                          const SizedBox(height: 12),
                        ],
                        _infoRow('Raised by',
                            '${t.raisedByName} (${t.raisedByRole})'),
                        _infoRow('Category', t.category.capitalizeFirst!),
                        if (t.arenaName != null)
                          _infoRow('Arena', t.arenaName!),
                        if (t.bookingId != null)
                          _infoRow('Booking', t.bookingId!),
                        _infoRow('Assigned to', t.assignedTo ?? 'Unassigned'),
                        _infoRow('Ticket ID', t.id.toUpperCase()),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Conversation', style: AppTextStyles.titleLarge),
                  const SizedBox(height: 10),
                  if (t.replies.isEmpty)
                    Text('No replies yet.',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textGrey))
                  else
                    ...t.replies.map(_replyBubble),
                ],
              ),
            ),
            // Reply box
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: replyCtrl,
                        decoration: InputDecoration(
                          hintText: 'Reply as Admin…',
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      style: IconButton.styleFrom(
                          backgroundColor: AppColors.primary),
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: () {
                        c.reply(id, replyCtrl.text);
                        replyCtrl.clear();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  void _assignSheet(TicketController c, TicketModel t) {
    final staff = AdminController.to.users
        .where((u) => u.role == UserRole.staff)
        .toList();
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Assign to staff', style: AppTextStyles.titleLarge),
            const SizedBox(height: 12),
            ...staff.map(
              (u) => ListTile(
                leading: const Icon(Icons.support_agent,
                    color: AppColors.primary),
                title: Text(u.name),
                subtitle: Text(u.email, style: AppTextStyles.bodySmall),
                onTap: () {
                  c.assign(t.id, u.name);
                  Get.back();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textGrey)),
          ),
          Expanded(child: Text(value, style: AppTextStyles.bodySmall)),
        ],
      ),
    );
  }

  Widget _replyBubble(TicketReply r) {
    final isStaffSide = r.senderRole == 'admin' || r.senderRole == 'staff';
    return Align(
      alignment: isStaffSide ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: isStaffSide
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.darkCard,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${r.senderName} · ${r.senderRole}',
                style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(r.message, style: AppTextStyles.bodyMedium),
          ],
        ),
      ),
    );
  }
}
