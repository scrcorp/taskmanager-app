/// 사용자(User) 데이터 모델
///
/// /auth/me 응답으로 받는 현재 로그인 사용자 정보.
/// 역할(role), 조직(organization), 회사코드(companyCode) 등을 포함.
/// roleLevel: Owner=10, GM=20, SV=30, Staff=40 (10단위 간격)
class User {
  final String id;
  final String organizationId;
  final String username;
  final String fullName;
  final String? email;
  final bool isActive;
  final String roleName;
  /// 역할 우선순위 레벨 (낮을수록 높은 권한: Owner=10, Staff=40)
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

  /// fullName에서 첫 단어만 추출 (인사말 등에 사용)
  String get firstName => fullName.split(' ').first;

  /// 이니셜 생성 (프로필 아바타에 표시)
  /// 예: "John Doe" → "JD", "Alice" → "AL"
  String get initials {
    if (fullName.isNotEmpty) {
      final parts = fullName.split(' ');
      if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      return fullName.substring(0, fullName.length >= 2 ? 2 : 1).toUpperCase();
    }
    return username.substring(0, 2).toUpperCase();
  }

  /// 서버 JSON → User 객체 변환
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String? ?? '',
      username: json['username'] as String,
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      roleName: json['role_name'] as String? ?? '',
      roleLevel: json['role_priority'] as int? ?? json['role_level'] as int? ?? 40,
      organizationName: json['organization_name'] as String? ?? '',
      companyCode: json['company_code'] as String? ?? '',
    );
  }
}
