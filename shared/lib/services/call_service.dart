import 'dart:async';
import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../models/call_request.dart';
import '../models/room_meta.dart';
import '../utils/app_logger.dart';
import 'call_config.dart';
import 'storage_service.dart';
import 'sync_client.dart';

const _uuid = Uuid();

class CallService {
  Box get _requests => StorageService.box(StorageService.callRequestsBox);
  Box get _rooms => StorageService.box(StorageService.roomMetaBox);
  final _updates = StreamController<CallRequest>.broadcast();
  StreamSubscription? _sub;

  Stream<CallRequest> get updates => _updates.stream;

  void listen() {
    _sub ??= SyncClient.instance.events.listen((event) {
      if (event['type'] == 'call_request') {
        final req = CallRequest.fromJson(Map<String, dynamic>.from(event['payload'] as Map));
        _requests.put(req.id, req.toJson());
        _updates.add(req);
        AppLogger.instance.log(LogTag.schedule, 'sync: request ${req.id} -> ${req.status.name}');
      }
      if (event['type'] == 'room_meta') {
        final room = RoomMeta.fromJson(Map<String, dynamic>.from(event['payload'] as Map));
        _rooms.put(room.id, room.toJson());
      }
    });
  }

  List<CallRequest> requestsFor({String? memberId, String? trainerId}) {
    return _requests.values
        .map((v) => CallRequest.fromJson(Map<String, dynamic>.from(v as Map)))
        .where((r) => (memberId == null || r.memberId == memberId) && (trainerId == null || r.trainerId == trainerId))
        .toList()
      ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
  }

  /// Returns an error string if [scheduledFor] conflicts with an existing
  /// approved slot for this trainer (within the same 30-min block), else null.
  String? conflictError(String trainerId, DateTime scheduledFor) {
    final now = DateTime.now();
    final pastError = CallRequest.validateScheduledFor(scheduledFor, now);
    if (pastError != null) return pastError;

    final approved = requestsFor(trainerId: trainerId).where((r) => r.status == CallRequestStatus.approved);
    for (final r in approved) {
      if (r.scheduledFor.difference(scheduledFor).abs() < const Duration(minutes: 30)) {
        return 'This slot is already booked. Pick another time.';
      }
    }
    return null;
  }

  Future<CallRequest> requestCall({
    required String memberId,
    required String trainerId,
    required DateTime scheduledFor,
    required String note,
  }) async {
    final req = CallRequest(
      id: _uuid.v4(),
      memberId: memberId,
      trainerId: trainerId,
      requestedAt: DateTime.now(),
      scheduledFor: scheduledFor,
      note: note,
    );
    await _requests.put(req.id, req.toJson());
    SyncClient.instance.send({'type': 'call_request', 'payload': req.toJson()});
    AppLogger.instance.log(LogTag.schedule, 'requested call for ${scheduledFor.toIso8601String()}');
    return req;
  }

  Future<RoomMeta> approve(CallRequest req) async {
    final updated = req.copyWith(status: CallRequestStatus.approved);
    await _requests.put(updated.id, updated.toJson());
    SyncClient.instance.send({'type': 'call_request', 'payload': updated.toJson()});

    final room = RoomMeta(
      id: _uuid.v4(),
      callRequestId: req.id,
      roomId: CallConfig.devRoomId,
    );
    await _rooms.put(room.id, room.toJson());
    SyncClient.instance.send({'type': 'room_meta', 'payload': room.toJson()});
    AppLogger.instance.log(LogTag.schedule, 'approved ${req.id}, room ${room.roomId}');
    return room;
  }

  Future<CallRequest> decline(CallRequest req, String reason) async {
    final updated = req.copyWith(status: CallRequestStatus.declined, declineReason: reason);
    await _requests.put(updated.id, updated.toJson());
    SyncClient.instance.send({'type': 'call_request', 'payload': updated.toJson()});
    AppLogger.instance.log(LogTag.schedule, 'declined ${req.id}: $reason');
    return updated;
  }

  RoomMeta? roomForRequest(String callRequestId) {
    for (final v in _rooms.values) {
      final room = RoomMeta.fromJson(Map<String, dynamic>.from(v as Map));
      if (room.callRequestId == callRequestId) return room;
    }
    return null;
  }

  /// Fetches a LiveKit access token (and the LiveKit server url to connect
  /// to) from the local token_server for the given user, scoped to the dev
  /// room. See token_server/server.js.
  Future<CallToken> fetchCallToken({required String userId, required String userName}) async {
    final uri = Uri.parse(
      '${CallConfig.tokenServerBaseUrl}/token?userId=$userId&userName=$userName&roomId=${CallConfig.devRoomId}',
    );
    AppLogger.instance.log(LogTag.rtc, 'fetching token for $userId');
    final resp = await http.get(uri).timeout(const Duration(seconds: 8));
    if (resp.statusCode != 200) {
      throw Exception('Token server error ${resp.statusCode}: ${resp.body}');
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    return CallToken(token: body['token'] as String, url: body['url'] as String);
  }

  void dispose() {
    _sub?.cancel();
  }
}

class CallToken {
  final String token;
  final String url;
  const CallToken({required this.token, required this.url});
}
