import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared/shared.dart';

import 'chat_list_screen.dart';
import 'members_screen.dart';
import 'requests_screen.dart';
import 'session_logs_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();
    final me = context.watch<AuthCubit>().state.user!;
    final pendingCount = services.call.requestsFor(trainerId: me.id).where((r) => r.status == CallRequestStatus.pending).length;
    final unreadTotal = services.chat
        .lastMessageByChat(me.id)
        .keys
        .fold<int>(0, (sum, chatId) => sum + services.chat.unreadCount(chatId, me.id));

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Trainer'),
            const SizedBox(width: 8),
            RoleBadge(label: 'Trainer • ${me.name}', color: const Color(0xFFE50914)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Toggle theme',
            icon: Icon(Theme.of(context).brightness == Brightness.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            onPressed: () => context.read<ThemeCubit>().toggle(),
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Welcome back, ${me.name} 👋', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text('Manage your members, chats and calls.', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 20),
                HomeActionCard(
                  icon: Icons.people_outline,
                  title: 'Members',
                  subtitle: 'Your assigned members',
                  color: const Color(0xFFE50914),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MembersScreen())),
                ),
                const SizedBox(height: 12),
                HomeActionCard(
                  icon: Icons.chat_bubble_outline,
                  title: 'Chats',
                  subtitle: 'Conversations with members',
                  color: const Color(0xFF1769E0),
                  badgeCount: unreadTotal,
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const ChatListScreen()))
                      .then((_) => setState(() {})),
                ),
                const SizedBox(height: 12),
                HomeActionCard(
                  icon: Icons.pending_actions_outlined,
                  title: 'Requests',
                  subtitle: 'Pending call requests',
                  color: const Color(0xFFF79009),
                  badgeCount: pendingCount,
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const RequestsScreen()))
                      .then((_) => setState(() {})),
                ),
                const SizedBox(height: 12),
                HomeActionCard(
                  icon: Icons.history,
                  title: 'Sessions',
                  subtitle: 'Completed session logs',
                  color: const Color(0xFF12B76A),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SessionLogsScreen())),
                ),
              ],
            ),
          ),
          DevPanelButton(
            appLabel: 'Trainer',
            buildInfo: {
              'user': me.name,
              'sync': SyncClient.instance.isConnected ? 'connected' : 'offline',
            },
          ),
        ],
      ),
    );
  }
}
