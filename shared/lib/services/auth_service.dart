import 'package:hive/hive.dart';

import '../models/app_user.dart';
import '../utils/app_logger.dart';
import '../utils/seed_data.dart';
import 'storage_service.dart';

/// Mock auth: no network calls, just a locally persisted "current user".
/// Reinstalling the app clears Hive's app storage, so onboarding/login shows
/// again automatically per the acceptance criteria.
class AuthService {
  Box get _users => StorageService.box(StorageService.usersBox);
  Box get _session => StorageService.box(StorageService.sessionBox);

  AppUser? get currentUser {
    final id = _session.get('currentUserId') as String?;
    if (id == null) return null;
    final json = _users.get(id);
    if (json == null) return null;
    return AppUser.fromJson(Map<String, dynamic>.from(json as Map));
  }

  bool get hasCompletedOnboarding => _session.get('onboardingDone') as bool? ?? false;

  Future<void> completeOnboarding() async {
    await _session.put('onboardingDone', true);
  }

  Future<AppUser> createMember({required String name, required String trainerId}) async {
    final user = AppUser(
      id: SeedData.memberId,
      role: UserRole.member,
      name: name,
      email: SeedData.member.email,
      avatarUrl: SeedData.member.avatarUrl,
      assignedTrainerId: trainerId,
    );
    await _users.put(user.id, user.toJson());
    await _session.put('currentUserId', user.id);
    await ensureTrainerSeeded();
    AppLogger.instance.log(LogTag.auth, 'member profile created: ${user.name}');
    return user;
  }

  Future<AppUser> loginAsTrainer() async {
    await ensureTrainerSeeded();
    await ensureMemberSeeded();
    await _session.put('currentUserId', SeedData.trainerId);
    AppLogger.instance.log(LogTag.auth, 'trainer logged in: ${SeedData.trainer.name}');
    return SeedData.trainer;
  }

  Future<void> ensureTrainerSeeded() async {
    if (_users.get(SeedData.trainerId) == null) {
      await _users.put(SeedData.trainerId, SeedData.trainer.toJson());
    }
  }

  Future<void> ensureMemberSeeded() async {
    if (_users.get(SeedData.memberId) == null) {
      await _users.put(SeedData.memberId, SeedData.member.toJson());
    }
  }

  AppUser? getUser(String id) {
    final json = _users.get(id);
    if (json == null) return null;
    return AppUser.fromJson(Map<String, dynamic>.from(json as Map));
  }

  List<AppUser> membersOf(String trainerId) {
    return _users.values
        .map((v) => AppUser.fromJson(Map<String, dynamic>.from(v as Map)))
        .where((u) => u.role == UserRole.member && u.assignedTrainerId == trainerId)
        .toList();
  }

  Future<void> logout() async {
    await _session.delete('currentUserId');
  }
}
