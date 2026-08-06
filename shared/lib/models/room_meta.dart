class RoomMeta {
  final String id;
  final String callRequestId;
  final String hmsRoomId;
  final String hmsRoleMember;
  final String hmsRoleTrainer;

  const RoomMeta({
    required this.id,
    required this.callRequestId,
    required this.hmsRoomId,
    this.hmsRoleMember = 'member',
    this.hmsRoleTrainer = 'trainer',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'callRequestId': callRequestId,
        'hmsRoomId': hmsRoomId,
        'hmsRoleMember': hmsRoleMember,
        'hmsRoleTrainer': hmsRoleTrainer,
      };

  factory RoomMeta.fromJson(Map<String, dynamic> json) => RoomMeta(
        id: json['id'] as String,
        callRequestId: json['callRequestId'] as String,
        hmsRoomId: json['hmsRoomId'] as String,
        hmsRoleMember: json['hmsRoleMember'] as String? ?? 'member',
        hmsRoleTrainer: json['hmsRoleTrainer'] as String? ?? 'trainer',
      );
}
