enum CallRequestStatus { pending, approved, declined, cancelled }

CallRequestStatus callRequestStatusFromString(String value) =>
    CallRequestStatus.values.firstWhere((e) => e.name == value, orElse: () => CallRequestStatus.pending);

class CallRequest {
  final String id;
  final String memberId;
  final String trainerId;
  final DateTime requestedAt;
  final DateTime scheduledFor;
  final String note;
  final CallRequestStatus status;
  final String? declineReason;

  const CallRequest({
    required this.id,
    required this.memberId,
    required this.trainerId,
    required this.requestedAt,
    required this.scheduledFor,
    required this.note,
    this.status = CallRequestStatus.pending,
    this.declineReason,
  });

  CallRequest copyWith({CallRequestStatus? status, String? declineReason}) => CallRequest(
        id: id,
        memberId: memberId,
        trainerId: trainerId,
        requestedAt: requestedAt,
        scheduledFor: scheduledFor,
        note: note,
        status: status ?? this.status,
        declineReason: declineReason ?? this.declineReason,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'memberId': memberId,
        'trainerId': trainerId,
        'requestedAt': requestedAt.millisecondsSinceEpoch,
        'scheduledFor': scheduledFor.millisecondsSinceEpoch,
        'note': note,
        'status': status.name,
        'declineReason': declineReason,
      };

  factory CallRequest.fromJson(Map<String, dynamic> json) => CallRequest(
        id: json['id'] as String,
        memberId: json['memberId'] as String,
        trainerId: json['trainerId'] as String,
        requestedAt: DateTime.fromMillisecondsSinceEpoch(json['requestedAt'] as int),
        scheduledFor: DateTime.fromMillisecondsSinceEpoch(json['scheduledFor'] as int),
        note: json['note'] as String,
        status: callRequestStatusFromString(json['status'] as String),
        declineReason: json['declineReason'] as String?,
      );

  /// Validation: cannot request a slot in the past.
  static String? validateScheduledFor(DateTime scheduledFor, DateTime now) {
    if (scheduledFor.isBefore(now)) {
      return 'Cannot pick a time in the past.';
    }
    return null;
  }
}
