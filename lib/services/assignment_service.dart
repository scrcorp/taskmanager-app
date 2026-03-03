import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/assignment.dart';
import 'api_client.dart';

final assignmentServiceProvider = Provider<AssignmentService>((ref) {
  return AssignmentService(ref.read(dioProvider));
});

class AssignmentService {
  final Dio _dio;

  AssignmentService(this._dio);

  Future<List<Assignment>> getMyAssignments({String? workDate, String? status}) async {
    final params = <String, dynamic>{};
    if (workDate != null) params['work_date'] = workDate;
    if (status != null) params['status'] = status;

    final response = await _dio.get('/app/my/work-assignments', queryParameters: params);
    final list = response.data is List ? response.data : response.data['items'] ?? response.data['data'] ?? [];
    return (list as List).map((e) => Assignment.fromJson(e)).toList();
  }

  Future<Assignment> getAssignment(String id) async {
    final response = await _dio.get('/app/my/work-assignments/$id');
    return Assignment.fromJson(response.data);
  }

  Future<PaginatedAssignments> getPastAssignments({
    required String dateTo,
    String? dateFrom,
    int page = 1,
    int perPage = 20,
  }) async {
    final params = <String, dynamic>{
      'date_to': dateTo,
      'page': page,
      'per_page': perPage,
    };
    if (dateFrom != null) params['date_from'] = dateFrom;

    final response = await _dio.get('/app/my/work-assignments', queryParameters: params);
    return PaginatedAssignments.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> toggleChecklistItem(
    String assignmentId,
    int itemIndex,
    bool isCompleted, {
    String timezone = 'America/Los_Angeles',
    String? photoUrl,
    String? note,
  }) async {
    await _dio.patch('/app/my/work-assignments/$assignmentId/checklist/$itemIndex', data: {
      'is_completed': isCompleted,
      'timezone': timezone,
      if (photoUrl != null) 'photo_url': photoUrl,
      if (note != null) 'note': note,
    });
  }

  Future<void> respondToRejection(
    String assignmentId,
    int itemIndex, {
    String? responseComment,
    String? photoUrl,
    String timezone = 'America/Los_Angeles',
  }) async {
    await _dio.patch('/app/my/work-assignments/$assignmentId/checklist/$itemIndex/respond', data: {
      'timezone': timezone,
      if (responseComment != null) 'response_comment': responseComment,
      if (photoUrl != null) 'photo_url': photoUrl,
    });
  }
}
