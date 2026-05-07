/// 매장(Store) 데이터 모델
///
/// 조직(Organization) 하위의 개별 매장 정보를 표현한다.
/// Admin UI에서는 "Brand"로 표시되며, 근무배정/공지 등의 범위 지정에 사용.
class Store {
  final String id;
  final String name;
  final String? address;
  final bool isActive;
  final String? timezone;
  final Map<String, String>? dayStartTime;

  const Store({
    required this.id,
    required this.name,
    this.address,
    this.isActive = true,
    this.timezone,
    this.dayStartTime,
  });

  /// 서버 JSON → Store 객체 변환
  factory Store.fromJson(Map<String, dynamic> json) {
    return Store(
      id: json['id'],
      name: json['name'],
      address: json['address'],
      isActive: json['is_active'] ?? true,
      timezone: json['timezone'],
      dayStartTime: json['day_start_time'] != null
          ? Map<String, String>.from(json['day_start_time'])
          : null,
    );
  }
}
