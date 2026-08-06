import 'dart:async';

import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_message.dart';
import '../utils/app_logger.dart';
import 'storage_service.dart';
import 'sync_client.dart';

const _uuid = Uuid();

/// Persists chat messages locally (Hive) and relays them to the other app
/// in real time over [SyncClient]. Each app instance also applies incoming
/// relay events to its own Hive box so history survives a restart even
/// without the relay running.
class ChatService {
  Box get _box => StorageService.box(StorageService.messagesBox);
  final _incoming = StreamController<ChatMessage>.broadcast();
  StreamSubscription? _sub;

  Stream<ChatMessage> get incoming => _incoming.stream;

  void listen() {
    _sub ??= SyncClient.instance.events.listen((event) {
      switch (event['type']) {
        case 'chat_message':
          final msg = ChatMessage.fromJson(Map<String, dynamic>.from(event['payload'] as Map));
          _persist(msg);
          _incoming.add(msg);
          AppLogger.instance.log(LogTag.chat, 'received "${msg.text}" from ${msg.senderId}');
          break;
        case 'chat_read':
          final chatId = event['chatId'] as String;
          final readerId = event['readerId'] as String;
          _markReadLocally(chatId, readerId);
          break;
      }
    });
  }

  List<ChatMessage> messagesFor(String chatId) {
    return _box.values
        .map((v) => ChatMessage.fromJson(Map<String, dynamic>.from(v as Map)))
        .where((m) => m.chatId == chatId)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  List<ChatMessage> allMessages() => _box.values
      .map((v) => ChatMessage.fromJson(Map<String, dynamic>.from(v as Map)))
      .toList();

  Future<ChatMessage> sendMessage({
    required String senderId,
    required String receiverId,
    required String text,
  }) async {
    final chatId = ChatMessage.chatIdFor(senderId, receiverId);
    final msg = ChatMessage(
      id: _uuid.v4(),
      chatId: chatId,
      senderId: senderId,
      receiverId: receiverId,
      text: text,
      createdAt: DateTime.now(),
      status: MessageStatus.sent,
    );
    await _persist(msg);
    SyncClient.instance.send({'type': 'chat_message', 'payload': msg.toJson()});
    AppLogger.instance.log(LogTag.chat, 'sent "$text" to $receiverId');
    return msg;
  }

  Future<void> sendSystemMessage({
    required String chatId,
    required String senderId,
    required String receiverId,
    required String text,
  }) async {
    final msg = ChatMessage(
      id: _uuid.v4(),
      chatId: chatId,
      senderId: senderId,
      receiverId: receiverId,
      text: text,
      createdAt: DateTime.now(),
      status: MessageStatus.sent,
      isSystem: true,
    );
    await _persist(msg);
    SyncClient.instance.send({'type': 'chat_message', 'payload': msg.toJson()});
  }

  Future<void> markRead(String chatId, String readerId) async {
    _markReadLocally(chatId, readerId);
    SyncClient.instance.send({'type': 'chat_read', 'chatId': chatId, 'readerId': readerId});
  }

  void _markReadLocally(String chatId, String readerId) {
    final keys = _box.keys.toList();
    for (final key in keys) {
      final json = Map<String, dynamic>.from(_box.get(key) as Map);
      final msg = ChatMessage.fromJson(json);
      if (msg.chatId == chatId && msg.receiverId == readerId && msg.status != MessageStatus.read) {
        _box.put(key, msg.copyWith(status: MessageStatus.read).toJson());
      }
    }
  }

  Future<void> _persist(ChatMessage msg) async {
    await _box.put(msg.id, msg.toJson());
  }

  /// Recent conversation summaries grouped by the other participant.
  Map<String, ChatMessage> lastMessageByChat(String currentUserId) {
    final result = <String, ChatMessage>{};
    for (final m in allMessages()) {
      if (m.senderId != currentUserId && m.receiverId != currentUserId) continue;
      final existing = result[m.chatId];
      if (existing == null || m.createdAt.isAfter(existing.createdAt)) {
        result[m.chatId] = m;
      }
    }
    return result;
  }

  int unreadCount(String chatId, String currentUserId) {
    return messagesFor(chatId)
        .where((m) => m.receiverId == currentUserId && m.status != MessageStatus.read)
        .length;
  }

  void dispose() {
    _sub?.cancel();
  }
}
