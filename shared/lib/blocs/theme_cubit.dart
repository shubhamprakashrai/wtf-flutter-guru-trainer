import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';

import '../services/storage_service.dart';

/// Spec section 15 stretch: light/dark theme toggle, persisted locally so
/// it survives app restart (same session box used for onboarding/login).
class ThemeCubit extends Cubit<ThemeMode> {
  Box get _session => StorageService.box(StorageService.sessionBox);

  ThemeCubit() : super(ThemeMode.system) {
    final saved = _session.get('themeMode') as String?;
    if (saved != null) {
      emit(ThemeMode.values.firstWhere((m) => m.name == saved, orElse: () => ThemeMode.system));
    }
  }

  void toggle() {
    final next = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    _session.put('themeMode', next.name);
    emit(next);
  }
}
