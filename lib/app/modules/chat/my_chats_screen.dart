import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/chat_controller.dart';
import '../../data/models/chat_model.dart';
import '../../routes/app_routes.dart';

const _bg = Color(0xFF10131A);
const _surface = Color(0xFF1D2026);
const _surfaceLow = Color(0xFF191C22);
const _outline = Color(0xFF3B494B);
const _cyan = Color(0xFF00DBE9);
const _greenFixed = Color(0xFF79FF5B);
const _onSurface = Color(0xFFE1E2EB);
const _onSurfaceVar = Color(0xFFB9CACB);

/// Chats tab — Booking chats | Support. Shared by customer and owner.
class MyChatsScreen extends StatefulWidget {
  const MyChatsScreen({super.key});

  @override
  State<MyChatsScreen> createState() => _MyChatsScreenState();
}

class _MyChatsScreenState extends State<MyChatsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<ChatController>()) {
      Get.put(ChatController(), permanent: true);
    }
    final c = ChatController.to;

    return Scaffold(
      backgroundColor: _bg,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _cyan,
        foregroundColor: const Color(0xFF00232A),
        icon: const Icon(Icons.support_agent),
        label: const Text('Contact Support',
            style: TextStyle(fontWeight: FontWeight.w700)),
        onPressed: () async {
          final chatId = await c.getOrCreateSupportChat();
          Get.toNamed(AppRoutes.chatRoom, arguments: chatId);
        },
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Chats',
                  style: TextStyle(
                    color: _onSurface,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: _outline, width: 1)),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: _cyan,
                indicatorWeight: 2,
                labelColor: _cyan,
                unselectedLabelColor: _onSurfaceVar,
                labelStyle: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700),
                unselectedLabelStyle: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(text: 'Booking Chats'),
                  Tab(text: 'Support'),
                ],
              ),
            ),
            Expanded(
              child: Obx(() {
                c.chats.length;
                return TabBarView(
                  controller: _tabController,
                  children: [
                    _ChatList(chats: c.bookingChats),
                    _ChatList(chats: c.supportChats),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatList extends StatelessWidget {
  final List<ChatModel> chats;

  const _ChatList({required this.chats});

  static String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    if (chats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _surface,
                shape: BoxShape.circle,
                border: Border.all(color: _outline),
              ),
              child: const Icon(Icons.chat_bubble_outline,
                  size: 28, color: _onSurfaceVar),
            ),
            const SizedBox(height: 16),
            const Text('No chats yet',
                style: TextStyle(
                    color: _onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text('Conversations appear here',
                style: TextStyle(color: _onSurfaceVar, fontSize: 13)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: chats.length,
      itemBuilder: (_, i) => _ChatCard(chat: chats[i], timeAgo: _timeAgo),
    );
  }
}

class _ChatCard extends StatelessWidget {
  final ChatModel chat;
  final String Function(DateTime) timeAgo;

  const _ChatCard({required this.chat, required this.timeAgo});

  bool get _isConfirmed =>
      chat.lastMessage.toLowerCase().contains('confirmed');

  bool get _isDocument =>
      chat.lastMessage.toLowerCase().contains('booking details');

  IconData? get _messageIcon {
    if (_isConfirmed) return Icons.check_circle;
    if (_isDocument) return Icons.description_outlined;
    return null;
  }

  Color get _messageColor {
    if (_isConfirmed) return _greenFixed;
    if (chat.unreadCount > 0) return _onSurface;
    return _onSurfaceVar;
  }

  @override
  Widget build(BuildContext context) {
    final unread = chat.unreadCount > 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            await ChatController.to.openChat(chat.id);
            Get.toNamed(AppRoutes.chatRoom, arguments: chat.id);
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _surfaceLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: unread ? _cyan.withValues(alpha: 0.35) : _outline,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _outline),
                      ),
                      child: Icon(
                        chat.type == ChatType.booking
                            ? Icons.stadium_outlined
                            : Icons.support_agent,
                        color: _cyan,
                      ),
                    ),
                    if (unread)
                      Positioned(
                        top: -6,
                        right: -6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: _cyan,
                            shape: BoxShape.circle,
                          ),
                          constraints:
                              const BoxConstraints(minWidth: 18, minHeight: 18),
                          child: Text(
                            '${chat.unreadCount}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF00232A),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              chat.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _onSurface,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            timeAgo(chat.lastMessageAt),
                            style:
                                const TextStyle(color: _onSurfaceVar, fontSize: 12),
                          ),
                        ],
                      ),
                      if (chat.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          chat.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              const TextStyle(color: _onSurfaceVar, fontSize: 13),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (_messageIcon != null) ...[
                            Icon(_messageIcon, size: 15, color: _messageColor),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              chat.lastMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _messageColor,
                                fontSize: 13,
                                fontWeight:
                                    unread ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
