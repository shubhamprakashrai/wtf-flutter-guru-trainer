import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared/shared.dart';

class SchedulerScreen extends StatelessWidget {
  const SchedulerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();
    final me = context.read<AuthCubit>().state.user!;
    final trainer = services.auth.getUser(me.assignedTrainerId ?? SeedData.trainerId) ?? SeedData.trainer;

    return BlocProvider(
      create: (_) => CallCubit(callService: services.call, memberId: me.id, trainerId: trainer.id),
      child: _SchedulerView(me: me, trainer: trainer),
    );
  }
}

class _SchedulerView extends StatefulWidget {
  final AppUser me;
  final AppUser trainer;
  const _SchedulerView({required this.me, required this.trainer});

  @override
  State<_SchedulerView> createState() => _SchedulerViewState();
}

class _SchedulerViewState extends State<_SchedulerView> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 2, vsync: this);

  late DateTime _selectedDay;
  DateTime? _selectedSlot;
  final _noteController = TextEditingController();
  bool _submitting = false;
  List<DateTime> _days = [];

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _days = List.generate(3, (i) => DateTime(today.year, today.month, today.day).add(Duration(days: i)));
    _selectedDay = _days.first;
  }

  @override
  void dispose() {
    _noteController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  List<DateTime> get _slotsForSelectedDay {
    final slots = <DateTime>[];
    var t = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day, 9, 0);
    final end = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day, 20, 30);
    while (t.isBefore(end)) {
      slots.add(t);
      t = t.add(const Duration(minutes: 30));
    }
    return slots;
  }

  Future<void> _submit() async {
    final slot = _selectedSlot;
    if (slot == null) return;
    final cubit = context.read<CallCubit>();
    final error = cubit.conflictError(widget.trainer.id, slot);
    if (error != null) {
      _showSnack(error, isError: true);
      return;
    }
    setState(() => _submitting = true);
    await cubit.request(memberId: widget.me.id, trainerId: widget.trainer.id, scheduledFor: slot, note: _noteController.text.trim());
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _selectedSlot = null;
      _noteController.clear();
    });
    _tabController.animateTo(1);
    _showSnack('Call requested. Waiting for trainer approval.');
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? const Color(0xFFD92D20) : const Color(0xFF12B76A),
      behavior: SnackBarBehavior.floating,
      action: isError ? SnackBarAction(label: 'Copy error', textColor: Colors.white, onPressed: () {}) : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule Call'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: const Color(0xFF667085),
          indicatorColor: Theme.of(context).colorScheme.primary,
          tabs: const [Tab(text: 'New Request'), Tab(text: 'My Requests')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildNewRequestTab(), _buildMyRequestsTab()],
      ),
    );
  }

  Widget _buildNewRequestTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pick a day', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(
            children: _days
                .map((d) => Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: DayChip(
                        date: d,
                        selected: _isSameDay(d, _selectedDay),
                        onTap: () => setState(() {
                          _selectedDay = d;
                          _selectedSlot = null;
                        }),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 20),
          const Text('Pick a time', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _slotsForSelectedDay.map((slot) {
              final disabled = slot.isBefore(DateTime.now());
              return TimeSlotChip(
                slot: slot,
                disabled: disabled,
                selected: _selectedSlot == slot,
                onTap: () => setState(() => _selectedSlot = slot),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          const Text('Note (optional)', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _noteController,
            maxLength: 140,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'e.g. Macros review'),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedSlot == null || _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Request Call'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyRequestsTab() {
    return BlocBuilder<CallCubit, CallUiState>(
      builder: (context, state) {
        if (state.requests.isEmpty) {
          return EmptyState(
            icon: Icons.calendar_today_outlined,
            title: 'No requests yet',
            message: 'Schedule your first call with ${widget.trainer.name}.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: state.requests.length,
          separatorBuilder: (context, i) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final r = state.requests[i];
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
                      Text(_formatDateTime(r.scheduledFor), style: const TextStyle(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      StatusPill(status: r.status),
                    ],
                  ),
                  if (r.note.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(r.note, style: const TextStyle(color: Color(0xFF667085))),
                  ],
                  const SizedBox(height: 6),
                  Text(_statusCopy(r), style: const TextStyle(fontSize: 12, color: Color(0xFF98A2B3))),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _statusCopy(CallRequest r) {
    switch (r.status) {
      case CallRequestStatus.pending:
        return 'Pending approval by ${widget.trainer.name}';
      case CallRequestStatus.approved:
        return 'Call approved for ${_formatDateTime(r.scheduledFor)}.';
      case CallRequestStatus.declined:
        return 'Call request declined. Reason: ${r.declineReason ?? 'Not specified'}.';
      case CallRequestStatus.cancelled:
        return 'Cancelled';
    }
  }

  String _formatDateTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.day}/${dt.month} $h:$m $ampm';
  }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}
