import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared/shared.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();
  SyncClient.instance.connect();
  final services = AppServices();
  services.startListening();
  runApp(TrainerApp(services: services));
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
