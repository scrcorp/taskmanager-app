/// 매장 Manager/SV 1명 — early clock-in "누가 불렀나" 선택지 (계약 §4).
///
/// POST /attendance/store-managers (device token + PIN 게이트) 응답 1건.
/// 서버는 `user_id / full_name / role_name / role_priority` 만 내려준다 —
/// 연락처·PIN·시급은 이 화면에 절대 오지 않는다.
///
/// 동명이인이 있을 수 있어 목록에는 role_name 을 함께 보여준다.
class StoreManagerOption {
  final String userId;
  final String fullName;
  final String roleName;
  final int rolePriority;

  const StoreManagerOption({
    required this.userId,
    required this.fullName,
    required this.roleName,
    required this.rolePriority,
  });

  factory StoreManagerOption.fromJson(Map<String, dynamic> json) {
    return StoreManagerOption(
      userId: json['user_id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      roleName: json['role_name']?.toString() ?? '',
      rolePriority: (json['role_priority'] as num?)?.toInt() ?? 0,
    );
  }
}
