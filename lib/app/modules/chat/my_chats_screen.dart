import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/chat_controller.dart';
import '../../data/models/chat_model.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

const _bg = AppColors.background;
const _surface = AppColors.surface;
const _surfaceLow = AppColors.elevated;
const _outline = AppColors.border;
const _greenFixed = AppColors.success;
const _onSurface = AppColors.textPrimary;
const _onSurfaceVar = AppColors.textSecondary;

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
      // The dashboard shells use extendBody with a floating glass nav pill,
      // so the FAB needs extra lift to clear it.
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 84),
        child: FloatingActionButton.extended(
          heroTag: 'my_chats_fab',
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          icon: const Icon(Icons.support_agent),
          label: Text('Contact Support',
              style: AppTextStyles.label.copyWith(color: AppColors.onPrimary)),
          onPressed: () async {
            final chatId = await c.getOrCreateSupportChat();
            Get.toNamed(AppRoutes.chatRoom, arguments: chatId);
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Chats',
                  style: AppTextStyles.headlineLarge.copyWith(
                    color: _onSurface,
                    fontSize: 26,
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
                indicatorColor: AppColors.primary,
                indicatorWeight: 2,
                labelColor: AppColors.primary,
                unselectedLabelColor: _onSurfaceVar,
                labelStyle: AppTextStyles.label.copyWith(fontSize: 14),
                unselectedLabelStyle: AppTextStyles.label.copyWith(
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
            Text('No chats yet',
                style: AppTextStyles.titleMedium.copyWith(
                    color: _onSurface, fontSize: 16)),
            const SizedBox(height: 6),
            Text('Conversations appear here',
                style: AppTextStyles.bodySmall.copyWith(
                    color: _onSurfaceVar, fontSize: 13)),
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

class _BookingStatusChip extends StatelessWidget {
  final String status;
  final String label;

  const _BookingStatusChip({required this.status, required this.label});

  Color get _color {
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
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: _color,
          ),
        ),
      );
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
                color: unread ? AppColors.primary.withValues(alpha: 0.35) : _outline,
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
                        color: AppColors.primary,
                      ),
                    ),
                    if (unread)
                      Positioned(
                        top: -6,
                        right: -6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                          constraints:
                              const BoxConstraints(minWidth: 18, minHeight: 18),
                          child: Text(
                            '${chat.unreadCount}',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.white,
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
                              style: AppTextStyles.titleMedium.copyWith(
                                color: _onSurface,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            timeAgo(chat.lastMessageAt),
                            style: AppTextStyles.caption.copyWith(
                                color: _onSurfaceVar, fontSize: 12),
                          ),
                        ],
                      ),
                      if (chat.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          chat.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySmall.copyWith(
                              color: _onSurfaceVar, fontSize: 13),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (chat.type == ChatType.booking &&
                              chat.bookingSnapshot != null) ...[
                            _BookingStatusChip(
                                status: chat.bookingSnapshot!.status,
                                label: chat.bookingSnapshot!.statusLabel),
                            const SizedBox(width: 6),
                          ] else if (_messageIcon != null) ...[
                            Icon(_messageIcon, size: 15, color: _messageColor),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              chat.lastMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodySmall.copyWith(
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
