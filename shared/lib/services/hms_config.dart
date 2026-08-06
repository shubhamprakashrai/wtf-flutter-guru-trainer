import 'dart:io' show Platform;

/// Points at the local token_server (see token_server/README.md).
/// Android emulator can't resolve the host machine's "localhost", hence the
/// 10.0.2.2 special alias; other platforms use localhost directly.
class HmsConfig {
  static String get tokenServerBaseUrl {
    final host = !Platform.isAndroid ? 'localhost' : '10.0.2.2';
    return 'http://$host:8090';
  }

  /// Single persistent dev room shared by all approved calls - this is the
  /// 100ms-recommended shortcut for take-home/dev projects instead of
  /// provisioning a new room per call via the Management API. See
  /// ARCHITECTURE.md "100ms integration" for the rationale.
  static const devRoomId = 'wtf-dev-room';
}
