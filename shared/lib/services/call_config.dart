/// Points at the local token_server (see token_server/README.md).
///
/// Every platform (including Android, emulator or physical device) reaches
/// it via plain "localhost". For a real Android device that only works
/// because the dev machine forwards its port over USB with:
///   adb reverse tcp:8090 tcp:8090
/// (an Android emulator would also work via the 10.0.2.2 alias without
/// this, but using `adb reverse` uniformly means the same code path works
/// for both emulator and physical-device runs.)
class CallConfig {
  static String get tokenServerBaseUrl => 'http://localhost:8090';

  /// Single persistent dev room shared by all approved calls - this is a
  /// common shortcut for dev/take-home projects instead of provisioning a
  /// new room per call. See ARCHITECTURE.md "Video calling (LiveKit)" for
  /// the rationale.
  static const devRoomId = 'wtf-dev-room';
}
