/// Task (work item) API 서비스 — staff (직원) 용.
///
/// 명칭 변경 이력: additional_tasks → issues → tasks.
/// 엔드포인트: /app/my/tasks/*
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';
import 'api_client.dart';

final taskServiceProvider = Provider<TaskService>((ref) {
  return TaskService(ref.read(dioProvider));
});

class TaskService {
  final Dio _dio;

  TaskService(this._dio);

  /// 내 task 목록 조회 — 상태 필터 지원.
  Future<List<AdditionalTask>> getMyTasks({String? status}) async {
    final params = <String, dynamic>{};
    if (status != null) params['status'] = status;

    final response = await _dio.get('/app/my/tasks', queryParameters: params);
    final list = response.data is List
        ? response.data
        : response.data['items'] ?? response.data['data'] ?? [];
    return (list as List).map((e) => AdditionalTask.fromJson(e)).toList();
  }

  /// task 상세 조회.
  Future<AdditionalTask> getTask(String id) async {
    final response = await _dio.get('/app/my/tasks/$id');
    return AdditionalTask.fromJson(response.data);
  }

  /// task 완료 처리 — status 를 completed 로 변경 (legacy 호환).
  Future<void> completeTask(String id) async {
    await _dio.put('/app/my/tasks/$id', data: {'status': 'completed'});
  }

  /// 상태 전이 (Start → In Progress / Submit → Under review).
  /// comment + attachments 동봉 가능 (특히 Submit 시 보고용).
  Future<AdditionalTask> transition(
    String id, {
    required String status,
    String? comment,
    List<Map<String, dynamic>>? attachments,
  }) async {
    final body = <String, dynamic>{'status': status};
    if (comment != null && comment.isNotEmpty) body['comment'] = comment;
    if (attachments != null) body['attachments'] = attachments;
    final response = await _dio.post('/app/my/tasks/$id/transition', data: body);
    return AdditionalTask.fromJson(response.data);
  }

  /// task 댓글 목록 조회.
  Future<List<TaskCommentItem>> listComments(String id) async {
    final response = await _dio.get('/app/my/tasks/$id/comments');
    return (response.data as List)
        .map((e) => TaskCommentItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// task 댓글 작성 (텍스트 + 옵션 첨부).
  Future<TaskCommentItem> addComment(
    String id, {
    required String content,
    List<Map<String, dynamic>>? attachments,
  }) async {
    final body = <String, dynamic>{
      'content': content,
      if (attachments != null) 'attachments': attachments,
    };
    final response =
        await _dio.post('/app/my/tasks/$id/comments', data: body);
    return TaskCommentItem.fromJson(response.data as Map<String, dynamic>);
  }
}
