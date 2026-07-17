import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/admin_chat_controller.dart';
import '../../data/models/chat_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Live transcript of a monitored conversation with an admin reply bar.
class AdminChatViewScreen extends StatefulWidget {
  const AdminChatViewScreen({super.key});

  @override
  State<AdminChatViewScreen> createState() => _AdminChatViewScreenState();
}

class _AdminChatViewScreenState extends State<AdminChatViewScreen> {
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
    await AdminChatController.to.sendReply(chatId, text);
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

  @override
  Widget build(BuildContext context) {
    final c = AdminChatController.to;
    final mChat = c.byId(chatId);

    if (mChat == null) {
      return const Scaffold(body: Center(child: Text('Chat not found')));
    }
    final chat = mChat.chat;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(chat.title, style: AppTextStyles.titleMedium),
            Text(chat.subtitle,
                style:
                    AppTextStyles.bodySmall.copyWith(color: AppColors.textGrey)),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.primary.withValues(alpha: 0.10),
            child: Row(
              children: [
                const Icon(Icons.admin_panel_settings_outlined,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('Admin view — replying joins the conversation',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.primary)),
              ],
            ),
          ),
          Expanded(
            child: Obx(() {
              final msgs = c.messagesFor(chatId);
              if (msgs.isEmpty) {
                return const Center(
                  child: Text('No messages yet',
                      style: TextStyle(color: AppColors.textGrey)),
                );
              }
              _scrollToBottom();
              return ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(16),
                itemCount: msgs.length,
                itemBuilder: (_, i) => _bubble(msgs[i], c.myUid),
              );
            }),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textCtrl,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Reply as admin…',
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _send,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                      ),
                      child:
                          const Icon(Icons.send, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(MessageModel msg, String myUid) {
    final mine = msg.senderId == myUid;
    final roleColor = msg.senderRole == 'admin'
        ? AppColors.warning
        : msg.senderRole == 'owner'
            ? AppColors.primary
            : AppColors.accent;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: mine
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.darkCard,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(msg.senderRole,
                style: AppTextStyles.bodySmall
                    .copyWith(color: roleColor, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              msg.type == MessageType.text
                  ? msg.content
                  : (msg.type == MessageType.image
                      ? '📷 Photo'
                      : '📎 ${msg.fileName ?? 'Document'}'),
              style: AppTextStyles.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
