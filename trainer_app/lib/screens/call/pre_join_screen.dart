import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hmssdk_flutter/hmssdk_flutter.dart';
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
  late final HmsCallManager _manager;
  bool _ready = false;
  String? _error;
  String? _authToken;

  @override
  void initState() {
    super.initState();
    _manager = HmsCallManager()..addListener(_onChange);
    _setup();
  }

  Future<void> _setup() async {
    try {
      await [Permission.camera, Permission.microphone].request();
      if (!mounted) return;
      final services = context.read<AppServices>();
      final me = context.read<AuthCubit>().state.user!;
      final role = me.role == UserRole.trainer ? 'trainer' : 'member';
      final token = await services.call.fetchHmsToken(userId: me.id, role: role);
      _authToken = token;
      await _manager.init();
      await _manager.startPreview(userName: me.name, authToken: token);
      if (!mounted) return;
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
    super.dispose();
  }

  void _join() {
    final me = context.read<AuthCubit>().state.user!;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => InCallScreen(
        manager: _manager,
        userName: me.name,
        authToken: _authToken!,
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
                              child: Text(_error!, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                            ),
                          )
                        : !_ready || _manager.previewVideoTrack == null
                            ? const Center(child: CircularProgressIndicator(color: Colors.white))
                            : (_manager.isVideoOn
                                ? HMSVideoView(track: _manager.previewVideoTrack!, setMirror: true)
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
