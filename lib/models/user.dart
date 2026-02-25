class User {
  final String id;
  final String organizationId;
  final String roleId;
  final String username;
  final String email;
  final String? firstName;
  final String? lastName;
  final bool isActive;
  final String? roleName;
  final int? roleLevel;
  final DateTime? createdAt;

  const User({
    required this.id,
    required this.organizationId,
    required this.roleId,
    required this.username,
    required this.email,
    this.firstName,
    this.lastName,
    this.isActive = true,
    this.roleName,
    this.roleLevel,
    this.createdAt,
  });

  String get fullName {
    if (firstName != null && lastName != null) return '$firstName $lastName';
    if (firstName != null) return firstName!;
    if (lastName != null) return lastName!;
    return username;
  }

  String get initials {
    if (firstName != null && lastName != null) {
      return '${firstName![0]}${lastName![0]}'.toUpperCase();
    }
    return username.substring(0, 2).toUpperCase();
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      organizationId: json['organization_id'] ?? '',
      roleId: json['role_id'] ?? '',
      username: json['username'],
      email: json['email'] ?? '',
      firstName: json['first_name'],
      lastName: json['last_name'],
      isActive: json['is_active'] ?? true,
      roleName: json['role_name'] ?? json['role']?['name'],
      roleLevel: json['role_level'] ?? json['role']?['level'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }

  User copyWith({
    String? firstName,
    String? lastName,
    String? email,
  }) {
    return User(
      id: id,
      organizationId: organizationId,
      roleId: roleId,
      username: username,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      isActive: isActive,
      roleName: roleName,
      roleLevel: roleLevel,
      createdAt: createdAt,
    );
  }
}
