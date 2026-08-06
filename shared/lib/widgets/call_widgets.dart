import 'package:flutter/material.dart';
import 'package:hmssdk_flutter/hmssdk_flutter.dart';

/// One grid tile in the in-call screen (spec section D - "Two participant
/// tiles (grid), name labels").
class ParticipantTile extends StatelessWidget {
  final HMSPeer peer;
  final HMSVideoTrack? videoTrack;
  final bool isMuted;

  const ParticipantTile({super.key, required this.peer, required this.videoTrack, this.isMuted = false});

  @override
  Widget build(BuildContext context) {
    final hasVideo = videoTrack != null && !videoTrack!.isMute;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: const Color(0xFF1D2939)),
          if (hasVideo)
            HMSVideoView(track: videoTrack!, setMirror: peer.isLocal)
          else
            Center(
              child: CircleAvatar(
                radius: 32,
                backgroundColor: Colors.white24,
                child: Text(
                  peer.name.isNotEmpty ? peer.name[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          Positioned(
            left: 10,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isMuted) const Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.mic_off, color: Colors.white, size: 14)),
                  Text(
                    peer.isLocal ? '${peer.name} (You)' : peer.name,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CallControlButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final Color? activeColor;
  final Color? inactiveColor;
  final VoidCallback onTap;
  final String? tooltip;

  const CallControlButton({
    super.key,
    required this.icon,
    required this.active,
    required this.onTap,
    this.activeColor,
    this.inactiveColor,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? (activeColor ?? Colors.white24) : (inactiveColor ?? const Color(0xFFD92D20));
    final button = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: button) : button;
  }
}

class ReconnectingBanner extends StatelessWidget {
  const ReconnectingBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFF79009),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          SizedBox(width: 8),
          Text('Reconnecting…', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
