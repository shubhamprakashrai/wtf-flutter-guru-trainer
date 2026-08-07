import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared/shared.dart';

import 'conversation_screen.dart';
import 'scheduler_screen.dart';
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
    final user = context.watch<AuthCubit>().state.user!;
    final trainer = services.auth.getUser(user.assignedTrainerId ?? SeedData.trainerId) ?? SeedData.trainer;
    final chatId = ChatMessage.chatIdFor(user.id, trainer.id);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Guru'),
            const SizedBox(width: 8),
            RoleBadge(label: 'Member • ${user.name}', color: const Color(0xFF1769E0)),
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
                Text('Welcome back, ${user.name} 👋', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text('Assigned trainer: ${trainer.name}', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 20),
                HomeActionCard(
                  icon: Icons.chat_bubble_outline,
                  title: 'Chat with Trainer',
                  subtitle: 'Message ${trainer.name}',
                  color: const Color(0xFF1769E0),
                  badgeCount: services.chat.unreadCount(chatId, user.id),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ConversationScreen(otherUser: trainer),
                  )).then((_) => setState(() {})),
                ),
                const SizedBox(height: 12),
                HomeActionCard(
                  icon: Icons.calendar_month_outlined,
                  title: 'Schedule Call',
                  subtitle: 'Book a session with ${trainer.name}',
                  color: const Color(0xFF12B76A),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SchedulerScreen())),
                ),
                const SizedBox(height: 12),
                HomeActionCard(
                  icon: Icons.history,
                  title: 'My Sessions',
                  subtitle: 'Past call logs & ratings',
                  color: const Color(0xFFF79009),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SessionLogsScreen())),
                ),
              ],
            ),
          ),
          DevPanelButton(
            appLabel: 'Guru',
            buildInfo: {
              'user': user.name,
              'trainer': trainer.name,
              'sync': SyncClient.instance.isConnected ? 'connected' : 'offline',
            },
          ),
        ],
      ),
    );
  }
}
