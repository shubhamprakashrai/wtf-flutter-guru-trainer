/// LiveKit doesn't have 100ms-style named per-participant roles baked into
/// the room itself - permissions (publish/subscribe) are granted per token
/// instead (see token_server/server.js), so this only needs to remember
/// which LiveKit room a given CallRequest maps to.
class RoomMeta {
  final String id;
  final String callRequestId;
  final String roomId;

  const RoomMeta({
    required this.id,
    required this.callRequestId,
    required this.roomId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'callRequestId': callRequestId,
        'roomId': roomId,
      };

  factory RoomMeta.fromJson(Map<String, dynamic> json) => RoomMeta(
        id: json['id'] as String,
        callRequestId: json['callRequestId'] as String,
        roomId: json['roomId'] as String? ?? json['hmsRoomId'] as String,
      );
}
