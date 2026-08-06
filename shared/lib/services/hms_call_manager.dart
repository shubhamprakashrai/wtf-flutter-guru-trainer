import 'package:flutter/foundation.dart';
import 'package:hmssdk_flutter/hmssdk_flutter.dart';

import '../utils/app_logger.dart';

enum CallConnectionState { idle, connecting, connected, reconnecting, ended, error }

/// Thin wrapper around [HMSSDK] exposing a ChangeNotifier-friendly surface
/// for the pre-join/in-call screens (spec section 5 - "Role Permissions",
/// "Edge Cases: token expired, app background/foreground, network loss").
///
/// One instance per call - created fresh in PreJoinScreen and disposed when
/// the call screen is popped.
class HmsCallManager extends ChangeNotifier implements HMSUpdateListener, HMSPreviewListener {
  final HMSSDK _sdk = HMSSDK();

  CallConnectionState state = CallConnectionState.idle;
  HMSPeer? localPeer;
  List<HMSPeer> remotePeers = [];
  HMSVideoTrack? previewVideoTrack;
  String? errorMessage;
  bool isAudioOn = true;
  bool isVideoOn = true;

  HMSSDK get sdk => _sdk;

  Future<void> init() async {
    await _sdk.build();
    _sdk.addUpdateListener(listener: this);
  }

  /// Pre-join device check (spec section D): warms up camera/mic and shows a
  /// local preview without actually publishing to the room yet.
  Future<void> startPreview({required String userName, required String authToken}) async {
    _sdk.addPreviewListener(listener: this);
    await _sdk.preview(config: HMSConfig(userName: userName, authToken: authToken));
  }

  Future<void> join({required String userName, required String authToken}) async {
    state = CallConnectionState.connecting;
    notifyListeners();
    AppLogger.instance.log(LogTag.rtc, 'joining as $userName');
    final result = await _sdk.join(config: HMSConfig(userName: userName, authToken: authToken));
    if (result is HMSException) {
      state = CallConnectionState.error;
      errorMessage = result.message;
      AppLogger.instance.log(LogTag.rtc, 'join failed: ${result.message}');
      notifyListeners();
    }
  }

  Future<void> leave() async {
    await _sdk.leave();
    state = CallConnectionState.ended;
    AppLogger.instance.log(LogTag.rtc, 'left call');
    notifyListeners();
  }

  Future<void> toggleMic() async {
    await _sdk.toggleMicMuteState();
    isAudioOn = !isAudioOn;
    AppLogger.instance.log(LogTag.rtc, 'mic ${isAudioOn ? 'on' : 'off'}');
    notifyListeners();
  }

  Future<void> toggleCamera() async {
    await _sdk.toggleCameraMuteState();
    isVideoOn = !isVideoOn;
    AppLogger.instance.log(LogTag.rtc, 'camera ${isVideoOn ? 'on' : 'off'}');
    notifyListeners();
  }

  Future<void> switchCamera() async {
    await _sdk.switchCamera();
  }

  Future<void> teardown() async {
    _sdk.removeUpdateListener(listener: this);
    _sdk.removePreviewListener(listener: this);
    _sdk.destroy();
  }

  Future<void> _refreshPeers() async {
    localPeer = await _sdk.getLocalPeer();
    remotePeers = await _sdk.getRemotePeers() ?? [];
  }

  @override
  void onJoin({required HMSRoom room}) async {
    await _refreshPeers();
    state = CallConnectionState.connected;
    AppLogger.instance.log(LogTag.rtc, 'joined room ${room.name}');
    notifyListeners();
  }

  @override
  void onPeerUpdate({required HMSPeer peer, required HMSPeerUpdate update}) async {
    await _refreshPeers();
    AppLogger.instance.log(LogTag.rtc, 'peer update: ${peer.name} -> ${update.name}');
    notifyListeners();
  }

  @override
  void onPeerListUpdate({required List<HMSPeer> addedPeers, required List<HMSPeer> removedPeers}) async {
    await _refreshPeers();
    notifyListeners();
  }

  @override
  void onTrackUpdate({required HMSTrack track, required HMSTrackUpdate trackUpdate, required HMSPeer peer}) async {
    await _refreshPeers();
    notifyListeners();
  }

  @override
  void onHMSError({required HMSException error}) {
    errorMessage = error.message;
    AppLogger.instance.log(LogTag.rtc, 'error: ${error.message}');
    notifyListeners();
  }

  @override
  void onReconnecting() {
    state = CallConnectionState.reconnecting;
    AppLogger.instance.log(LogTag.rtc, 'reconnecting…');
    notifyListeners();
  }

  @override
  void onReconnected() {
    state = CallConnectionState.connected;
    AppLogger.instance.log(LogTag.rtc, 'reconnected');
    notifyListeners();
  }

  @override
  void onRemovedFromRoom({required HMSPeerRemovedFromPeer hmsPeerRemovedFromPeer}) {
    state = CallConnectionState.ended;
    notifyListeners();
  }

  @override
  void onRoomUpdate({required HMSRoom room, required HMSRoomUpdate update}) {}

  @override
  void onMessage({required HMSMessage message}) {}

  @override
  void onUpdateSpeakers({required List<HMSSpeaker> updateSpeakers}) {}

  @override
  void onRoleChangeRequest({required HMSRoleChangeRequest roleChangeRequest}) {}

  @override
  void onChangeTrackStateRequest({required HMSTrackChangeRequest hmsTrackChangeRequest}) {}

  @override
  void onAudioDeviceChanged({HMSAudioDevice? currentAudioDevice, List<HMSAudioDevice>? availableAudioDevice}) {}

  @override
  void onSessionStoreAvailable({HMSSessionStore? hmsSessionStore}) {}

  // --- HMSPreviewListener -----------------------------------------------

  @override
  void onPreview({required HMSRoom room, required List<HMSTrack> localTracks}) {
    for (final track in localTracks) {
      if (track is HMSVideoTrack) {
        previewVideoTrack = track;
        isVideoOn = !track.isMute;
      }
      if (track is HMSAudioTrack) {
        isAudioOn = !track.isMute;
      }
    }
    AppLogger.instance.log(LogTag.rtc, 'preview ready (${localTracks.length} local tracks)');
    notifyListeners();
  }
}
