import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../utils/app_logger.dart';

/// Spec section 15 stretch: "Push notifications (local scheduled for
/// reminder)". Schedules a local notification 10 minutes before an
/// approved call's scheduledFor - no server-side push infra needed since
/// this fires entirely on-device.
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _plugin.initialize(settings);
    _initialized = true;
  }

  static Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Deterministic notification id derived from the CallRequest id, so
  /// [cancelReminder] can target the same alarm without persisting a
  /// separate id mapping.
  static int _idFor(String callRequestId) => callRequestId.hashCode & 0x7fffffff;

  static Future<void> scheduleCallReminder({
    required String callRequestId,
    required DateTime scheduledFor,
    required String title,
    required String body,
  }) async {
    final reminderTime = scheduledFor.subtract(const Duration(minutes: 10));
    if (reminderTime.isBefore(DateTime.now())) {
      AppLogger.instance.log(LogTag.schedule, 'skip reminder for $callRequestId - already within 10 min');
      return;
    }
    try {
      await _plugin.zonedSchedule(
        _idFor(callRequestId),
        title,
        body,
        tz.TZDateTime.from(reminderTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'call_reminders',
            'Call Reminders',
            channelDescription: 'Reminds you 10 minutes before a scheduled call.',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      AppLogger.instance.log(LogTag.schedule, 'reminder scheduled for $callRequestId at $reminderTime');
    } catch (e) {
      // Local-first stretch feature - a scheduling failure (e.g. missing
      // permission) should never block the actual call approval flow.
      AppLogger.instance.log(LogTag.schedule, 'reminder scheduling failed: $e');
    }
  }

  static Future<void> cancelReminder(String callRequestId) async {
    await _plugin.cancel(_idFor(callRequestId));
  }
}
