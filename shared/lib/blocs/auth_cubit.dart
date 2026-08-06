import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';

class AuthState {
  final bool onboarded;
  final AppUser? user;
  const AuthState({required this.onboarded, this.user});
}

/// Wraps [AuthService] (mock auth, no network) so screens react to
/// onboarding/login via BlocBuilder instead of polling Hive directly.
class AuthCubit extends Cubit<AuthState> {
  final AuthService authService;

  AuthCubit(this.authService)
      : super(AuthState(onboarded: authService.hasCompletedOnboarding, user: authService.currentUser));

  Future<void> createMember({required String name, required String trainerId}) async {
    final user = await authService.createMember(name: name, trainerId: trainerId);
    await authService.completeOnboarding();
    emit(AuthState(onboarded: true, user: user));
  }

  Future<void> loginAsTrainer() async {
    final user = await authService.loginAsTrainer();
    await authService.completeOnboarding();
    emit(AuthState(onboarded: true, user: user));
  }

  void logout() {
    authService.logout();
    emit(const AuthState(onboarded: true, user: null));
  }
}
