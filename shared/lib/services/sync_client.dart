import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../utils/app_logger.dart';

/// Local-first realtime relay. Both apps connect to the same tiny WebSocket
/// server (see token_server/server.js) running on the dev machine so chat
/// messages and call-request updates propagate between the two apps without
/// any cloud backend. See HmsConfig for why every platform just uses
/// "localhost" (Android needs `adb reverse tcp:8090 tcp:8090` for this to
/// resolve, whether it's an emulator or a physical device).
class SyncClient {
  SyncClient._();
  static final SyncClient instance = SyncClient._();

  static const defaultHost = 'localhost';

  WebSocketChannel? _channel;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  bool _stopped = false;
  bool _connected = false;

  Stream<Map<String, dynamic>> get events => _controller.stream;
  bool get isConnected => _connected;

  Future<void> connect({String? host, int port = 8090}) async {
    _stopped = false;
    _connect(host ?? defaultHost, port);
  }

  void _connect(String host, int port) {
    if (_stopped) return;
    try {
      final channel = WebSocketChannel.connect(Uri.parse('ws://$host:$port'));
      _channel = channel;
      channel.stream.listen(
        (raw) {
          _connected = true;
          try {
            final data = jsonDecode(raw as String) as Map<String, dynamic>;
            _controller.add(data);
          } catch (_) {}
        },
        onDone: () => _scheduleReconnect(host, port),
        onError: (_) => _scheduleReconnect(host, port),
        cancelOnError: true,
      );
      _connected = true;
      AppLogger.instance.log(LogTag.chat, 'sync connected to $host:$port');
    } catch (e) {
      AppLogger.instance.log(LogTag.chat, 'sync connect failed: $e');
      _scheduleReconnect(host, port);
    }
  }

  void _scheduleReconnect(String host, int port) {
    if (_stopped) return;
    _connected = false;
    Timer(const Duration(seconds: 2), () => _connect(host, port));
  }

  void send(Map<String, dynamic> event) {
    try {
      _channel?.sink.add(jsonEncode(event));
    } catch (e) {
      AppLogger.instance.log(LogTag.chat, 'sync send failed: $e');
    }
  }

  void dispose() {
    _stopped = true;
    _channel?.sink.close();
  }
}
