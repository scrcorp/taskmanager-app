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

  Future<List<AdditionalTask>> getMyTasks({String? status}) async {
    final params = <String, dynamic>{};
    if (status != null) params['status'] = status;

    final response = await _dio.get('/app/my/tasks', queryParameters: params);
    final list = response.data is List ? response.data : response.data['items'] ?? response.data['data'] ?? [];
    return (list as List).map((e) => AdditionalTask.fromJson(e)).toList();
  }

  Future<AdditionalTask> getTask(String id) async {
    final response = await _dio.get('/app/my/tasks/$id');
    return AdditionalTask.fromJson(response.data);
  }

  Future<void> completeTask(String id) async {
    await _dio.post('/app/my/tasks/$id/complete');
  }

  Future<void> addComment(String taskId, {required String text, String? imageUrl}) async {
    await _dio.post('/app/my/tasks/$taskId/comments', data: {
      'text': text,
      if (imageUrl != null) 'image_url': imageUrl,
    });
  }
}
