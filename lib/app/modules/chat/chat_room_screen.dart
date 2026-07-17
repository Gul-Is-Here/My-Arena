import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/chat_controller.dart';
import '../../data/models/chat_model.dart';

const _bg = Color(0xFF10131A);
const _surface = Color(0xFF1D2026);
const _surfaceLow = Color(0xFF191C22);
const _outline = Color(0xFF3B494B);
const _cyan = Color(0xFF00DBE9);
const _onSurface = Color(0xFFE1E2EB);
const _onSurfaceVar = Color(0xFFB9CACB);

const _months = [
  'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE', 'JULY',
  'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER',
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
              _attachOption(Icons.photo_outlined, 'Photo',
                  () => _attach(MessageType.image)),
              _attachOption(Icons.insert_drive_file_outlined, 'Document',
                  () => _attach(MessageType.document)),
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
              color: _cyan.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _cyan, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: _onSurface, fontSize: 13)),
        ],
      ),
    );
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
            Expanded(
              child: Obx(() {
                final msgs = c.messagesFor(chatId);
                if (msgs.isEmpty) {
                  return const Center(
                    child: Text('No messages yet. Say hello!',
                        style: TextStyle(color: _onSurfaceVar)),
                  );
                }
                _scrollToBottom();
                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  itemCount: msgs.length,
                  itemBuilder: (_, i) {
                    final msg = msgs[i];
                    final showDate = i == 0 ||
                        !_sameDay(msgs[i - 1].createdAt, msg.createdAt);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showDate) _dateDivider(msg.createdAt),
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
              style: const TextStyle(
                color: _onSurfaceVar,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
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
                  color: _cyan,
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
                      style: const TextStyle(
                        color: _cyan,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if ((chat?.subtitle ?? '').isNotEmpty)
                      Text(
                        chat!.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: _onSurfaceVar, fontSize: 12),
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
                  color: _surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _outline),
                ),
                child: const Icon(Icons.add, color: _cyan),
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
                  style: const TextStyle(color: _onSurface),
                  decoration: const InputDecoration(
                    hintText: 'Type a message…',
                    hintStyle: TextStyle(color: _onSurfaceVar),
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  color: _cyan,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _cyan.withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(Icons.send,
                    color: Color(0xFF00232A), size: 20),
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
          MapEntry(line.substring(0, idx).trim(), line.substring(idx + 1).trim()));
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
          color: _cyan.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _cyan.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: _cyan.withValues(alpha: 0.15),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              children: [
                Icon(Icons.assignment_outlined, color: _cyan, size: 18),
                SizedBox(width: 8),
                Text(
                  'Booking Details',
                  style: TextStyle(
                    color: _cyan,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
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
                            ? const TextStyle(
                                color: _cyan, fontWeight: FontWeight.w800)
                            : const TextStyle(
                                color: _onSurface, fontWeight: FontWeight.w600),
                      ),
                    ],
                    style: const TextStyle(
                        color: _onSurfaceVar, fontSize: 13, height: 1.4),
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(time,
                      style:
                          const TextStyle(fontSize: 10, color: _onSurfaceVar)),
                  if (mine) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.done_all,
                        size: 14,
                        color: msg.isRead ? _cyan : _onSurfaceVar),
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
        content = Text(
          msg.content,
          style: const TextStyle(color: _onSurface, fontSize: 14, height: 1.3),
        );
        break;
      case MessageType.image:
        content = ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: msg.content.startsWith('http')
              ? Image.network(msg.content,
                  width: 180,
                  height: 130,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, e, s) =>
                      const Icon(Icons.broken_image, color: _onSurfaceVar))
              : Container(
                  width: 180,
                  height: 130,
                  color: _outline.withValues(alpha: 0.3),
                  child: const Icon(Icons.image_outlined,
                      size: 42, color: _onSurfaceVar),
                ),
        );
        break;
      case MessageType.document:
        content = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insert_drive_file_outlined,
                size: 20, color: _cyan),
            const SizedBox(width: 8),
            Text(msg.fileName ?? 'Document',
                style: const TextStyle(color: _onSurface, fontSize: 14)),
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
          color: mine ? _cyan.withValues(alpha: 0.14) : _surfaceLow,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
          border: mine
              ? Border.all(color: _cyan.withValues(alpha: 0.4))
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
                    style: const TextStyle(
                        fontSize: 10, color: _onSurfaceVar),
                  ),
                Text(
                  time,
                  style: const TextStyle(fontSize: 10, color: _onSurfaceVar),
                ),
                if (mine) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.done_all,
                      size: 14, color: msg.isRead ? _cyan : _onSurfaceVar),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
