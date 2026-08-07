import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared/shared.dart';

class InCallScreen extends StatefulWidget {
  final CallManager manager;
  final String userName;
  final CallToken callToken;
  final RoomMeta room;
  final String sessionMemberId;
  final String sessionTrainerId;

  const InCallScreen({
    super.key,
    required this.manager,
    required this.userName,
    required this.callToken,
    required this.room,
    required this.sessionMemberId,
    required this.sessionTrainerId,
  });

  @override
  State<InCallScreen> createState() => _InCallScreenState();
}

class _InCallScreenState extends State<InCallScreen> {
  bool _sessionStarted = false;
  bool _ending = false;

  @override
  void initState() {
    super.initState();
    widget.manager.addListener(_onChange);
    widget.manager.connect(url: widget.callToken.url, userName: widget.userName, token: widget.callToken.token);
  }

  void _onChange() {
    if (!mounted) return;
    setState(() {});
    if (widget.manager.state == CallConnectionState.connected && !_sessionStarted) {
      _sessionStarted = true;
      context.read<AppServices>().log.startSession(
            id: widget.room.callRequestId,
            memberId: widget.sessionMemberId,
            trainerId: widget.sessionTrainerId,
          );
    }
  }

  @override
  void dispose() {
    widget.manager.removeListener(_onChange);
    widget.manager.teardown();
    super.dispose();
  }

  Future<void> _endCall() async {
    if (_ending) return;
    setState(() => _ending = true);
    await widget.manager.leave();
    if (!mounted) return;
    final services = context.read<AppServices>();
    final log = await services.log.endSession(widget.room.callRequestId);
    if (!mounted) return;
    final isTrainer = context.read<AuthCubit>().state.user?.role == UserRole.trainer;
    Navigator.of(context).pop();
    await showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      // Without this, the sheet is capped at a fixed fraction of the screen
      // and doesn't properly resize for the keyboard - the note TextField
      // would get covered/overflow as soon as it's focused.
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => isTrainer ? _TrainerNotesSheet(sessionLogId: log.id) : _RatingSheet(sessionLogId: log.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final manager = widget.manager;
    final local = manager.localParticipant;
    final remotes = manager.remoteParticipants;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF101828),
        body: SafeArea(
          child: Column(
            children: [
              if (manager.state == CallConnectionState.reconnecting) const ReconnectingBanner(),
              if (manager.state == CallConnectionState.connecting)
                const Expanded(child: Center(child: CircularProgressIndicator(color: Colors.white)))
              else if (manager.state == CallConnectionState.error)
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(manager.errorMessage ?? 'Call failed', style: const TextStyle(color: Colors.white70)),
                    ),
                  ),
                )
              else
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: (local != null ? 1 : 0) + remotes.length,
                      itemBuilder: (context, i) {
                        if (local != null && i == 0) {
                          return ParticipantTile(participant: local, isLocal: true);
                        }
                        final remote = remotes[local != null ? i - 1 : i];
                        return ParticipantTile(participant: remote);
                      },
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CallControlButton(
                      icon: manager.isAudioOn ? Icons.mic : Icons.mic_off,
                      active: manager.isAudioOn,
                      onTap: () => manager.toggleMic(),
                    ),
                    const SizedBox(width: 14),
                    CallControlButton(
                      icon: manager.isVideoOn ? Icons.videocam : Icons.videocam_off,
                      active: manager.isVideoOn,
                      onTap: () => manager.toggleCamera(),
                    ),
                    const SizedBox(width: 14),
                    CallControlButton(
                      icon: Icons.cameraswitch,
                      active: true,
                      onTap: () => manager.switchCamera(),
                    ),
                    const SizedBox(width: 14),
                    CallControlButton(
                      icon: Icons.call_end,
                      active: false,
                      onTap: _ending ? () {} : _endCall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RatingSheet extends StatefulWidget {
  final String sessionLogId;
  const _RatingSheet({required this.sessionLogId});

  @override
  State<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<_RatingSheet> {
  int _rating = 0;
  final _noteController = TextEditingController();
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    await context.read<AppServices>().log.addMemberFeedback(
          widget.sessionLogId,
          rating: _rating,
          note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        );
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Session saved to your logs.'),
      backgroundColor: Color(0xFF12B76A),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rate your session', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          const Text('Session saved to your logs.', style: TextStyle(color: Color(0xFF667085))),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final filled = i < _rating;
              return IconButton(
                onPressed: () => setState(() => _rating = i + 1),
                icon: Icon(filled ? Icons.star : Icons.star_border, color: const Color(0xFFF79009), size: 32),
              );
            }),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _noteController,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Optional note for yourself'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _rating == 0 || _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainerNotesSheet extends StatefulWidget {
  final String sessionLogId;
  const _TrainerNotesSheet({required this.sessionLogId});

  @override
  State<_TrainerNotesSheet> createState() => _TrainerNotesSheetState();
}

class _TrainerNotesSheetState extends State<_TrainerNotesSheet> {
  final _noteController = TextEditingController();
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    await context.read<AppServices>().log.addTrainerNotes(widget.sessionLogId, notes: _noteController.text.trim());
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Session saved to your logs.'),
      backgroundColor: Color(0xFF12B76A),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Session notes', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          const Text('Add quick notes for this member.', style: TextStyle(color: Color(0xFF667085))),
          const SizedBox(height: 16),
          TextField(
            controller: _noteController,
            maxLines: 4,
            decoration: const InputDecoration(hintText: 'e.g. Focused on form, increase weight next session'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Mark as complete'),
            ),
          ),
        ],
      ),
    );
  }
}
