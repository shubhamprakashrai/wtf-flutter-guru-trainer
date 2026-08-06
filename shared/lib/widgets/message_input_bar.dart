import 'package:flutter/material.dart';

class MessageInputBar extends StatefulWidget {
  final ValueChanged<String> onSend;
  final List<String> quickReplies;

  const MessageInputBar({super.key, required this.onSend, this.quickReplies = const []});

  @override
  State<MessageInputBar> createState() => _MessageInputBarState();
}

class _MessageInputBarState extends State<MessageInputBar> {
  final _controller = TextEditingController();

  void _send([String? text]) {
    final value = (text ?? _controller.text).trim();
    if (value.isEmpty) return;
    widget.onSend(value);
    _controller.clear();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: Color(0xFFE4E7EC))),
        ),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.quickReplies.isNotEmpty)
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.quickReplies.length,
                  separatorBuilder: (context, i) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final reply = widget.quickReplies[i];
                    return ActionChip(
                      label: Text(reply, style: const TextStyle(fontSize: 13)),
                      backgroundColor: const Color(0xFFF2F4F7),
                      onPressed: () => _send(reply),
                    );
                  },
                ),
              ),
            if (widget.quickReplies.isNotEmpty) const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Message',
                      filled: true,
                      fillColor: const Color(0xFFF7F8FA),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: _send,
                  ),
                ),
                const SizedBox(width: 8),
                _SendButton(onTap: () => _send(), color: Theme.of(context).colorScheme.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SendButton extends StatefulWidget {
  final VoidCallback onTap;
  final Color color;
  const _SendButton({required this.onTap, required this.color});

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.9),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 150),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
          child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
