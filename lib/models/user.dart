class User {
  final String id;
  final String organizationId;
  final String username;
  final String fullName;
  final String? email;
  final bool isActive;
  final String roleName;
  final int roleLevel;
  final String organizationName;
  final String companyCode;

  const User({
    required this.id,
    required this.organizationId,
    required this.username,
    required this.fullName,
    this.email,
    this.isActive = true,
    required this.roleName,
    required this.roleLevel,
    required this.organizationName,
    required this.companyCode,
  });

  String get initials {
    if (fullName.isNotEmpty) {
      final parts = fullName.split(' ');
      if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      return fullName.substring(0, fullName.length >= 2 ? 2 : 1).toUpperCase();
    }
    return username.substring(0, 2).toUpperCase();
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String? ?? '',
      username: json['username'] as String,
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      roleName: json['role_name'] as String? ?? '',
      roleLevel: json['role_level'] as int? ?? 40,
      organizationName: json['organization_name'] as String? ?? '',
      companyCode: json['company_code'] as String? ?? '',
    );
  }
}
