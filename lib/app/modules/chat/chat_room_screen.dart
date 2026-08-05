import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/chat_controller.dart';
import '../../controllers/owner_booking_controller.dart';
import '../../data/models/booking_model.dart';
import '../../data/models/chat_model.dart';
import '../../data/models/ticket_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

const _bg = AppColors.background;
const _surface = AppColors.surface;
const _surfaceLow = AppColors.elevated;
const _outline = AppColors.border;
const _onSurface = AppColors.textPrimary;
const _onSurfaceVar = AppColors.textSecondary;

const _months = [
  'JANUARY',
  'FEBRUARY',
  'MARCH',
  'APRIL',
  'MAY',
  'JUNE',
  'JULY',
  'AUGUST',
  'SEPTEMBER',
  'OCTOBER',
  'NOVEMBER',
  'DECEMBER',
];

/// One conversation — bubbles, text input, image/document attach stubs.
/// Route argument: chat id.
class ChatRoomScreen extends StatefulWidget {
  const ChatRoomScreen({super.key});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  late final String chatId = Get.arguments as String;

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_textCtrl.text.trim().isEmpty) return;
    final text = _textCtrl.text;
    _textCtrl.clear();
    await ChatController.to.sendMessage(chatId, text);
    _scrollToBottom();
  }

  Future<void> _attach(MessageType type) async {
    Get.back(); // close the sheet
    await ChatController.to.sendMessage(chatId, '', type: type);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showAttachSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _attachOption(
                Icons.photo_outlined,
                'Photo',
                () => _attach(MessageType.image),
              ),
              _attachOption(
                Icons.insert_drive_file_outlined,
                'Document',
                () => _attach(MessageType.document),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _attachOption(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: _onSurface,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // Guards against double-taps while an approve/reject write is in flight.
  bool _actionBusy = false;

  OwnerBookingController get _ownerCtrl {
    if (!Get.isRegistered<OwnerBookingController>()) {
      Get.put(OwnerBookingController(), permanent: true);
    }
    return OwnerBookingController.to;
  }

  Future<void> _approveBooking(BookingModel b) async {
    if (_actionBusy) return;
    setState(() => _actionBusy = true);
    try {
      await _ownerCtrl.approve(b.id, booking: b);
      Get.snackbar(
        'Booking Approved',
        '${b.courtName} · ${b.timeRange}',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Approval failed',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _rejectBooking(BookingModel b) async {
    if (_actionBusy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        title: Text(
          'Reject booking?',
          style: AppTextStyles.titleMedium.copyWith(color: _onSurface),
        ),
        content: Text(
          '${b.courtName} · ${ChatController.dateLabelFor(b.date)} · ${b.timeRange}\n'
          'The customer will be notified and the deposit flow stops.',
          style: AppTextStyles.bodySmall.copyWith(color: _onSurfaceVar),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Reject',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _actionBusy = true);
    try {
      await _ownerCtrl.reject(b.id);
    } catch (e) {
      Get.snackbar(
        'Rejection failed',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  /// View adapter: a live BookingModel rendered through the same banner and
  /// detail sheet the legacy snapshot path uses.
  static BookingSnapshot _snapOf(BookingModel b) => BookingSnapshot(
    arenaName: b.arenaName,
    courtName: b.courtName,
    date: b.date,
    timeRange: b.timeRange,
    totalAmount: b.totalAmount,
    depositAmount: b.depositAmount,
    status: b.status.key,
  );

  void _showBookingPicker(
    ChatModel chat,
    List<BookingModel> bookings,
    String pinnedId,
  ) {
    final sorted = bookings.toList()
      ..sort((a, b) => b.startDateTime.compareTo(a.startDateTime));

    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Text(
                'Select booking to discuss',
                style: AppTextStyles.titleMedium.copyWith(
                  color: _onSurface,
                  fontSize: 15,
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                itemCount: sorted.length,
                itemBuilder: (_, i) {
                  final b = sorted[i];
                  final pinned = b.id == pinnedId;
                  final color = _bookingStatusColor(b.status.key);
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Get.back();
                      if (!pinned) {
                        ChatController.to.setActiveBooking(chat.id, b.id);
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: pinned
                            ? AppColors.primary.withValues(alpha: 0.06)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: pinned
                              ? AppColors.primary.withValues(alpha: 0.30)
                              : _outline,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${b.courtName} · ${ChatController.dateLabelFor(b.date)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${b.timeRange} · Rs ${b.totalAmount.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: _onSurfaceVar,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              b.status.label,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ),
                          if (pinned) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.check_circle,
                              size: 16,
                              color: AppColors.primary,
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBookingSnapshotSheet(BookingSnapshot snap) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final d = snap.date;
    final dateStr =
        '${weekdays[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';

    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2),
                      ),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      Icons.stadium_outlined,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      snap.arenaName,
                      style: AppTextStyles.titleLarge.copyWith(
                        color: _onSurface,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: _outline),
              const SizedBox(height: 16),
              _sheetRow('Court', snap.courtName),
              _sheetRow('Date', dateStr),
              _sheetRow('Time', snap.timeRange),
              _sheetRow('Total', 'Rs ${snap.totalAmount.toStringAsFixed(0)}'),
              _sheetRow(
                'Deposit',
                'Rs ${snap.depositAmount.toStringAsFixed(0)}',
              ),
              const SizedBox(height: 4),
              _sheetRow(
                'Status',
                snap.statusLabel,
                valueColor: _bookingStatusColor(snap.status),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetRow(String label, String value, {Color? valueColor}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: _onSurfaceVar),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? _onSurface,
            ),
          ),
        ),
      ],
    ),
  );

  static Color _bookingStatusColor(String status) {
    switch (status) {
      case 'confirmed':
      case 'completed':
        return AppColors.success;
      case 'rejected':
      case 'cancelled':
        return AppColors.error;
      case 'refund_pending':
      case 'refund_sent':
      case 'refund_confirmed':
        return AppColors.warning;
      default:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ChatController.to;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(c),
            // Support context bar (ticket/booking selector)
            Obx(() {
              final chat = c.byId(chatId);
              if (chat == null || chat.type == ChatType.booking) {
                return const SizedBox.shrink();
              }
              return _SupportContextBar(controller: c);
            }),
            // Support context banner (selected ticket/booking info)
            Obx(() {
              final chat = c.byId(chatId);
              if (chat == null || chat.type == ChatType.booking) {
                return const SizedBox.shrink();
              }
              return _SupportContextBanner(controller: c);
            }),
            Obx(() {
              final chat = c.byId(chatId);
              if (chat == null || chat.type != ChatType.booking) {
                return const SizedBox.shrink();
              }

              // Pair chat: banner reads live from the bookings collection.
              if (chat.pairKey != null) {
                final bookings = c.bookingsForPair(chat);
                final pinned = c.pinnedBookingFor(chat, bookings);
                if (pinned != null) {
                  final snap = _snapOf(pinned);
                  final canAct =
                      !_actionBusy &&
                      pinned.ownerId == c.myUid &&
                      pinned.status == BookingStatus.depositSubmitted;
                  return _BookingContextBanner(
                    snapshot: snap,
                    onTap: () => _showBookingSnapshotSheet(snap),
                    onSwitch: bookings.length > 1
                        ? () => _showBookingPicker(chat, bookings, pinned.id)
                        : null,
                    bookingCount: bookings.length,
                    onApprove: canAct ? () => _approveBooking(pinned) : null,
                    onReject: canAct ? () => _rejectBooking(pinned) : null,
                  );
                }
                // Stream not loaded yet — fall through to legacy snapshot.
              }

              final snap = chat.bookingSnapshot;
              if (snap == null) return const SizedBox.shrink();
              return _BookingContextBanner(
                snapshot: snap,
                onTap: () => _showBookingSnapshotSheet(snap),
              );
            }),
            Expanded(
              child: Obx(() {
                final msgs = c.messagesFor(chatId);
                if (msgs.isEmpty) {
                  return Center(
                    child: Text(
                      'No messages yet. Say hello!',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: _onSurfaceVar,
                      ),
                    ),
                  );
                }
                _scrollToBottom();
                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  itemCount: msgs.length,
                  itemBuilder: (_, i) {
                    final msg = msgs[i];
                    final showDate =
                        i == 0 ||
                        !_sameDay(msgs[i - 1].createdAt, msg.createdAt);
                    // Divider when the booking being discussed changes.
                    BookingRef? lastRef;
                    for (var j = i - 1; j >= 0; j--) {
                      final r = msgs[j].bookingRef;
                      if (r != null) {
                        lastRef = r;
                        break;
                      }
                    }
                    final showRef =
                        msg.bookingRef != null &&
                        lastRef != null &&
                        lastRef.bookingId != msg.bookingRef!.bookingId;

                    // Ticket context divider
                    TicketRef? lastTicketRef;
                    for (var j = i - 1; j >= 0; j--) {
                      final r = msgs[j].ticketRef;
                      if (r != null) {
                        lastTicketRef = r;
                        break;
                      }
                    }
                    final showTicketRef =
                        msg.ticketRef != null &&
                        lastTicketRef != null &&
                        lastTicketRef.ticketId != msg.ticketRef!.ticketId;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showDate) _dateDivider(msg.createdAt),
                        if (showRef) _refDivider(msg.bookingRef!),
                        if (showTicketRef) _ticketRefDivider(msg.ticketRef!),
                        if (msg.type == MessageType.system)
                          _systemMessage(msg)
                        else
                          _bubble(context, msg, c.myUid),
                      ],
                    );
                  },
                );
              }),
            ),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _dateDivider(DateTime d) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _outline),
        ),
        child: Text(
          '${_months[d.month - 1]} ${d.day}, ${d.year}',
          style: AppTextStyles.caption.copyWith(
            color: _onSurfaceVar,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      ),
    ),
  );

  /// Marks a switch of booking context mid-conversation.
  Widget _refDivider(BookingRef ref) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        const Expanded(child: Divider(color: _outline, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            're: ${ref.label}',
            style: AppTextStyles.caption.copyWith(
              color: _onSurfaceVar,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Expanded(child: Divider(color: _outline, height: 1)),
      ],
    ),
  );

  Widget _ticketRefDivider(TicketRef ref) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        const Expanded(child: Divider(color: _outline, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.confirmation_number_outlined,
                size: 10,
                color: _onSurfaceVar,
              ),
              const SizedBox(width: 4),
              Text(
                ref.label,
                style: AppTextStyles.caption.copyWith(
                  color: _onSurfaceVar,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const Expanded(child: Divider(color: _outline, height: 1)),
      ],
    ),
  );

  /// Status-change events written by the backend ('Booking approved', …).
  Widget _systemMessage(MessageModel msg) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, size: 12, color: _onSurfaceVar),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                msg.content,
                style: AppTextStyles.caption.copyWith(
                  color: _onSurfaceVar,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildHeader(ChatController c) => Container(
    padding: const EdgeInsets.fromLTRB(4, 8, 16, 12),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: _outline)),
    ),
    child: Obx(() {
      final chat = c.byId(chatId);
      return Row(
        children: [
          IconButton(
            onPressed: () => Get.back(),
            icon: const Icon(Icons.arrow_back, color: _onSurface),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _outline),
            ),
            child: Icon(
              chat?.type == ChatType.booking
                  ? Icons.stadium_outlined
                  : Icons.support_agent,
              color: _onSurfaceVar,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  chat?.title ?? 'Chat',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleLarge.copyWith(
                    color: _onSurface,
                    fontSize: 17,
                  ),
                ),
                if ((chat?.subtitle ?? '').isNotEmpty)
                  Text(
                    chat!.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: _onSurfaceVar,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    }),
  );

  Widget _buildInputBar() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
    child: Row(
      children: [
        GestureDetector(
          onTap: _showAttachSheet,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25),
              ),
            ),
            child: const Icon(Icons.add, color: AppColors.primary),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _outline),
            ),
            child: TextField(
              controller: _textCtrl,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              style: AppTextStyles.bodyMedium.copyWith(color: _onSurface),
              decoration: InputDecoration(
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: AppColors.primary),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: AppColors.primary),
                ),
                hintText: 'Type a message…',
                hintStyle: AppTextStyles.bodyMedium.copyWith(
                  color: _onSurfaceVar,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: _send,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Icon(Icons.send, color: AppColors.onPrimary, size: 20),
          ),
        ),
      ],
    ),
  );

  static bool _isBookingDetailsMsg(String content) =>
      content.trim().startsWith('📋 Booking Details');

  static List<MapEntry<String, String>> _parseBookingDetails(String content) {
    final rows = <MapEntry<String, String>>[];
    for (final line in content.split('\n').skip(1)) {
      if (line.contains('━')) continue;
      final idx = line.indexOf(':');
      if (idx == -1) continue;
      rows.add(
        MapEntry(line.substring(0, idx).trim(), line.substring(idx + 1).trim()),
      );
    }
    return rows;
  }

  Widget _bookingDetailsCard(MessageModel msg, bool mine) {
    final rows = _parseBookingDetails(msg.content);
    final time =
        '${msg.createdAt.hour.toString().padLeft(2, '0')}:${msg.createdAt.minute.toString().padLeft(2, '0')}';
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.secondary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.secondary.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: AppColors.secondary.withValues(alpha: 0.15),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.assignment_outlined,
                  color: AppColors.secondary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Booking Details',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.secondary,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(color: _outline, height: 1),
            ),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '${row.key}: '),
                      TextSpan(
                        text: row.value,
                        style: row.key.contains('Status')
                            ? AppTextStyles.bodySmall.copyWith(
                                color: AppColors.secondary,
                                fontWeight: FontWeight.w800,
                              )
                            : AppTextStyles.bodySmall.copyWith(
                                color: _onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                      ),
                    ],
                    style: AppTextStyles.bodySmall.copyWith(
                      color: _onSurfaceVar,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    time,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 10,
                      color: _onSurfaceVar,
                    ),
                  ),
                  if (mine) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.done_all,
                      size: 14,
                      color: msg.isRead ? AppColors.success : _onSurfaceVar,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(BuildContext context, MessageModel msg, String myUid) {
    final mine = msg.senderId == myUid;

    if (msg.type == MessageType.text && _isBookingDetailsMsg(msg.content)) {
      return _bookingDetailsCard(msg, mine);
    }

    Widget content;
    switch (msg.type) {
      case MessageType.text:
      case MessageType.system:
        content = Text(
          msg.content,
          style: AppTextStyles.bodyMedium.copyWith(
            color: _onSurface,
            fontSize: 14,
            height: 1.3,
          ),
        );
        break;
      case MessageType.image:
        content = ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: msg.content.startsWith('http')
              ? Image.network(
                  msg.content,
                  width: 180,
                  height: 130,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, e, s) =>
                      const Icon(Icons.broken_image, color: _onSurfaceVar),
                )
              : Container(
                  width: 180,
                  height: 130,
                  color: _outline.withValues(alpha: 0.3),
                  child: const Icon(
                    Icons.image_outlined,
                    size: 42,
                    color: _onSurfaceVar,
                  ),
                ),
        );
        break;
      case MessageType.document:
        content = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.insert_drive_file_outlined,
              size: 20,
              color: AppColors.secondary,
            ),
            const SizedBox(width: 8),
            Text(
              msg.fileName ?? 'Document',
              style: AppTextStyles.bodyMedium.copyWith(
                color: _onSurface,
                fontSize: 14,
              ),
            ),
          ],
        );
        break;
    }

    final time =
        '${msg.createdAt.hour.toString().padLeft(2, '0')}:${msg.createdAt.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: mine ? AppColors.primary.withValues(alpha: 0.07) : _surfaceLow,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
          border: mine
              ? Border.all(color: AppColors.primary.withValues(alpha: 0.18))
              : Border.all(color: _outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            content,
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!mine)
                  Text(
                    '${msg.senderRole} · ',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 10,
                      color: _onSurfaceVar,
                    ),
                  ),
                Text(
                  time,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 10,
                    color: _onSurfaceVar,
                  ),
                ),
                if (mine) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.done_all,
                    size: 14,
                    color: msg.isRead ? AppColors.success : _onSurfaceVar,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pinned booking context banner — shown between header and messages.
// Taps open a bottom sheet with full booking details.
// ─────────────────────────────────────────────────────────────────────────────

class _BookingContextBanner extends StatelessWidget {
  final BookingSnapshot snapshot;
  final VoidCallback onTap;

  /// When the pair has multiple bookings: opens the booking picker.
  final VoidCallback? onSwitch;
  final int bookingCount;

  /// Owner-only, when the pinned booking awaits approval. Both null hides
  /// the action row entirely.
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const _BookingContextBanner({
    required this.snapshot,
    required this.onTap,
    this.onSwitch,
    this.bookingCount = 1,
    this.onApprove,
    this.onReject,
  });

  static Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
      case 'completed':
        return AppColors.success;
      case 'rejected':
      case 'cancelled':
        return AppColors.error;
      case 'refund_pending':
      case 'refund_sent':
      case 'refund_confirmed':
        return AppColors.warning;
      case 'deposit_submitted':
        return AppColors.secondary;
      default:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(snapshot.status);
    final isConfirmed =
        snapshot.status == 'confirmed' || snapshot.status == 'completed';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isConfirmed
              ? AppColors.success.withValues(alpha: 0.04)
              : AppColors.surface,
          border: const Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isConfirmed
                        ? AppColors.success.withValues(alpha: 0.10)
                        : AppColors.primary.withValues(alpha: 0.08),
                    border: Border.all(
                      color: isConfirmed
                          ? AppColors.success.withValues(alpha: 0.25)
                          : AppColors.primary.withValues(alpha: 0.20),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isConfirmed
                        ? Icons.check_circle_outline
                        : Icons.calendar_month_outlined,
                    size: 16,
                    color: isConfirmed ? AppColors.success : AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        snapshot.courtName.isNotEmpty
                            ? '${snapshot.courtName} · ${snapshot.timeRange}'
                            : snapshot.timeRange,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Rs ${snapshot.totalAmount.toStringAsFixed(0)} total'
                        ' · Rs ${snapshot.depositAmount.toStringAsFixed(0)} deposit',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    snapshot.statusLabel,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
                if (onSwitch != null) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: onSwitch,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$bookingCount',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          const Icon(
                            Icons.arrow_drop_down,
                            size: 14,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
            if (onApprove != null || onReject != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: onReject,
                      child: Container(
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.45),
                          ),
                        ),
                        child: const Text(
                          'Reject',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: onApprove,
                      child: Container(
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Approve',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Support context mode selector — General / Ticket / Booking chips.
// ─────────────────────────────────────────────────────────────────────────────

class _SupportContextBar extends StatelessWidget {
  final ChatController controller;
  const _SupportContextBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final mode = controller.supportContextMode.value;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.attach_file,
              size: 14,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              'Context:',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            _contextChip(
              'General',
              Icons.chat_bubble_outline,
              mode == SupportContextMode.general,
              () => controller.setSupportContext(SupportContextMode.general),
            ),
            const SizedBox(width: 6),
            _contextChip(
              'Ticket',
              Icons.confirmation_number_outlined,
              mode == SupportContextMode.ticket,
              () => _showTicketPicker(context),
            ),
            const SizedBox(width: 6),
            _contextChip(
              'Booking',
              Icons.sports_soccer_outlined,
              mode == SupportContextMode.booking,
              () => _showBookingPicker(context),
            ),
          ],
        ),
      );
    });
  }

  Widget _contextChip(
    String label,
    IconData icon,
    bool selected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTicketPicker(BuildContext context) {
    final tickets = controller.userTickets.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.85,
        minChildSize: 0.3,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.confirmation_number_outlined,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Select a Ticket',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      Get.back();
                      _showCreateTicket(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.add,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'New',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: tickets.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.confirmation_number_outlined,
                            size: 48,
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.4,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No tickets yet',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () {
                              Get.back();
                              _showCreateTicket(context);
                            },
                            child: Text(
                              'Create your first ticket',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                      itemCount: tickets.length,
                      itemBuilder: (_, i) {
                        final t = tickets[i];
                        final isSelected =
                            controller.selectedTicket.value?.id == t.id;
                        return _TicketPickerItem(
                          ticket: t,
                          isSelected: isSelected,
                          onTap: () {
                            controller.selectTicket(t);
                            Get.back();
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBookingPicker(BuildContext context) {
    final bookings = controller.userBookings.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.85,
        minChildSize: 0.3,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.sports_soccer_outlined,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Select a Booking',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: bookings.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.sports_soccer_outlined,
                            size: 48,
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.4,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No bookings yet',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                      itemCount: bookings.length,
                      itemBuilder: (_, i) {
                        final b = bookings[i];
                        final isSelected =
                            controller.selectedSupportBooking.value?.id == b.id;
                        return _BookingPickerItem(
                          booking: b,
                          isSelected: isSelected,
                          onTap: () {
                            controller.selectSupportBooking(b);
                            Get.back();
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateTicket(BuildContext context) {
    final subjectCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String category = kTicketCategories.first;
    final submitting = false.obs;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: StatefulBuilder(
          builder: (ctx, setSheet) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Create New Ticket',
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: subjectCtrl,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Subject',
                  hintStyle: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textGrey,
                  ),
                  filled: true,
                  fillColor: AppColors.background,
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
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: category,
                    dropdownColor: AppColors.surface,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    isExpanded: true,
                    items: kTicketCategories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setSheet(() => category = v!),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                maxLines: 3,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Describe your issue…',
                  hintStyle: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textGrey,
                  ),
                  filled: true,
                  fillColor: AppColors.background,
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
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Obx(
                () => SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: submitting.value
                        ? null
                        : () async {
                            final subject = subjectCtrl.text.trim();
                            final desc = descCtrl.text.trim();
                            if (subject.isEmpty || desc.isEmpty) {
                              Get.snackbar(
                                'Required',
                                'Subject and description are required.',
                                snackPosition: SnackPosition.BOTTOM,
                              );
                              return;
                            }
                            submitting.value = true;
                            try {
                              final ticketId = await controller
                                  .createTicketFromChat(
                                    subject: subject,
                                    description: desc,
                                    category: category,
                                  );
                              Get.back();
                              await Future.delayed(
                                const Duration(milliseconds: 300),
                              );
                              final ticket = controller.userTickets
                                  .firstWhereOrNull((t) => t.id == ticketId);
                              if (ticket != null)
                                controller.selectTicket(ticket);
                              Get.snackbar(
                                'Ticket Created',
                                subject,
                                backgroundColor: AppColors.primary,
                                colorText: AppColors.onPrimary,
                                snackPosition: SnackPosition.BOTTOM,
                              );
                            } catch (e) {
                              Get.snackbar(
                                'Error',
                                e.toString(),
                                backgroundColor: AppColors.error,
                                colorText: Colors.white,
                                snackPosition: SnackPosition.BOTTOM,
                              );
                            } finally {
                              submitting.value = false;
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: submitting.value
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.onPrimary,
                            ),
                          )
                        : const Text(
                            'Create Ticket',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Support context banner — shows the selected ticket or booking info.
// ─────────────────────────────────────────────────────────────────────────────

class _SupportContextBanner extends StatelessWidget {
  final ChatController controller;
  const _SupportContextBanner({required this.controller});

  @override
  Widget build(BuildContext context) {
    final mode = controller.supportContextMode.value;

    if (mode == SupportContextMode.ticket) {
      final t = controller.selectedTicket.value;
      if (t == null) return const SizedBox.shrink();
      return _ticketBanner(t);
    }

    if (mode == SupportContextMode.booking) {
      final b = controller.selectedSupportBooking.value;
      if (b == null) return const SizedBox.shrink();
      return _bookingBanner(b);
    }

    return const SizedBox.shrink();
  }

  Widget _ticketBanner(TicketModel t) {
    final statusColor = _ticketStatusColor(t.status);
    return GestureDetector(
      onTap: () => _showTicketDetail(t),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.secondary.withValues(alpha: 0.04),
          border: const Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.secondary.withValues(alpha: 0.25),
                ),
              ),
              child: const Icon(
                Icons.confirmation_number_outlined,
                size: 16,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    t.ticketNumber.isNotEmpty
                        ? t.ticketNumber
                        : '#${t.id.substring(0, 6)}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondary,
                    ),
                  ),
                  Text(
                    t.subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                t.status.label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => controller.clearSupportContext(),
              child: const Icon(
                Icons.close,
                size: 16,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bookingBanner(BookingModel b) {
    final statusColor = _bStatusColor(b.status.key);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.04),
        border: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.20),
              ),
            ),
            child: const Icon(
              Icons.sports_soccer_outlined,
              size: 16,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${b.courtName} · ${b.timeRange}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${b.arenaName} · ${ChatController.dateLabelFor(b.date)}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              b.status.label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => controller.clearSupportContext(),
            child: const Icon(
              Icons.close,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _showTicketDetail(TicketModel t) {
    final statusColor = _ticketStatusColor(t.status);
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.confirmation_number_outlined,
                  color: AppColors.secondary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    t.subject,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    t.status.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 12),
            _detailRow(
              'Ticket',
              t.ticketNumber.isNotEmpty
                  ? t.ticketNumber
                  : '#${t.id.substring(0, 8)}',
            ),
            _detailRow('Category', t.category),
            _detailRow('Priority', t.priority.label),
            if (t.assignedTo != null) _detailRow('Assigned to', t.assignedTo!),
            _detailRow('Created', _fmtDate(t.createdAt)),
            if (t.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                t.description,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    ),
  );

  static String _fmtDate(DateTime d) {
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  static Color _ticketStatusColor(TicketStatus s) {
    switch (s) {
      case TicketStatus.open:
        return AppColors.primary;
      case TicketStatus.inProgress:
        return Colors.blue;
      case TicketStatus.waitingForCustomer:
        return AppColors.warning;
      case TicketStatus.resolved:
        return AppColors.success;
      case TicketStatus.closed:
        return AppColors.textSecondary;
    }
  }

  static Color _bStatusColor(String status) {
    switch (status) {
      case 'confirmed':
      case 'completed':
        return AppColors.success;
      case 'rejected':
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }
}

// ─── Picker items ────────────────────────────────────────────────────────────

class _TicketPickerItem extends StatelessWidget {
  final TicketModel ticket;
  final bool isSelected;
  final VoidCallback onTap;

  const _TicketPickerItem({
    required this.ticket,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _SupportContextBanner._ticketStatusColor(ticket.status);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.06)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.30)
                : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ticket.ticketNumber.isNotEmpty
                        ? ticket.ticketNumber
                        : '#${ticket.id.substring(0, 6)}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ticket.subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    ticket.category,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                ticket.status.label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              const Icon(
                Icons.check_circle,
                size: 16,
                color: AppColors.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BookingPickerItem extends StatelessWidget {
  final BookingModel booking;
  final bool isSelected;
  final VoidCallback onTap;

  const _BookingPickerItem({
    required this.booking,
    required this.isSelected,
    required this.onTap,
  });

  static Color _statusColor(String key) {
    switch (key) {
      case 'confirmed':
      case 'completed':
        return AppColors.success;
      case 'rejected':
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(booking.status.key);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.06)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.30)
                : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${booking.courtName} · ${ChatController.dateLabelFor(booking.date)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${booking.arenaName} · ${booking.timeRange}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                booking.status.label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              const Icon(
                Icons.check_circle,
                size: 16,
                color: AppColors.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
