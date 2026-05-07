/// 추가 업무(Additional Task) API 서비스
///
/// 배정된 추가 업무 목록 조회, 상세 조회, 완료 처리, 증빙 첨부 API를 호출.
/// 엔드포인트: /app/my/additional-tasks/*
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';
import 'api_client.dart';

/// 추가 업무 서비스 Provider
final taskServiceProvider = Provider<TaskService>((ref) {
  return TaskService(ref.read(dioProvider));
});

/// 추가 업무 API 서비스 클래스
class TaskService {
  final Dio _dio;

  TaskService(this._dio);

  /// 내 추가 업무 목록 조회 — 상태 필터 지원
  ///
  /// [status]: pending/in_progress/completed 등으로 필터링.
  /// 응답 형식이 배열 또는 { items/data: [...] } 모두 대응.
  Future<List<AdditionalTask>> getMyTasks({String? status}) async {
    final params = <String, dynamic>{};
    if (status != null) params['status'] = status;

    final response = await _dio.get('/app/my/additional-tasks', queryParameters: params);
    final list = response.data is List ? response.data : response.data['items'] ?? response.data['data'] ?? [];
    return (list as List).map((e) => AdditionalTask.fromJson(e)).toList();
  }

  /// 추가 업무 상세 조회 — 담당자, 라벨 등 포함
  Future<AdditionalTask> getTask(String id) async {
    final response = await _dio.get('/app/my/additional-tasks/$id');
    return AdditionalTask.fromJson(response.data);
  }

  /// 추가 업무 완료 처리 — PATCH로 상태를 completed로 변경
  Future<void> completeTask(String id) async {
    await _dio.patch('/app/my/additional-tasks/$id/complete');
  }

  /// 추가 업무에 증빙(사진/파일) 첨부
  ///
  /// [fileUrl]: 업로드된 파일의 URL (StorageService로 사전 업로드)
  /// [fileType]: 파일 유형 (기본: photo)
  /// [note]: 증빙에 대한 메모 (선택)
  Future<void> addEvidence(String taskId, {required String fileUrl, String fileType = 'photo', String? note}) async {
    await _dio.post('/app/my/additional-tasks/$taskId/evidences', data: {
      'file_url': fileUrl,
      'file_type': fileType,
      if (note != null) 'note': note,
    });
  }
}
