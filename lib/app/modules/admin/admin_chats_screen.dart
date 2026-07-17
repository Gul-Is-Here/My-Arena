import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/admin_chat_controller.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';

/// Admin chat monitoring — all platform conversations, searchable
/// by user, arena, or booking. Live Firestore streams in backend phase.
class AdminChatsScreen extends StatelessWidget {
  const AdminChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<AdminChatController>()) {
      Get.put(AdminChatController(), permanent: true);
    }
    final c = AdminChatController.to;

    const pairs = {
      'all': 'All',
      'customer_owner': 'Customer ↔ Owner',
      'customer_staff': 'Customer ↔ Staff',
      'customer_admin': 'Customer ↔ Admin',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Chat Monitoring')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              onChanged: (v) => c.query.value = v,
              decoration: InputDecoration(
                hintText: 'Search by user, arena or booking…',
                prefixIcon: const Icon(Icons.search),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 52,
            child: Obx(
              () => ListView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: pairs.entries.map((e) {
                  final selected = c.pairFilter.value == e.key;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(e.value),
                      selected: selected,
                      selectedColor: AppColors.primary,
                      labelStyle: AppTextStyles.bodySmall.copyWith(
                        color: selected ? Colors.white : AppColors.textGrey,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (_) => c.pairFilter.value = e.key,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: Obx(() {
              final items = c.filtered;
              if (items.isEmpty) {
                return Center(
                  child: Text('No conversations found',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textGrey)),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final mChat = items[i];
                  final chat = mChat.chat;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppCard(
                      onTap: () => Get.toNamed(AppRoutes.adminChatView,
                          arguments: chat.id),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.forum_outlined,
                                    color: AppColors.primary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        '${mChat.partyA.split(' (').first} ↔ ${mChat.partyB.split(' (').first}',
                                        style: AppTextStyles.titleMedium),
                                    Text(
                                      '${chat.title} · ${chat.subtitle}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.textGrey),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(mChat.pairLabel,
                                    style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.accent,
                                        fontWeight: FontWeight.w600)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  chat.lastMessage,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.bodySmall
                                      .copyWith(color: AppColors.textGrey),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}
