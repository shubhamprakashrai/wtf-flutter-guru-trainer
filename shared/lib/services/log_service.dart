import 'dart:async';

import 'package:hive/hive.dart';

import '../models/session_log.dart';
import '../utils/app_logger.dart';
import 'storage_service.dart';
import 'sync_client.dart';

class LogService {
  Box get _box => StorageService.box(StorageService.sessionLogsBox);
  StreamSubscription? _sub;
  final _updates = StreamController<SessionLog>.broadcast();

  Stream<SessionLog> get updates => _updates.stream;

  void listen() {
    _sub ??= SyncClient.instance.events.listen((event) {
      if (event['type'] == 'session_log') {
        final log = SessionLog.fromJson(Map<String, dynamic>.from(event['payload'] as Map));
        applyIncoming(log);
        _updates.add(log);
      }
    });
  }

  void dispose() => _sub?.cancel();

  List<SessionLog> logsFor({String? memberId, String? trainerId}) {
    return _box.values
        .map((v) => SessionLog.fromJson(Map<String, dynamic>.from(v as Map)))
        .where((l) => (memberId == null || l.memberId == memberId) && (trainerId == null || l.trainerId == trainerId))
        .toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  }

  /// [id] should be deterministic (e.g. the RoomMeta/CallRequest id) so both
  /// the member's and trainer's app - which each start a "session" locally
  /// the moment they join the call - end up writing the *same* SessionLog
  /// row instead of two independent ones. See ARCHITECTURE.md.
  Future<SessionLog> startSession({required String id, required String memberId, required String trainerId}) async {
    final existing = _box.get(id);
    if (existing != null) {
      return SessionLog.fromJson(Map<String, dynamic>.from(existing as Map));
    }
    final log = SessionLog(id: id, memberId: memberId, trainerId: trainerId, startedAt: DateTime.now());
    await _box.put(log.id, log.toJson());
    AppLogger.instance.log(LogTag.rtc, 'session started ${log.id}');
    return log;
  }

  Future<SessionLog> endSession(String id, {int fallbackDurationSec = 0}) async {
    final json = _box.get(id);
    if (json == null) throw StateError('SessionLog $id not found');
    final log = SessionLog.fromJson(Map<String, dynamic>.from(json as Map));
    final endedAt = DateTime.now();
    final duration = SessionLog.computeDurationSec(log.startedAt, endedAt, fallback: fallbackDurationSec);
    final updated = log.copyWith(endedAt: endedAt, durationSec: duration);
    await _box.put(id, updated.toJson());
    SyncClient.instance.send({'type': 'session_log', 'payload': updated.toJson()});
    _updates.add(updated);
    AppLogger.instance.log(LogTag.rtc, 'session ended ${log.id}, ${duration}s');
    return updated;
  }

  Future<void> addMemberFeedback(String id, {required int rating, String? note}) async {
    final json = _box.get(id);
    if (json == null) return;
    final log = SessionLog.fromJson(Map<String, dynamic>.from(json as Map));
    final updated = log.copyWith(rating: rating, memberNotes: note);
    await _box.put(id, updated.toJson());
    SyncClient.instance.send({'type': 'session_log', 'payload': updated.toJson()});
    _updates.add(updated);
  }

  Future<void> addTrainerNotes(String id, {required String notes}) async {
    final json = _box.get(id);
    if (json == null) return;
    final log = SessionLog.fromJson(Map<String, dynamic>.from(json as Map));
    final updated = log.copyWith(trainerNotes: notes);
    await _box.put(id, updated.toJson());
    SyncClient.instance.send({'type': 'session_log', 'payload': updated.toJson()});
    _updates.add(updated);
  }

  void applyIncoming(SessionLog log) {
    _box.put(log.id, log.toJson());
  }
}
