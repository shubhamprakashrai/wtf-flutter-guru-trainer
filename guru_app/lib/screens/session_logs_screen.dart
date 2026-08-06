import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared/shared.dart';

enum _Filter { all, last7, thisMonth }

class SessionLogsScreen extends StatelessWidget {
  const SessionLogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();
    final me = context.read<AuthCubit>().state.user!;
    return BlocProvider(
      create: (_) => SessionLogCubit(logService: services.log, memberId: me.id),
      child: const _SessionLogsView(),
    );
  }
}

class _SessionLogsView extends StatefulWidget {
  const _SessionLogsView();

  @override
  State<_SessionLogsView> createState() => _SessionLogsViewState();
}

class _SessionLogsViewState extends State<_SessionLogsView> {
  _Filter _filter = _Filter.all;

  List<SessionLog> _applyFilter(List<SessionLog> logs) {
    final now = DateTime.now();
    switch (_filter) {
      case _Filter.all:
        return logs;
      case _Filter.last7:
        return logs.where((l) => now.difference(l.startedAt).inDays <= 7).toList();
      case _Filter.thisMonth:
        return logs.where((l) => l.startedAt.year == now.year && l.startedAt.month == now.month).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Sessions')),
      body: BlocBuilder<SessionLogCubit, SessionLogUiState>(
        builder: (context, state) {
          final logs = _applyFilter(state.logs);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _chip('All', _Filter.all),
                    const SizedBox(width: 8),
                    _chip('Last 7 days', _Filter.last7),
                    const SizedBox(width: 8),
                    _chip('This Month', _Filter.thisMonth),
                  ],
                ),
              ),
              Expanded(
                child: logs.isEmpty
                    ? const EmptyState(
                        icon: Icons.history,
                        title: 'No sessions yet',
                        message: 'Schedule your first call to see it here.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: logs.length,
                        separatorBuilder: (context, i) => const SizedBox(height: 10),
                        itemBuilder: (context, i) => _LogTile(log: logs[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _chip(String label, _Filter value) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = value),
    );
  }
}

class _LogTile extends StatelessWidget {
  final SessionLog log;
  const _LogTile({required this.log});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => _LogDetailSheet(log: log),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE4E7EC)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: const Color(0xFF1769E0).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.videocam_outlined, color: Color(0xFF1769E0)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_formatDate(log.startedAt), style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(log.durationSec.asDuration, style: const TextStyle(fontSize: 12, color: Color(0xFF667085))),
                ],
              ),
            ),
            if (log.rating != null)
              Row(
                children: [
                  const Icon(Icons.star, size: 16, color: Color(0xFFF79009)),
                  const SizedBox(width: 2),
                  Text('${log.rating}', style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year} · ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
}

class _LogDetailSheet extends StatelessWidget {
  final SessionLog log;
  const _LogDetailSheet({required this.log});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Session Detail', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          _row('Duration', log.durationSec.asDuration),
          _row('Rating', log.rating != null ? '${log.rating} / 5' : 'Not rated'),
          const SizedBox(height: 12),
          if (log.memberNotes != null) ...[
            const Text('Your note', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(log.memberNotes!),
            const SizedBox(height: 12),
          ],
          if (log.trainerNotes != null) ...[
            const Text('Trainer notes', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(log.trainerNotes!),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Color(0xFF667085))),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
