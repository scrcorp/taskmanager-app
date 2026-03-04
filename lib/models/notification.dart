/// 앱 알림(Notification) 데이터 모델
///
/// 서버에서 발생하는 알림(근무배정, 업무, 공지 등)을 표현.
/// referenceType/referenceId로 관련 리소스로의 네비게이션을 지원한다.
class AppNotification {
  final String id;
  /// 알림 유형 (예: 'assignment_created', 'task_assigned' 등)
  final String type;
  /// 사용자에게 표시할 알림 메시지
  final String message;
  /// 참조 리소스 유형 (예: 'work_assignment', 'additional_task', 'announcement')
  final String? referenceType;
  /// 참조 리소스 ID (해당 화면으로 이동 시 사용)
  final String? referenceId;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.message,
    this.referenceType,
    this.referenceId,
    this.isRead = false,
    required this.createdAt,
  });

  /// 서버 JSON → AppNotification 객체 변환
  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'],
      type: json['type'],
      message: json['message'] ?? '',
      referenceType: json['reference_type'],
      referenceId: json['reference_id'],
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
