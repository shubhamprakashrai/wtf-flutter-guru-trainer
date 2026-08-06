import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared/shared.dart';

class RequestsScreen extends StatelessWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();
    final me = context.read<AuthCubit>().state.user!;
    return BlocProvider(
      create: (_) => CallCubit(callService: services.call, trainerId: me.id),
      child: const _RequestsView(),
    );
  }
}

class _RequestsView extends StatelessWidget {
  const _RequestsView();

  Future<void> _approve(BuildContext context, CallRequest req) async {
    final services = context.read<AppServices>();
    final cubit = context.read<CallCubit>();
    await cubit.approve(req);
    final chatId = ChatMessage.chatIdFor(req.memberId, req.trainerId);
    await services.chat.sendSystemMessage(
      chatId: chatId,
      senderId: req.trainerId,
      receiverId: req.memberId,
      text: 'Call approved for ${_formatDateTime(req.scheduledFor)}.',
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Call approved for ${_formatDateTime(req.scheduledFor)}.'),
      backgroundColor: const Color(0xFF12B76A),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _decline(BuildContext context, CallRequest req) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _DeclineReasonSheet(),
    );
    if (reason == null) return;
    if (!context.mounted) return;
    final cubit = context.read<CallCubit>();
    await cubit.decline(req, reason);
  }

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();

    return Scaffold(
      appBar: AppBar(title: const Text('Requests')),
      body: BlocBuilder<CallCubit, CallUiState>(
        builder: (context, state) {
          if (state.requests.isEmpty) {
            return const EmptyState(
              icon: Icons.pending_actions_outlined,
              title: 'No requests',
              message: 'Call requests from members will appear here.',
            );
          }
          final sorted = [...state.requests]..sort((a, b) {
              const order = {
                CallRequestStatus.pending: 0,
                CallRequestStatus.approved: 1,
                CallRequestStatus.declined: 2,
                CallRequestStatus.cancelled: 3,
              };
              return order[a.status]!.compareTo(order[b.status]!);
            });
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: sorted.length,
            separatorBuilder: (context, i) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final r = sorted[i];
              final member = services.auth.getUser(r.memberId);
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE4E7EC)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        UserAvatar(url: member?.avatarUrl, fallbackInitial: member?.name[0] ?? '?', size: 32),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(member?.name ?? r.memberId, style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text(_formatDateTime(r.scheduledFor), style: const TextStyle(fontSize: 12, color: Color(0xFF667085))),
                            ],
                          ),
                        ),
                        StatusPill(status: r.status),
                      ],
                    ),
                    if (r.note.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(r.note, style: const TextStyle(color: Color(0xFF344054))),
                    ],
                    if (r.status == CallRequestStatus.pending) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _decline(context, r),
                              style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFD92D20), side: const BorderSide(color: Color(0xFFD92D20))),
                              child: const Text('Decline'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _approve(context, r),
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF12B76A)),
                              child: const Text('Approve'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.day}/${dt.month} $h:$m $ampm';
  }
}

class _DeclineReasonSheet extends StatefulWidget {
  const _DeclineReasonSheet();

  @override
  State<_DeclineReasonSheet> createState() => _DeclineReasonSheetState();
}

class _DeclineReasonSheetState extends State<_DeclineReasonSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Decline request', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLines: 2,
            decoration: const InputDecoration(hintText: 'Reason (shown to the member)'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(_controller.text.trim().isEmpty ? 'Not specified' : _controller.text.trim()),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD92D20)),
              child: const Text('Decline'),
            ),
          ),
        ],
      ),
    );
  }
}
