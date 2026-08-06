import 'dart:async';

import 'package:flutter/material.dart';

import '../utils/app_logger.dart';

/// Floating "..." button (spec section 8) that opens a DevPanel with build
/// info and the last 20 tagged logs. Drop [DevPanelButton] anywhere near the
/// root of a screen (e.g. wrapped in a Stack) to enable it app-wide.
class DevPanelButton extends StatelessWidget {
  final String appLabel;
  final Map<String, String> buildInfo;

  const DevPanelButton({super.key, required this.appLabel, this.buildInfo = const {}});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 12,
      bottom: 12,
      child: SafeArea(
        child: FloatingActionButton.small(
          heroTag: 'dev_panel_$appLabel',
          backgroundColor: Colors.black87,
          foregroundColor: Colors.white,
          onPressed: () => _openDevPanel(context, appLabel, buildInfo),
          child: const Icon(Icons.more_vert),
        ),
      ),
    );
  }
}

void _openDevPanel(BuildContext context, String appLabel, Map<String, String> buildInfo) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => _DevPanelSheet(appLabel: appLabel, buildInfo: buildInfo),
  );
}

class _DevPanelSheet extends StatefulWidget {
  final String appLabel;
  final Map<String, String> buildInfo;

  const _DevPanelSheet({required this.appLabel, required this.buildInfo});

  @override
  State<_DevPanelSheet> createState() => _DevPanelSheetState();
}

class _DevPanelSheetState extends State<_DevPanelSheet> {
  late List<LogEntry> _logs;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _logs = AppLogger.instance.entries.reversed.toList();
    _sub = AppLogger.instance.stream.listen((entry) {
      setState(() => _logs = AppLogger.instance.entries.reversed.toList());
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 12),
              Text('DevPanel · ${widget.appLabel}', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.buildInfo.entries
                    .map((e) => Chip(label: Text('${e.key}: ${e.value}'), visualDensity: VisualDensity.compact))
                    .toList(),
              ),
              const SizedBox(height: 12),
              Text('Last ${_logs.length} logs', style: Theme.of(context).textTheme.bodyLarge),
              const Divider(),
              Expanded(
                child: _logs.isEmpty
                    ? const Center(child: Text('No logs yet.'))
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _logs.length,
                        itemBuilder: (context, i) {
                          final entry = _logs[i];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              entry.toString(),
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
