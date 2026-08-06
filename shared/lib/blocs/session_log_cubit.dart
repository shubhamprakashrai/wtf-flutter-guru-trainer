import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/session_log.dart';
import '../services/log_service.dart';

class SessionLogUiState {
  final List<SessionLog> logs;
  const SessionLogUiState({this.logs = const []});
}

class SessionLogCubit extends Cubit<SessionLogUiState> {
  final LogService logService;
  final String? memberId;
  final String? trainerId;
  StreamSubscription? _sub;

  SessionLogCubit({required this.logService, this.memberId, this.trainerId}) : super(const SessionLogUiState()) {
    _load();
    _sub = logService.updates.listen((_) => _load());
  }

  void _load() => emit(SessionLogUiState(logs: logService.logsFor(memberId: memberId, trainerId: trainerId)));

  void refresh() => _load();

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
