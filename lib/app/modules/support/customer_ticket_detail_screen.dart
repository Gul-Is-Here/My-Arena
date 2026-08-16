import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/customer_ticket_controller.dart';
import '../../data/models/ticket_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class CustomerTicketDetailScreen extends StatefulWidget {
  const CustomerTicketDetailScreen({super.key});

  @override
  State<CustomerTicketDetailScreen> createState() =>
      _CustomerTicketDetailScreenState();
}

class _CustomerTicketDetailScreenState
    extends State<CustomerTicketDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  late final String _ticketId;
  late final CustomerTicketController _c;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _ticketId = (Get.arguments as String?) ?? '';
    if (!Get.isRegistered<CustomerTicketController>()) {
      Get.put(CustomerTicketController());
    }
    _c = CustomerTicketController.to;
    _c.openTicket(_ticketId);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _c.closeTicket();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: Get.back,
        ),
        title: Obx(() {
          final t = _c.byId(_ticketId);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  t?.ticketNumber.isNotEmpty == true
                      ? t!.ticketNumber
                      : 'Ticket Detail',
                  style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800)),
              if (t != null)
                Text(t.subject,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textGrey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
            ],
          );
        }),
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
        final isClosed = t.status == TicketStatus.closed ||
            t.status == TicketStatus.resolved;

        return TabBarView(
          controller: _tabs,
          children: [
            // ── Chat tab ────────────────────────────────────────────
            Column(children: [
              // Status bar
              _statusBar(t),
              // Messages
              Expanded(child: _messageList()),
              // Input
              if (!isClosed) _messageInput(t.id),
              if (isClosed)
                Container(
                  padding: const EdgeInsets.all(16),
                  color: AppColors.surface,
                  child: Text(
                    'This ticket is ${t.status.label.toLowerCase()}. You cannot send more messages.',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textGrey),
                    textAlign: TextAlign.center,
                  ),
                ),
            ]),

            // ── Details tab ─────────────────────────────────────────
            _detailsTab(t),
          ],
        );
      }),
    );
  }

  Widget _statusBar(TicketModel t) {
    final statusColor = _statusColor(t.status);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        border: Border(
            bottom: BorderSide(
                color: statusColor.withValues(alpha: 0.3))),
      ),
      child: Row(children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
              color: statusColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(t.status.label,
            style: AppTextStyles.bodySmall.copyWith(
                color: statusColor, fontWeight: FontWeight.w700)),
        const SizedBox(width: 4),
        Text('· ${t.category}',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textGrey)),
        const Spacer(),
        if (t.assignedTo != null)
          Row(children: [
            const Icon(Icons.support_agent,
                size: 13, color: AppColors.textGrey),
            const SizedBox(width: 4),
            Text(t.assignedTo!,
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textGrey)),
          ]),
      ]),
    );
  }

  Widget _messageList() {
    return Obx(() {
      final msgs = _c.messages;
      if (msgs.isEmpty) {
        return const Center(
            child:
                CircularProgressIndicator(color: AppColors.primary));
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });

      // Group by date
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
    });
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

    final isMe = m.senderRole == 'customer';
    final align = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor = isMe
        ? AppColors.primary.withValues(alpha: 0.15)
        : AppColors.surface;
    final textColor = AppColors.textPrimary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: align,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text(m.senderName,
                  style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700)),
            ),
          Row(
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe) ...[
                CircleAvatar(
                  radius: 14,
                  backgroundColor:
                      AppColors.primary.withValues(alpha: 0.2),
                  child: const Icon(Icons.support_agent,
                      size: 14, color: AppColors.primary),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  constraints: BoxConstraints(
                      maxWidth:
                          MediaQuery.of(context).size.width * 0.72),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: isMe
                          ? const Radius.circular(18)
                          : const Radius.circular(4),
                      bottomRight: isMe
                          ? const Radius.circular(4)
                          : const Radius.circular(18),
                    ),
                    border: Border.all(
                        color: isMe
                            ? AppColors.primary.withValues(alpha: 0.3)
                            : AppColors.border),
                  ),
                  child: Text(m.content,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: textColor, height: 1.4)),
                ),
              ),
              if (isMe) ...[
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 14,
                  backgroundColor:
                      AppColors.surface,
                  child: const Icon(Icons.person,
                      size: 14, color: AppColors.textGrey),
                ),
              ],
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
            child: Text(
                DateFormat('HH:mm').format(m.createdAt),
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
                hintText: 'Type a message…',
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
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send, color: Colors.black, size: 20),
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
        // ── Info card ──────────────────────────────────────────────
        _sectionCard(
          title: 'Ticket Information',
          children: [
            _infoRow('Ticket ID', t.ticketNumber.isNotEmpty ? t.ticketNumber : t.id),
            _infoRow('Status', t.status.label,
                valueColor: _statusColor(t.status)),
            _infoRow('Priority', t.priority.label,
                valueColor: _priorityColor(t.priority)),
            _infoRow('Category', t.category),
            _infoRow('Assigned to', t.assignedTo ?? 'Awaiting assignment'),
            _infoRow('Submitted', DateFormat('dd MMM yyyy, HH:mm').format(t.createdAt)),
            _infoRow('Last updated', DateFormat('dd MMM yyyy, HH:mm').format(t.updatedAt)),
          ],
        ),

        if (t.bookingSnapshot != null) ...[
          const SizedBox(height: 16),
          _sectionCard(
            title: 'Related Booking',
            children: [
              _infoRow('Arena', t.bookingSnapshot!.arenaName),
              _infoRow('Court', t.bookingSnapshot!.courtName),
              _infoRow('Date',
                  DateFormat('dd MMM yyyy').format(t.bookingSnapshot!.date)),
              _infoRow('Time', t.bookingSnapshot!.timeRange),
              _infoRow('Status', t.bookingSnapshot!.status),
            ],
          ),
        ],

        const SizedBox(height: 16),

        // ── Original message ───────────────────────────────────────
        _sectionCard(
          title: 'Original Message',
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(t.description,
                  style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary, height: 1.5)),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ── Timeline ───────────────────────────────────────────────
        _sectionCard(
          title: 'Status Timeline',
          children: [
            if (t.statusHistory.isEmpty)
              Text('No status changes yet',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textGrey))
            else
              ...t.statusHistory.asMap().entries.map((entry) {
                final i = entry.key;
                final s = entry.value;
                final isLast = i == t.statusHistory.length - 1;
                return _timelineEntry(s, isLast: isLast);
              }),
          ],
        ),
      ],
    );
  }

  Widget _sectionCard(
      {required String title, required List<Widget> children}) {
    return Container(
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
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 110,
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

  Widget _timelineEntry(StatusChange s, {bool isLast = false}) {
    final statusVal = TicketStatusX.fromKey(s.status);
    final color = _statusColor(statusVal);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(children: [
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          if (!isLast)
            Container(
                width: 2,
                height: 40,
                color: AppColors.border),
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
                        color: color, fontWeight: FontWeight.w700)),
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
  }

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
