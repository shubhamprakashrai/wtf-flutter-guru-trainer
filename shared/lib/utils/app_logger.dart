import 'dart:async';
import 'dart:collection';

enum LogTag { chat, rtc, schedule, auth }

class LogEntry {
  final DateTime time;
  final LogTag tag;
  final String message;

  LogEntry(this.tag, this.message) : time = DateTime.now();

  @override
  String toString() {
    final t = time.toIso8601String().substring(11, 19);
    return '[$t] [${tag.name.toUpperCase()}] $message';
  }
}

/// App-wide ring buffer logger backing the DevPanel. Kept simple and
/// dependency-free so both apps can share one instance via a singleton.
class AppLogger {
  AppLogger._();
  static final AppLogger instance = AppLogger._();

  static const _maxEntries = 20;
  final ListQueue<LogEntry> _entries = ListQueue<LogEntry>(_maxEntries);
  final StreamController<LogEntry> _controller = StreamController.broadcast();

  Stream<LogEntry> get stream => _controller.stream;
  List<LogEntry> get entries => _entries.toList();

  void log(LogTag tag, String message) {
    final entry = LogEntry(tag, message);
    if (_entries.length >= _maxEntries) {
      _entries.removeFirst();
    }
    _entries.add(entry);
    _controller.add(entry);
    // ignore: avoid_print
    print(entry.toString());
  }
}
