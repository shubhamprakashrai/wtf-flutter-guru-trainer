import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared/shared.dart';

import 'call/pre_join_screen.dart';

class ConversationScreen extends StatelessWidget {
  final AppUser otherUser;
  const ConversationScreen({super.key, required this.otherUser});

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();
    final me = context.read<AuthCubit>().state.user!;
    final chatId = ChatMessage.chatIdFor(me.id, otherUser.id);
    final isMemberSide = me.role == UserRole.member;

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => ChatCubit(chatService: services.chat, chatId: chatId, meId: me.id, otherId: otherUser.id),
        ),
        BlocProvider(
          create: (_) => CallCubit(
            callService: services.call,
            memberId: isMemberSide ? me.id : otherUser.id,
            trainerId: isMemberSide ? otherUser.id : me.id,
          ),
        ),
      ],
      child: _ConversationView(otherUser: otherUser, me: me),
    );
  }
}

class _ConversationView extends StatefulWidget {
  final AppUser otherUser;
  final AppUser me;
  const _ConversationView({required this.otherUser, required this.me});

  @override
  State<_ConversationView> createState() => _ConversationViewState();
}

class _ConversationViewState extends State<_ConversationView> {
  final _scrollController = ScrollController();
  int _lastCount = 0;

  static const _quickReplies = ['Got it 👍', 'Can we talk at 6?', 'Share plan?'];

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  CallRequest? _joinableRequest(List<CallRequest> requests) {
    final now = DateTime.now();
    CallRequest? joinable;
    for (final r in requests) {
      if (r.status != CallRequestStatus.approved) continue;
      if (now.isAfter(r.scheduledFor.subtract(const Duration(minutes: 10)))) {
        joinable = r;
      }
    }
    return joinable;
  }

  void _joinCall(CallRequest req) {
    final room = context.read<CallCubit>().roomFor(req.id);
    if (room == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PreJoinScreen(room: room, sessionMemberId: req.memberId, sessionTrainerId: req.trainerId),
    ));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ownColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            UserAvatar(url: widget.otherUser.avatarUrl, fallbackInitial: widget.otherUser.name[0], size: 34),
            const SizedBox(width: 10),
            Expanded(
              child: Text(widget.otherUser.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        actions: [
          BlocBuilder<CallCubit, CallUiState>(
            builder: (context, state) {
              final joinable = _joinableRequest(state.requests);
              if (joinable == null) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'Join Call',
                onPressed: () => _joinCall(joinable),
                icon: const Badge(
                  backgroundColor: Color(0xFF12B76A),
                  smallSize: 8,
                  child: Icon(Icons.videocam),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: BlocConsumer<ChatCubit, ChatUiState>(
              listener: (context, state) {
                final total = state.messages.length + (state.showTyping ? 1 : 0);
                if (total != _lastCount) {
                  _lastCount = total;
                  _scrollToBottom();
                }
              },
              builder: (context, state) {
                if (state.messages.isEmpty && !state.showTyping) {
                  return const EmptyState(
                    icon: Icons.chat_bubble_outline,
                    title: 'No messages yet.',
                    message: 'Start the conversation.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => Future.delayed(const Duration(milliseconds: 400)),
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: state.messages.length + (state.showTyping ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == state.messages.length) {
                        return const TypingIndicator();
                      }
                      final msg = state.messages[i];
                      return ChatBubble(message: msg, isMine: msg.senderId == widget.me.id, ownColor: ownColor);
                    },
                  ),
                );
              },
            ),
          ),
          MessageInputBar(onSend: (text) => context.read<ChatCubit>().send(text), quickReplies: _quickReplies),
        ],
      ),
    );
  }
}
