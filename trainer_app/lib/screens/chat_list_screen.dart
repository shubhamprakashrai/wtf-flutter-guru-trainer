import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared/shared.dart';

import 'conversation_screen.dart';
import 'members_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();
    final me = context.read<AuthCubit>().state.user!;
    final members = services.auth.membersOf(me.id);
    final lastMessages = services.chat.lastMessageByChat(me.id);

    final rows = members.map((member) {
      final chatId = ChatMessage.chatIdFor(me.id, member.id);
      return (member: member, chatId: chatId, last: lastMessages[chatId]);
    }).toList()
      ..sort((a, b) {
        if (a.last == null && b.last == null) return 0;
        if (a.last == null) return 1;
        if (b.last == null) return -1;
        return b.last!.createdAt.compareTo(a.last!.createdAt);
      });

    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFE50914),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MembersScreen())),
        child: const Icon(Icons.add_comment_outlined, color: Colors.white),
      ),
      body: rows.isEmpty
          ? EmptyState(
              icon: Icons.chat_bubble_outline,
              title: 'No messages yet.',
              message: 'Start the conversation.',
              ctaLabel: 'Say hi',
              onCta: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MembersScreen())),
            )
          : RefreshIndicator(
              onRefresh: () async => setState(() {}),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: rows.length,
                separatorBuilder: (context, i) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final row = rows[i];
                  final unread = services.chat.unreadCount(row.chatId, me.id);
                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => ConversationScreen(otherUser: row.member)))
                        .then((_) => setState(() {})),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE4E7EC)),
                      ),
                      child: Row(
                        children: [
                          UserAvatar(url: row.member.avatarUrl, fallbackInitial: row.member.name[0]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(row.member.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(
                                  row.last?.text ?? 'No messages yet',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF667085)),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (row.last != null)
                                Text(row.last!.createdAt.timeAgo, style: const TextStyle(fontSize: 11, color: Color(0xFF98A2B3))),
                              if (unread > 0) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: const BoxDecoration(color: Color(0xFFE50914), shape: BoxShape.circle),
                                  child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 11)),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
