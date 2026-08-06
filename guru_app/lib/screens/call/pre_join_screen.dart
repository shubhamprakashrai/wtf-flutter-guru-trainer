import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared/shared.dart';

import 'in_call_screen.dart';

/// "Ready to join? Check mic and camera." (spec copy) - device check modal
/// before the call actually connects (spec section D).
class PreJoinScreen extends StatefulWidget {
  final RoomMeta room;
  final String sessionMemberId;
  final String sessionTrainerId;

  const PreJoinScreen({super.key, required this.room, required this.sessionMemberId, required this.sessionTrainerId});

  @override
  State<PreJoinScreen> createState() => _PreJoinScreenState();
}

class _PreJoinScreenState extends State<PreJoinScreen> {
  late CallManager _manager;
  bool _ready = false;
  String? _error;
  CallToken? _callToken;
  bool _ownershipTransferred = false;

  @override
  void initState() {
    super.initState();
    _manager = CallManager()..addListener(_onChange);
    _setup();
  }

  Future<void> _retry() async {
    _manager.removeListener(_onChange);
    await _manager.teardown();
    setState(() {
      _error = null;
      _ready = false;
      _manager = CallManager()..addListener(_onChange);
    });
    _setup();
  }

  Future<void> _setup() async {
    try {
      await [Permission.camera, Permission.microphone].request();
      if (!mounted) return;
      final services = context.read<AppServices>();
      final me = context.read<AuthCubit>().state.user!;
      final callToken = await services.call.fetchCallToken(userId: me.id, userName: me.name);
      _callToken = callToken;
      await _manager.startPreview();
      if (!mounted) return;
      if (_manager.errorMessage != null) {
        setState(() => _error = _manager.errorMessage);
        return;
      }
      setState(() => _ready = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  void _onChange() => setState(() {});

  @override
  void dispose() {
    _manager.removeListener(_onChange);
    // InCallScreen takes over the manager's lifecycle once we've joined; if
    // the user backs out of the device-check screen instead, release the
    // camera/mic here so preview doesn't keep running in the background.
    if (!_ownershipTransferred) {
      _manager.teardown();
    }
    super.dispose();
  }

  void _join() {
    _ownershipTransferred = true;
    final me = context.read<AuthCubit>().state.user!;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => InCallScreen(
        manager: _manager,
        userName: me.name,
        callToken: _callToken!,
        room: widget.room,
        sessionMemberId: widget.sessionMemberId,
        sessionTrainerId: widget.sessionTrainerId,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101828),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Ready to join?'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text(
                'Ready to join? Check mic and camera.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    color: const Color(0xFF1D2939),
                    child: _error != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.error_outline, color: Colors.white38, size: 36),
                                  const SizedBox(height: 12),
                                  Text(_error!, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                                  const SizedBox(height: 16),
                                  OutlinedButton(
                                    onPressed: _retry,
                                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white38)),
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : !_ready || _manager.previewVideoTrack == null
                            ? const Center(child: CircularProgressIndicator(color: Colors.white))
                            : (_manager.isVideoOn
                                ? lk.VideoTrackRenderer(_manager.previewVideoTrack!, mirrorMode: lk.VideoViewMirrorMode.mirror)
                                : const Center(
                                    child: Icon(Icons.videocam_off, color: Colors.white38, size: 48),
                                  )),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CallControlButton(
                    icon: _manager.isAudioOn ? Icons.mic : Icons.mic_off,
                    active: _manager.isAudioOn,
                    onTap: _ready ? () => _manager.toggleMic() : () {},
                  ),
                  const SizedBox(width: 16),
                  CallControlButton(
                    icon: _manager.isVideoOn ? Icons.videocam : Icons.videocam_off,
                    active: _manager.isVideoOn,
                    onTap: _ready ? () => _manager.toggleCamera() : () {},
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _ready && _error == null ? _join : null,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF12B76A)),
                  child: const Text('Join Call'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
