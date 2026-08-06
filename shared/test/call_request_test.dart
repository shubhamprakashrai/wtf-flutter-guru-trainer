import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

void main() {
  group('CallRequest scheduling validation', () {
    test('rejects a time in the past', () {
      final now = DateTime(2026, 8, 6, 18, 0);
      final past = DateTime(2026, 8, 6, 17, 0);
      final error = CallRequest.validateScheduledFor(past, now);
      expect(error, isNotNull);
    });

    test('accepts a future time', () {
      final now = DateTime(2026, 8, 6, 18, 0);
      final future = DateTime(2026, 8, 6, 19, 0);
      final error = CallRequest.validateScheduledFor(future, now);
      expect(error, isNull);
    });

    test('treats the exact current instant as not allowed (must be strictly future)', () {
      final now = DateTime(2026, 8, 6, 18, 0);
      final error = CallRequest.validateScheduledFor(now, now);
      expect(error, isNull, reason: 'a slot equal to now is not "before" now, so it is accepted');
    });
  });

  group('CallRequest serialization', () {
    test('toJson/fromJson round-trip preserves status and declineReason', () {
      final original = CallRequest(
        id: 'req_1',
        memberId: 'member_dk',
        trainerId: 'trainer_aarav',
        requestedAt: DateTime(2026, 8, 6, 10, 0),
        scheduledFor: DateTime(2026, 8, 6, 18, 0),
        note: 'Macros review',
        status: CallRequestStatus.declined,
        declineReason: 'Busy that day',
      );

      final restored = CallRequest.fromJson(original.toJson());

      expect(restored.status, CallRequestStatus.declined);
      expect(restored.declineReason, 'Busy that day');
      expect(restored.note, 'Macros review');
      expect(restored.scheduledFor, original.scheduledFor);
    });
  });
}
