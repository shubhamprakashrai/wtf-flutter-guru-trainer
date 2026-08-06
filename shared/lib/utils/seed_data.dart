import '../models/app_user.dart';

/// Fixed IDs so both apps (running as separate processes/storage) agree on
/// who "DK" and "Aarav" are without needing a real auth backend.
class SeedData {
  static const trainerId = 'trainer_aarav';
  static const memberId = 'member_dk';

  static const trainer = AppUser(
    id: trainerId,
    role: UserRole.trainer,
    name: 'Aarav (Lead Trainer)',
    email: 'aarav@wtf.fit',
    avatarUrl: 'https://api.dicebear.com/9.x/avataaars/png?seed=Aarav',
  );

  static const member = AppUser(
    id: memberId,
    role: UserRole.member,
    name: 'DK',
    email: 'dk@wtf.fit',
    avatarUrl: 'https://api.dicebear.com/9.x/avataaars/png?seed=DK',
    assignedTrainerId: trainerId,
  );
}
