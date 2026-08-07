import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
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
///
/// Offline send queue (spec section 15 stretch): a message sent while the
/// relay is disconnected is written to Hive with [MessageStatus.sending]
/// instead of [MessageStatus.sent] and re-dispatched automatically the next
/// time [SyncClient] reconnects - see [_flushQueue].
class ChatService {
  Box get _box => StorageService.box(StorageService.messagesBox);
  final _incoming = StreamController<ChatMessage>.broadcast();
  final _localUpdates = StreamController<void>.broadcast();
  StreamSubscription? _sub;
  StreamSubscription? _connectionSub;

  Stream<ChatMessage> get incoming => _incoming.stream;

  /// Fires on any locally-caused change (queue flush, read receipt) that
  /// isn't already covered by [incoming] - lets a UI listener refresh
  /// without waiting for a new message to arrive.
  Stream<void> get localUpdates => _localUpdates.stream;

  void listen() {
    _sub ??= SyncClient.instance.events.listen((event) async {
      switch (event['type']) {
        case 'chat_message':
          var msg = ChatMessage.fromJson(Map<String, dynamic>.from(event['payload'] as Map));
          final attachmentBase64 = event['attachmentBase64'] as String?;
          if (attachmentBase64 != null) {
            // The sender's attachmentPath is meaningless on this device -
            // save our own local copy of the relayed bytes and use that.
            final localPath = await _saveAttachmentBytes(base64Decode(attachmentBase64), msg.id);
            msg = msg.copyWith(attachmentPath: localPath);
          }
          await _persist(msg);
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
    _connectionSub ??= SyncClient.instance.connectionChanges.listen((connected) {
      if (connected) _flushQueue();
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
    final online = SyncClient.instance.isConnected;
    final msg = ChatMessage(
      id: _uuid.v4(),
      chatId: chatId,
      senderId: senderId,
      receiverId: receiverId,
      text: text,
      createdAt: DateTime.now(),
      status: online ? MessageStatus.sent : MessageStatus.sending,
    );
    await _persist(msg);
    if (online) {
      SyncClient.instance.send({'type': 'chat_message', 'payload': msg.toJson()});
      AppLogger.instance.log(LogTag.chat, 'sent "$text" to $receiverId');
    } else {
      AppLogger.instance.log(LogTag.chat, 'queued "$text" (offline) for $receiverId');
    }
    return msg;
  }

  /// Attachments (spec section 15 stretch): saves a local copy of the
  /// picked image and relays the bytes (base64, downsized by the caller's
  /// image_picker options before this is called) to the other app, which
  /// saves its own local copy on receipt - see the [listen] handler.
  Future<ChatMessage> sendImageMessage({
    required String senderId,
    required String receiverId,
    required Uint8List imageBytes,
  }) async {
    final chatId = ChatMessage.chatIdFor(senderId, receiverId);
    final online = SyncClient.instance.isConnected;
    final id = _uuid.v4();
    final localPath = await _saveAttachmentBytes(imageBytes, id);
    final msg = ChatMessage(
      id: id,
      chatId: chatId,
      senderId: senderId,
      receiverId: receiverId,
      text: '📷 Photo',
      createdAt: DateTime.now(),
      status: online ? MessageStatus.sent : MessageStatus.sending,
      attachmentPath: localPath,
    );
    await _persist(msg);
    if (online) {
      SyncClient.instance.send({
        'type': 'chat_message',
        'payload': msg.toJson(),
        'attachmentBase64': base64Encode(imageBytes),
      });
      AppLogger.instance.log(LogTag.chat, 'sent photo to $receiverId');
    } else {
      AppLogger.instance.log(LogTag.chat, 'queued photo (offline) for $receiverId');
    }
    return msg;
  }

  Future<String> _saveAttachmentBytes(Uint8List bytes, String messageId) async {
    final dir = await getApplicationDocumentsDirectory();
    final attachmentsDir = Directory('${dir.path}/chat_attachments');
    if (!await attachmentsDir.exists()) {
      await attachmentsDir.create(recursive: true);
    }
    final file = File('${attachmentsDir.path}/$messageId.jpg');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  /// Re-dispatches every locally-queued (status == sending) message once
  /// the relay reconnects, in the order they were originally written.
  Future<void> _flushQueue() async {
    final pending = allMessages().where((m) => m.status == MessageStatus.sending).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (pending.isEmpty) return;
    AppLogger.instance.log(LogTag.chat, 'flushing ${pending.length} queued message(s)');
    for (final msg in pending) {
      final sent = msg.copyWith(status: MessageStatus.sent);
      await _persist(sent);
      String? attachmentBase64;
      if (sent.attachmentPath != null) {
        final file = File(sent.attachmentPath!);
        if (await file.exists()) {
          attachmentBase64 = base64Encode(await file.readAsBytes());
        }
      }
      SyncClient.instance.send({
        'type': 'chat_message',
        'payload': sent.toJson(),
        'attachmentBase64': ?attachmentBase64,
      });
    }
    _localUpdates.add(null);
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
    _connectionSub?.cancel();
  }
}
