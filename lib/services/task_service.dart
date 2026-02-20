import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';
import '../config/constants.dart';
import '../models/task.dart';
import 'mock_services.dart';

final taskServiceProvider = Provider<TaskService>((ref) {
  if (AppConstants.useMock) return MockTaskService();
  return TaskService(ref.read(dioProvider));
});

class TaskService {
  final Dio _dio;
  TaskService(this._dio);

  Future<List<AdditionalTask>> getMyTasks({String? status}) async {
    final response = await _dio.get('/app/my/additional-tasks', queryParameters: {
      if (status != null) 'status': status,
    });
    final items = response.data['items'] ?? response.data;
    return (items as List).map((e) => AdditionalTask.fromJson(e)).toList();
  }

  Future<AdditionalTask> getTask(String id) async {
    final response = await _dio.get('/app/my/additional-tasks/$id');
    return AdditionalTask.fromJson(response.data);
  }

  Future<void> completeTask(String id) async {
    await _dio.patch('/app/my/additional-tasks/$id/complete');
  }
}
