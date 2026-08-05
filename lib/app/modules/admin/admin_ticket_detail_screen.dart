import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/ticket_controller.dart';
import '../../data/models/ticket_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/status_badge.dart';

class AdminTicketDetailScreen extends StatefulWidget {
  const AdminTicketDetailScreen({super.key});

  @override
  State<AdminTicketDetailScreen> createState() =>
      _AdminTicketDetailScreenState();
}

class _AdminTicketDetailScreenState extends State<AdminTicketDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  late final String _ticketId;
  late final TicketController _c;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _ticketId = Get.arguments as String;
    if (!Get.isRegistered<TicketController>()) {
      Get.put(TicketController(), permanent: true);
    }
    _c = TicketController.to;
    _c.markRead(_ticketId);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Obx(() {
          final t = _c.byId(_ticketId);
          return Text(t?.ticketNumber.isNotEmpty == true
              ? t!.ticketNumber
              : 'Ticket Detail',
              style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w800));
        }),
        actions: [
          Obx(() {
            final t = _c.byId(_ticketId);
            if (t == null) return const SizedBox.shrink();
            return PopupMenuButton<String>(
              onSelected: (v) {
                switch (v) {
                  case 'priority_low':
                    _c.setPriority(_ticketId, TicketPriority.low);
                  case 'priority_medium':
                    _c.setPriority(_ticketId, TicketPriority.medium);
                  case 'priority_high':
                    _c.setPriority(_ticketId, TicketPriority.high);
                  case 'priority_urgent':
                    _c.setPriority(_ticketId, TicketPriority.urgent);
                  case 'in_progress':
                    _c.setStatus(_ticketId, TicketStatus.inProgress);
                  case 'waiting':
                    _c.setStatus(_ticketId, TicketStatus.waitingForCustomer);
                  case 'resolve':
                    _c.setStatus(_ticketId, TicketStatus.resolved);
                  case 'close':
                    _c.setStatus(_ticketId, TicketStatus.closed);
                  case 'reopen':
                    _c.setStatus(_ticketId, TicketStatus.open);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'priority_low', child: Text('Priority: Low')),
                const PopupMenuItem(
                    value: 'priority_medium', child: Text('Priority: Medium')),
                const PopupMenuItem(
                    value: 'priority_high', child: Text('Priority: High')),
                const PopupMenuItem(
                    value: 'priority_urgent',
                    child: Text('Priority: Urgent')),
                const PopupMenuDivider(),
                if (t.status != TicketStatus.inProgress)
                  const PopupMenuItem(
                      value: 'in_progress', child: Text('Mark In Progress')),
                const PopupMenuItem(
                    value: 'waiting',
                    child: Text('Waiting for Customer')),
                if (t.status != TicketStatus.resolved)
                  const PopupMenuItem(
                      value: 'resolve', child: Text('Mark Resolved')),
                if (t.status != TicketStatus.closed)
                  const PopupMenuItem(
                      value: 'close', child: Text('Close Ticket')),
                if (t.status == TicketStatus.closed ||
                    t.status == TicketStatus.resolved)
                  const PopupMenuItem(
                      value: 'reopen', child: Text('Reopen Ticket')),
              ],
            );
          }),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textGrey,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Chat'),
            Tab(text: 'Details'),
          ],
        ),
      ),
      body: Obx(() {
        final t = _c.byId(_ticketId);
        if (t == null) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primary));
        }
        return TabBarView(
          controller: _tabs,
          children: [
            // ── Chat tab ──────────────────────────────────────────────
            Column(children: [
              _statusBar(t),
              Expanded(child: _messageList(t.id)),
              _messageInput(t.id),
            ]),

            // ── Details tab ───────────────────────────────────────────
            _detailsTab(t),
          ],
        );
      }),
    );
  }

  Widget _statusBar(TicketModel t) {
    final priorityColor = _priorityColor(t.priority);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(children: [
        StatusBadge(status: t.status.key),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: priorityColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(t.priority.label,
              style: AppTextStyles.caption.copyWith(
                  color: priorityColor, fontWeight: FontWeight.w700)),
        ),
        const Spacer(),
        if (t.unreadCountAdmin > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('${t.unreadCountAdmin} new',
                style: AppTextStyles.caption.copyWith(
                    color: Colors.black, fontWeight: FontWeight.w700)),
          ),
      ]),
    );
  }

  Widget _messageList(String ticketId) {
    return StreamBuilder<List<TicketMessage>>(
      stream: _c.messagesStream(ticketId),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primary));
        }
        final msgs = snap.data!;
        if (msgs.isEmpty) {
          return Center(
              child: Text('No messages yet',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textGrey)));
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollCtrl.hasClients) {
            _scrollCtrl.animateTo(
              _scrollCtrl.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });

        final grouped = <String, List<TicketMessage>>{};
        for (final m in msgs) {
          final key = DateFormat('dd MMM yyyy').format(m.createdAt);
          grouped.putIfAbsent(key, () => []).add(m);
        }
        final keys = grouped.keys.toList();

        return ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          itemCount: keys.length,
          itemBuilder: (_, i) {
            final dateKey = keys[i];
            final dayMsgs = grouped[dateKey]!;
            return Column(children: [
              _dateSeparator(dateKey),
              ...dayMsgs.map(_messageBubble),
            ]);
          },
        );
      },
    );
  }

  Widget _dateSeparator(String date) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          const Expanded(child: Divider(color: AppColors.border)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(date,
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textGrey)),
          ),
          const Expanded(child: Divider(color: AppColors.border)),
        ]),
      );

  Widget _messageBubble(TicketMessage m) {
    if (m.type == TicketMessageType.system) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(m.content,
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textGrey),
                textAlign: TextAlign.center),
          ),
        ),
      );
    }

    final isAdmin = m.senderRole == 'admin' || m.senderRole == 'staff';
    final align = isAdmin ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor = isAdmin
        ? AppColors.primary.withValues(alpha: 0.15)
        : AppColors.surface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: align,
        children: [
          if (!isAdmin)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text(m.senderName,
                  style: AppTextStyles.caption.copyWith(
                      color: Colors.blue, fontWeight: FontWeight.w700)),
            ),
          Align(
            alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.72),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: isAdmin
                      ? const Radius.circular(18)
                      : const Radius.circular(4),
                  bottomRight: isAdmin
                      ? const Radius.circular(4)
                      : const Radius.circular(18),
                ),
                border: Border.all(
                    color: isAdmin
                        ? AppColors.primary.withValues(alpha: 0.3)
                        : AppColors.border),
              ),
              child: Text(m.content,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textPrimary, height: 1.4)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
            child: Text(DateFormat('HH:mm').format(m.createdAt),
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textGrey)),
          ),
        ],
      ),
    );
  }

  Widget _messageInput(String ticketId) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _msgCtrl,
              maxLines: null,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Reply as Support…',
                hintStyle: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textGrey),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide:
                        const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide:
                        const BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(
                        color: AppColors.primary, width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () async {
              final text = _msgCtrl.text.trim();
              if (text.isEmpty) return;
              _msgCtrl.clear();
              await _c.sendMessage(ticketId, text);
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                  color: AppColors.primary, shape: BoxShape.circle),
              child:
                  const Icon(Icons.send, color: Colors.black, size: 20),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _detailsTab(TicketModel t) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _sectionCard(
          title: 'Ticket Information',
          children: [
            _infoRow('Ticket ID', t.ticketNumber.isNotEmpty ? t.ticketNumber : t.id),
            _infoRow('Status', t.status.label, valueColor: _statusColor(t.status)),
            _infoRow('Priority', t.priority.label, valueColor: _priorityColor(t.priority)),
            _infoRow('Category', t.category),
            _infoRow('Raised by', '${t.raisedByName} (${t.raisedByRole})'),
            _infoRow('Assigned to', t.assignedTo ?? 'Unassigned'),
            _infoRow('Created', DateFormat('dd MMM yyyy, HH:mm').format(t.createdAt)),
            _infoRow('Updated', DateFormat('dd MMM yyyy, HH:mm').format(t.updatedAt)),
          ],
        ),

        if (t.bookingSnapshot != null) ...[
          const SizedBox(height: 16),
          _sectionCard(
            title: 'Related Booking',
            children: [
              _infoRow('Arena', t.bookingSnapshot!.arenaName),
              _infoRow('Court', t.bookingSnapshot!.courtName),
              _infoRow('Date', DateFormat('dd MMM yyyy').format(t.bookingSnapshot!.date)),
              _infoRow('Time', t.bookingSnapshot!.timeRange),
              _infoRow('Status', t.bookingSnapshot!.status),
              _infoRow('Booking ID', t.bookingSnapshot!.bookingId),
            ],
          ),
        ],

        const SizedBox(height: 16),

        _sectionCard(
          title: 'Original Message',
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(t.description,
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textPrimary, height: 1.5)),
            ),
          ],
        ),

        const SizedBox(height: 16),

        _sectionCard(
          title: 'Status Timeline',
          children: [
            if (t.statusHistory.isEmpty)
              Text('No status changes yet',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textGrey))
            else
              ...t.statusHistory.asMap().entries.map((e) {
                final s = e.value;
                final isLast = e.key == t.statusHistory.length - 1;
                final statusVal = TicketStatusX.fromKey(s.status);
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(children: [
                      Container(
                        width: 12,
                        height: 12,
                        margin: const EdgeInsets.only(top: 2),
                        decoration: BoxDecoration(
                            color: _statusColor(statusVal),
                            shape: BoxShape.circle),
                      ),
                      if (!isLast)
                        Container(
                            width: 2, height: 40, color: AppColors.border),
                    ]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(statusVal.label,
                                style: AppTextStyles.bodySmall.copyWith(
                                    color: _statusColor(statusVal),
                                    fontWeight: FontWeight.w700)),
                            Text(
                                '${DateFormat('dd MMM yyyy, HH:mm').format(s.changedAt)} · ${s.changedBy}',
                                style: AppTextStyles.caption
                                    .copyWith(color: AppColors.textGrey)),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }),
          ],
        ),
      ],
    );
  }

  Widget _sectionCard(
      {required String title, required List<Widget> children}) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      );

  Widget _infoRow(String label, String value, {Color? valueColor}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child:
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textGrey)),
          ),
          Expanded(
            child: Text(value,
                style: AppTextStyles.bodySmall.copyWith(
                    color: valueColor ?? AppColors.textPrimary,
                    fontWeight: valueColor != null
                        ? FontWeight.w600
                        : FontWeight.normal)),
          ),
        ]),
      );

  Color _statusColor(TicketStatus s) {
    switch (s) {
      case TicketStatus.open:
        return AppColors.primary;
      case TicketStatus.inProgress:
        return Colors.blue;
      case TicketStatus.waitingForCustomer:
        return AppColors.warning;
      case TicketStatus.resolved:
        return Colors.green;
      case TicketStatus.closed:
        return AppColors.textGrey;
    }
  }

  Color _priorityColor(TicketPriority p) {
    switch (p) {
      case TicketPriority.low:
        return Colors.green;
      case TicketPriority.medium:
        return Colors.blue;
      case TicketPriority.high:
        return AppColors.warning;
      case TicketPriority.urgent:
        return Colors.red;
    }
  }
}
