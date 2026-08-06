import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/call_request.dart';
import '../models/room_meta.dart';
import '../services/call_service.dart';

class CallUiState {
  final List<CallRequest> requests;
  const CallUiState({this.requests = const []});
}

/// Scoped to a member/trainer pair (or just a trainer for the Requests
/// inbox). Reloads from [CallService] whenever a request or room update is
/// relayed from the other app.
class CallCubit extends Cubit<CallUiState> {
  final CallService callService;
  final String? memberId;
  final String? trainerId;
  StreamSubscription? _sub;

  CallCubit({required this.callService, this.memberId, this.trainerId}) : super(const CallUiState()) {
    _load();
    _sub = callService.updates.listen((_) => _load());
  }

  void _load() => emit(CallUiState(requests: callService.requestsFor(memberId: memberId, trainerId: trainerId)));

  void refresh() => _load();

  String? conflictError(String trainerId, DateTime slot) => callService.conflictError(trainerId, slot);

  Future<CallRequest> request({
    required String memberId,
    required String trainerId,
    required DateTime scheduledFor,
    required String note,
  }) async {
    final req = await callService.requestCall(memberId: memberId, trainerId: trainerId, scheduledFor: scheduledFor, note: note);
    _load();
    return req;
  }

  Future<RoomMeta> approve(CallRequest req) async {
    final room = await callService.approve(req);
    _load();
    return room;
  }

  Future<CallRequest> decline(CallRequest req, String reason) async {
    final updated = await callService.decline(req, reason);
    _load();
    return updated;
  }

  RoomMeta? roomFor(String callRequestId) => callService.roomForRequest(callRequestId);

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
