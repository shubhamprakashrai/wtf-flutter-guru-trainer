class SessionLog {
  final String id;
  final String memberId;
  final String trainerId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int durationSec;
  final int? rating;
  final String? trainerNotes;
  final String? memberNotes;

  const SessionLog({
    required this.id,
    required this.memberId,
    required this.trainerId,
    required this.startedAt,
    this.endedAt,
    this.durationSec = 0,
    this.rating,
    this.trainerNotes,
    this.memberNotes,
  });

  /// Computes duration from start/end timestamps when available, else falls
  /// back to the stored [durationSec] (e.g. if the RTC SDK didn't report one).
  static int computeDurationSec(DateTime startedAt, DateTime? endedAt, {int fallback = 0}) {
    if (endedAt == null) return fallback;
    final diff = endedAt.difference(startedAt).inSeconds;
    return diff < 0 ? fallback : diff;
  }

  SessionLog copyWith({
    DateTime? endedAt,
    int? durationSec,
    int? rating,
    String? trainerNotes,
    String? memberNotes,
  }) =>
      SessionLog(
        id: id,
        memberId: memberId,
        trainerId: trainerId,
        startedAt: startedAt,
        endedAt: endedAt ?? this.endedAt,
        durationSec: durationSec ?? this.durationSec,
        rating: rating ?? this.rating,
        trainerNotes: trainerNotes ?? this.trainerNotes,
        memberNotes: memberNotes ?? this.memberNotes,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'memberId': memberId,
        'trainerId': trainerId,
        'startedAt': startedAt.millisecondsSinceEpoch,
        'endedAt': endedAt?.millisecondsSinceEpoch,
        'durationSec': durationSec,
        'rating': rating,
        'trainerNotes': trainerNotes,
        'memberNotes': memberNotes,
      };

  factory SessionLog.fromJson(Map<String, dynamic> json) => SessionLog(
        id: json['id'] as String,
        memberId: json['memberId'] as String,
        trainerId: json['trainerId'] as String,
        startedAt: DateTime.fromMillisecondsSinceEpoch(json['startedAt'] as int),
        endedAt: json['endedAt'] != null ? DateTime.fromMillisecondsSinceEpoch(json['endedAt'] as int) : null,
        durationSec: json['durationSec'] as int? ?? 0,
        rating: json['rating'] as int?,
        trainerNotes: json['trainerNotes'] as String?,
        memberNotes: json['memberNotes'] as String?,
      );
}
