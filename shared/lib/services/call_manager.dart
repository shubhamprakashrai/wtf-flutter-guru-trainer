import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import '../utils/app_logger.dart';

enum CallConnectionState { idle, connecting, connected, reconnecting, ended, error }

/// Thin wrapper around LiveKit's [lk.Room] for the pre-join/in-call screens
/// (spec section 5 - "Role Permissions", "Edge Cases: token expired, app
/// background/foreground, network loss"). `Room` is already a
/// ChangeNotifier, so this class mostly re-exposes it with the same shape
/// the UI previously expected from the 100ms integration (see
/// DECISIONS.md ADR #3 for why the RTC vendor changed mid-build).
///
/// One instance per call - created fresh in PreJoinScreen and torn down
/// when the call screen is popped.
class CallManager extends ChangeNotifier {
  final lk.Room room = lk.Room();

  lk.LocalVideoTrack? previewVideoTrack;
  bool _hasError = false;
  bool _ended = false;
  String? errorMessage;
  bool isAudioOn = true;
  bool isVideoOn = true;
  lk.CameraPosition _cameraPosition = lk.CameraPosition.front;

  CallManager() {
    room.addListener(_onRoomChange);
  }

  void _onRoomChange() => notifyListeners();

  CallConnectionState get state {
    if (_hasError) return CallConnectionState.error;
    if (_ended) return CallConnectionState.ended;
    switch (room.connectionState) {
      case lk.ConnectionState.disconnected:
        return CallConnectionState.idle;
      case lk.ConnectionState.connecting:
        return CallConnectionState.connecting;
      case lk.ConnectionState.reconnecting:
        return CallConnectionState.reconnecting;
      case lk.ConnectionState.connected:
        return CallConnectionState.connected;
    }
  }

  lk.LocalParticipant? get localParticipant => room.localParticipant;
  List<lk.RemoteParticipant> get remoteParticipants => room.remoteParticipants.values.toList();

  /// Pre-join device check (spec section D): warms up the camera and shows
  /// a local preview without publishing to any room yet.
  Future<void> startPreview() async {
    try {
      previewVideoTrack = await lk.LocalVideoTrack.createCameraTrack(
        lk.CameraCaptureOptions(cameraPosition: _cameraPosition),
      );
      await previewVideoTrack!.start();
      AppLogger.instance.log(LogTag.rtc, 'preview ready');
    } catch (e) {
      _hasError = true;
      errorMessage = e.toString();
      AppLogger.instance.log(LogTag.rtc, 'preview failed: $e');
    }
    notifyListeners();
  }

  Future<void> connect({required String url, required String userName, required String token}) async {
    try {
      await previewVideoTrack?.stop();
      await previewVideoTrack?.dispose();
      previewVideoTrack = null;
      AppLogger.instance.log(LogTag.rtc, 'joining as $userName');
      await room.connect(
        url,
        token,
        fastConnectOptions: lk.FastConnectOptions(
          microphone: lk.TrackOption(enabled: isAudioOn),
          camera: lk.TrackOption(enabled: isVideoOn),
        ),
      );
      AppLogger.instance.log(LogTag.rtc, 'joined room');
    } catch (e) {
      _hasError = true;
      errorMessage = e.toString();
      AppLogger.instance.log(LogTag.rtc, 'join failed: $e');
    }
    notifyListeners();
  }

  Future<void> toggleMic() async {
    isAudioOn = !isAudioOn;
    await room.localParticipant?.setMicrophoneEnabled(isAudioOn);
    AppLogger.instance.log(LogTag.rtc, 'mic ${isAudioOn ? 'on' : 'off'}');
    notifyListeners();
  }

  Future<void> toggleCamera() async {
    isVideoOn = !isVideoOn;
    await room.localParticipant?.setCameraEnabled(isVideoOn);
    AppLogger.instance.log(LogTag.rtc, 'camera ${isVideoOn ? 'on' : 'off'}');
    notifyListeners();
  }

  Future<void> switchCamera() async {
    _cameraPosition = _cameraPosition == lk.CameraPosition.front ? lk.CameraPosition.back : lk.CameraPosition.front;
    final pub = room.localParticipant?.videoTrackPublications.firstOrNull;
    final track = pub?.track;
    if (track is lk.LocalVideoTrack) {
      await track.setCameraPosition(_cameraPosition);
    }
  }

  Future<void> leave() async {
    _ended = true;
    await room.disconnect();
    AppLogger.instance.log(LogTag.rtc, 'left call');
    notifyListeners();
  }

  Future<void> teardown() async {
    room.removeListener(_onRoomChange);
    await previewVideoTrack?.stop();
    await previewVideoTrack?.dispose();
    await room.dispose();
  }
}
