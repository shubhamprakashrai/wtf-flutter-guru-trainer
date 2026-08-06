import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

void main() {
  group('ChatMessage serialization', () {
    test('toJson/fromJson round-trip preserves all fields', () {
      final original = ChatMessage(
        id: 'msg_1',
        chatId: ChatMessage.chatIdFor('member_dk', 'trainer_aarav'),
        senderId: 'member_dk',
        receiverId: 'trainer_aarav',
        text: 'Hi Coach 👋',
        createdAt: DateTime(2026, 8, 6, 18, 30),
        status: MessageStatus.read,
        isSystem: false,
      );

      final restored = ChatMessage.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.chatId, original.chatId);
      expect(restored.senderId, original.senderId);
      expect(restored.receiverId, original.receiverId);
      expect(restored.text, original.text);
      expect(restored.createdAt, original.createdAt);
      expect(restored.status, MessageStatus.read);
      expect(restored.isSystem, false);
    });

    test('fromJson defaults isSystem to false when absent', () {
      final json = {
        'id': 'msg_2',
        'chatId': 'a_b',
        'senderId': 'a',
        'receiverId': 'b',
        'text': 'hello',
        'createdAt': DateTime(2026, 1, 1).millisecondsSinceEpoch,
        'status': 'sent',
      };

      final restored = ChatMessage.fromJson(json);
      expect(restored.isSystem, false);
    });

    test('chatIdFor is order-independent so both participants land in the same chat', () {
      final idAB = ChatMessage.chatIdFor('member_dk', 'trainer_aarav');
      final idBA = ChatMessage.chatIdFor('trainer_aarav', 'member_dk');
      expect(idAB, idBA);
    });

    test('copyWith(status) only changes status, not other fields', () {
      final msg = ChatMessage(
        id: 'msg_3',
        chatId: 'a_b',
        senderId: 'a',
        receiverId: 'b',
        text: 'test',
        createdAt: DateTime(2026, 1, 1),
        status: MessageStatus.sent,
      );
      final read = msg.copyWith(status: MessageStatus.read);
      expect(read.status, MessageStatus.read);
      expect(read.text, msg.text);
      expect(read.id, msg.id);
    });
  });
}
