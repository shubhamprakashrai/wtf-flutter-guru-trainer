import 'dart:async';
import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/chat_message.dart';
import '../services/chat_service.dart';

class ChatUiState {
  final List<ChatMessage> messages;
  final bool showTyping;
  const ChatUiState({this.messages = const [], this.showTyping = false});

  ChatUiState copyWith({List<ChatMessage>? messages, bool? showTyping}) =>
      ChatUiState(messages: messages ?? this.messages, showTyping: showTyping ?? this.showTyping);
}

/// One instance per open conversation. Applies the "typing" delay described
/// in the spec: when a message arrives from the other participant, hold it
/// behind a simulated 400-800ms typing indicator before revealing it.
class ChatCubit extends Cubit<ChatUiState> {
  final ChatService chatService;
  final String chatId;
  final String meId;
  final String otherId;
  StreamSubscription? _sub;

  ChatCubit({required this.chatService, required this.chatId, required this.meId, required this.otherId})
      : super(const ChatUiState()) {
    _load();
    markRead();
    _sub = chatService.incoming.listen(_onIncoming);
  }

  void _load() => emit(state.copyWith(messages: chatService.messagesFor(chatId)));

  void markRead() {
    chatService.markRead(chatId, meId);
    _load();
  }

  Future<void> send(String text) async {
    await chatService.sendMessage(senderId: meId, receiverId: otherId, text: text);
    _load();
  }

  Future<void> _onIncoming(ChatMessage msg) async {
    if (msg.chatId != chatId || msg.senderId == meId) return;
    emit(state.copyWith(showTyping: true));
    final delayMs = 400 + Random().nextInt(400);
    await Future.delayed(Duration(milliseconds: delayMs));
    emit(state.copyWith(showTyping: false));
    _load();
    markRead();
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
