extension RelativeTime on DateTime {
  /// "5m ago" style relative label for chat previews.
  String get timeAgo {
    final diff = DateTime.now().difference(this);
    if (diff.inSeconds < 60) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '$day/$month/$year';
  }
}

extension DurationLabel on int {
  /// Formats seconds as "12m 34s" for session logs.
  String get asDuration {
    final d = Duration(seconds: this);
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    if (m == 0) return '${s}s';
    return '${m}m ${s}s';
  }
}
