import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/customer_ticket_controller.dart';
import '../../data/models/ticket_model.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class CustomerTicketsScreen extends StatelessWidget {
  const CustomerTicketsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<CustomerTicketController>()) {
      Get.put(CustomerTicketController());
    }
    final c = CustomerTicketController.to;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: Get.back,
        ),
        title: Text('My Tickets',
            style: AppTextStyles.headlineMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            )),
        actions: [
          TextButton.icon(
            onPressed: () => Get.toNamed(AppRoutes.submitTicket),
            icon: const Icon(Icons.add, color: AppColors.primary, size: 18),
            label: Text('New',
                style:
                    AppTextStyles.bodySmall.copyWith(color: AppColors.primary)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.toNamed(AppRoutes.submitTicket),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.black),
        label: Text('Submit Ticket',
            style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.black, fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          // ── Search bar ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              onChanged: (v) => c.search.value = v,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search by ID, subject, booking…',
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
                return _emptyState(c.filter.value);
              }
              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async {},
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
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

  Widget _chip(TicketStatus? s, String label, CustomerTicketController c) {
    return Obx(() {
      final isSelected = c.filter.value == s;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () => c.filter.value = s,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border),
            ),
            child: Text(label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: isSelected ? Colors.black : AppColors.textGrey,
                  fontWeight: FontWeight.w600,
                )),
          ),
        ),
      );
    });
  }

  Widget _ticketCard(TicketModel t) {
    final hasUnread = t.unreadCountCustomer > 0;
    return GestureDetector(
      onTap: () => Get.toNamed(AppRoutes.customerTicketDetail,
          arguments: t.id),
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
                    Text(t.ticketNumber.isNotEmpty ? t.ticketNumber : '#${t.id.substring(0, 6).toUpperCase()}',
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
              const SizedBox(width: 12),
              _statusBadge(t.status),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              _infoChip(Icons.category_outlined, t.category),
              if (t.bookingSnapshot != null) ...[
                const SizedBox(width: 8),
                _infoChip(Icons.sports_soccer_outlined,
                    t.bookingSnapshot!.arenaName),
              ],
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Icon(Icons.access_time, size: 13, color: AppColors.textGrey),
              const SizedBox(width: 4),
              Text(_formatDate(t.createdAt),
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textGrey)),
              const Spacer(),
              if (hasUnread)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${t.unreadCountCustomer} new',
                      style: AppTextStyles.caption.copyWith(
                          color: Colors.black,
                          fontWeight: FontWeight.w700)),
                )
              else
                Text('Updated ${_formatRelative(t.updatedAt)}',
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(s.label,
          style: AppTextStyles.caption
              .copyWith(color: color, fontWeight: FontWeight.w700)),
    );
  }

  Widget _infoChip(IconData icon, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textGrey),
          const SizedBox(width: 4),
          Text(label,
              style:
                  AppTextStyles.caption.copyWith(color: AppColors.textGrey)),
        ],
      );

  Widget _emptyState(TicketStatus? filter) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.confirmation_number_outlined,
                size: 64, color: AppColors.textGrey.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
                filter == null
                    ? 'No support tickets yet'
                    : 'No ${filter.label.toLowerCase()} tickets',
                style: AppTextStyles.titleMedium
                    .copyWith(color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text('Tap "Submit Ticket" to get help',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textGrey)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Get.toNamed(AppRoutes.submitTicket),
              icon: const Icon(Icons.add, color: Colors.black),
              label: const Text('Submit Ticket'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12)),
            ),
          ],
        ),
      );

  String _formatDate(DateTime dt) =>
      DateFormat('dd MMM yyyy').format(dt);

  String _formatRelative(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
