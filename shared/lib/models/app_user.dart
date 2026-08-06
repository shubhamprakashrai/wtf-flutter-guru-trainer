enum UserRole { trainer, member }

UserRole userRoleFromString(String value) =>
    UserRole.values.firstWhere((e) => e.name == value, orElse: () => UserRole.member);

class AppUser {
  final String id;
  final UserRole role;
  final String name;
  final String email;
  final String? avatarUrl;
  final String? assignedTrainerId;

  const AppUser({
    required this.id,
    required this.role,
    required this.name,
    required this.email,
    this.avatarUrl,
    this.assignedTrainerId,
  });

  AppUser copyWith({
    String? id,
    UserRole? role,
    String? name,
    String? email,
    String? avatarUrl,
    String? assignedTrainerId,
  }) {
    return AppUser(
      id: id ?? this.id,
      role: role ?? this.role,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      assignedTrainerId: assignedTrainerId ?? this.assignedTrainerId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.name,
        'name': name,
        'email': email,
        'avatarUrl': avatarUrl,
        'assignedTrainerId': assignedTrainerId,
      };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        role: userRoleFromString(json['role'] as String),
        name: json['name'] as String,
        email: json['email'] as String,
        avatarUrl: json['avatarUrl'] as String?,
        assignedTrainerId: json['assignedTrainerId'] as String?,
      );
}
