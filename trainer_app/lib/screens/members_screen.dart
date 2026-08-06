import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared/shared.dart';

import 'conversation_screen.dart';

class MembersScreen extends StatelessWidget {
  const MembersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();
    final me = context.read<AuthCubit>().state.user!;
    final members = services.auth.membersOf(me.id);

    return Scaffold(
      appBar: AppBar(title: const Text('Members')),
      body: members.isEmpty
          ? const EmptyState(
              icon: Icons.people_outline,
              title: 'No members yet',
              message: 'Members will show up here once assigned to you.',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: members.length,
              separatorBuilder: (context, i) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final member = members[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => ConversationScreen(otherUser: member))),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE4E7EC)),
                    ),
                    child: Row(
                      children: [
                        UserAvatar(url: member.avatarUrl, fallbackInitial: member.name[0]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(member.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text(member.email, style: const TextStyle(fontSize: 12, color: Color(0xFF667085))),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Color(0xFF98A2B3)),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
