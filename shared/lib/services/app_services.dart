import 'auth_service.dart';
import 'call_service.dart';
import 'chat_service.dart';
import 'log_service.dart';

/// Bundles the four service singletons an app needs. Injected once at the
/// widget-tree root via flutter_bloc's RepositoryProvider and read by Cubits
/// (see shared/lib/blocs/) - see DECISIONS.md for why plain services +
/// Cubits instead of a heavier data layer.
class AppServices {
  final auth = AuthService();
  final chat = ChatService();
  final call = CallService();
  final log = LogService();

  void startListening() {
    chat.listen();
    call.listen();
    log.listen();
  }

  void dispose() {
    chat.dispose();
    call.dispose();
    log.dispose();
  }
}
