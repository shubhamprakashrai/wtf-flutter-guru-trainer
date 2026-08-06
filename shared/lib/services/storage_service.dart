import 'package:hive_flutter/hive_flutter.dart';

/// Thin wrapper around Hive box init. Models are stored as plain
/// `Map<String,dynamic>` (via each model's toJson/fromJson) so no generated
/// TypeAdapters are needed - keeps the build fast and dependency-free.
class StorageService {
  static const usersBox = 'users_box';
  static const sessionBox = 'session_box'; // current logged-in user id, onboarding flag
  static const messagesBox = 'messages_box';
  static const callRequestsBox = 'call_requests_box';
  static const roomMetaBox = 'room_meta_box';
  static const sessionLogsBox = 'session_logs_box';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Future.wait([
      Hive.openBox(usersBox),
      Hive.openBox(sessionBox),
      Hive.openBox(messagesBox),
      Hive.openBox(callRequestsBox),
      Hive.openBox(roomMetaBox),
      Hive.openBox(sessionLogsBox),
    ]);
  }

  static Box box(String name) => Hive.box(name);
}
