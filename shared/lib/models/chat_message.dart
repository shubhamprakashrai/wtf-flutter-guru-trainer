enum MessageStatus { sending, sent, read }

MessageStatus messageStatusFromString(String value) => MessageStatus.values
    .firstWhere((e) => e.name == value, orElse: () => MessageStatus.sent);

class ChatMessage {
  final String id;
  final String chatId;
  final String senderId;
  final String receiverId;
  final String text;
  final DateTime createdAt;
  final MessageStatus status;
  final bool isSystem;

  const ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.createdAt,
    this.status = MessageStatus.sending,
    this.isSystem = false,
  });

  ChatMessage copyWith({MessageStatus? status}) => ChatMessage(
        id: id,
        chatId: chatId,
        senderId: senderId,
        receiverId: receiverId,
        text: text,
        createdAt: createdAt,
        status: status ?? this.status,
        isSystem: isSystem,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'chatId': chatId,
        'senderId': senderId,
        'receiverId': receiverId,
        'text': text,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'status': status.name,
        'isSystem': isSystem,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        chatId: json['chatId'] as String,
        senderId: json['senderId'] as String,
        receiverId: json['receiverId'] as String,
        text: json['text'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
        status: messageStatusFromString(json['status'] as String),
        isSystem: json['isSystem'] as bool? ?? false,
      );

  static String chatIdFor(String userA, String userB) {
    final ids = [userA, userB]..sort();
    return '${ids[0]}_${ids[1]}';
  }
}
