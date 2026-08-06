import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

void main() {
  group('SessionLog duration calculation', () {
    test('computes duration in whole seconds from start/end timestamps', () {
      final start = DateTime(2026, 8, 6, 18, 0, 0);
      final end = DateTime(2026, 8, 6, 18, 12, 34);
      final duration = SessionLog.computeDurationSec(start, end);
      expect(duration, 12 * 60 + 34);
    });

    test('falls back to the provided value when endedAt is null (e.g. SDK did not report one)', () {
      final start = DateTime(2026, 8, 6, 18, 0);
      final duration = SessionLog.computeDurationSec(start, null, fallback: 42);
      expect(duration, 42);
    });

    test('falls back instead of returning a negative duration on clock skew', () {
      final start = DateTime(2026, 8, 6, 18, 0);
      final endBeforeStart = DateTime(2026, 8, 6, 17, 59);
      final duration = SessionLog.computeDurationSec(start, endBeforeStart, fallback: 5);
      expect(duration, 5);
    });
  });

  group('DurationLabel extension', () {
    test('formats sub-minute durations as seconds only', () {
      expect(45.asDuration, '45s');
    });

    test('formats multi-minute durations as "Xm Ys"', () {
      expect(754.asDuration, '12m 34s');
    });
  });
}
