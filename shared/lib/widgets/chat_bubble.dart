import 'package:flutter/material.dart';

import '../models/chat_message.dart';

/// Bubble UI: right side = current user, left side = other participant.
/// [ownColor] is Member-blue in guru_app and Trainer-red in trainer_app,
/// so the two apps visually agree on whose message is whose.
class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;
  final Color ownColor;

  const ChatBubble({super.key, required this.message, required this.isMine, required this.ownColor});

  @override
  Widget build(BuildContext context) {
    if (message.isSystem) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F4F7),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            message.text,
            style: const TextStyle(fontSize: 12, color: Color(0xFF667085), fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final bubbleColor = isMine ? ownColor : const Color(0xFFF2F4F7);
    final textColor = isMine ? Colors.white : const Color(0xFF1D2939);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message.text, style: TextStyle(color: textColor, fontSize: 15)),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _timeLabel(message.createdAt),
                  style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.7)),
                ),
                if (isMine) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.status == MessageStatus.read ? Icons.done_all : Icons.done,
                    size: 14,
                    color: message.status == MessageStatus.read ? Colors.lightBlueAccent : textColor.withValues(alpha: 0.7),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _timeLabel(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }
}

class TypingIndicator extends StatelessWidget {
  const TypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: const Color(0xFFF2F4F7), borderRadius: BorderRadius.circular(16)),
        child: const _TypingDots(),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final t = (_controller.value + i * 0.2) % 1.0;
              final scale = 0.6 + 0.4 * (t < 0.5 ? t * 2 : (1 - t) * 2);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(color: Color(0xFF667085), shape: BoxShape.circle),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
