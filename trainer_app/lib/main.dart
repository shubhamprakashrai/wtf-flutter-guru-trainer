import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared/shared.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    // LiveKit's Room fires some internal events asynchronously after
    // disconnect()/dispose() (e.g. a stray participant-update wait timing
    // out during teardown) - harmless, but log it instead of letting it
    // surface as a red console error.
    FlutterError.onError = (details) {
      AppLogger.instance.log(LogTag.rtc, 'FlutterError: ${details.exceptionAsString()}');
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      AppLogger.instance.log(LogTag.rtc, 'Uncaught: $error');
      return true;
    };

    await StorageService.init();
    SyncClient.instance.connect();
    final services = AppServices();
    services.startListening();
    runApp(TrainerApp(services: services));
  }, (error, stack) {
    AppLogger.instance.log(LogTag.rtc, 'Uncaught (zone): $error');
  });
}

class TrainerApp extends StatelessWidget {
  final AppServices services;
  const TrainerApp({super.key, required this.services});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<AppServices>.value(
      value: services,
      child: BlocProvider<AuthCubit>(
        create: (_) => AuthCubit(services.auth),
        child: MaterialApp(
          title: 'Trainer App',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(const Color(0xFFE50914)),
          home: BlocBuilder<AuthCubit, AuthState>(
            builder: (context, state) {
              if (!state.onboarded || state.user == null) {
                return const LoginScreen();
              }
              return const HomeScreen();
            },
          ),
        ),
      ),
    );
  }
}
