import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';
import '../config/constants.dart';
import '../models/assignment.dart';
import 'mock_services.dart';

final assignmentServiceProvider = Provider<AssignmentService>((ref) {
  if (AppConstants.useMock) return MockAssignmentService();
  return AssignmentService(ref.read(dioProvider));
});

class AssignmentService {
  final Dio _dio;
  AssignmentService(this._dio);

  Future<List<Assignment>> getMyAssignments({String? workDate, String? status}) async {
    final response = await _dio.get('/app/my/work-assignments', queryParameters: {
      if (workDate != null) 'work_date': workDate,
      if (status != null) 'status': status,
    });
    final items = response.data is List ? response.data : (response.data['items'] ?? []);
    return (items as List).map((e) => Assignment.fromJson(e)).toList();
  }

  Future<Assignment> getAssignment(String id) async {
    final response = await _dio.get('/app/my/work-assignments/$id');
    return Assignment.fromJson(response.data);
  }

  Future<void> toggleChecklistItem(String assignmentId, int itemIndex, bool isCompleted) async {
    final timezone = DateTime.now().timeZoneName; // e.g. "PST", "KST"
    // IANA timezone from device locale
    final ianaTimezone = _getIanaTimezone();
    await _dio.patch('/app/my/work-assignments/$assignmentId/checklist/$itemIndex', data: {
      'is_completed': isCompleted,
      'timezone': ianaTimezone,
    });
  }

  /// Best-effort IANA timezone from device UTC offset.
  String _getIanaTimezone() {
    final offset = DateTime.now().timeZoneOffset;
    // Common offset-to-IANA mapping for this app's use case
    const offsetMap = {
      -8: 'America/Los_Angeles',
      -7: 'America/Los_Angeles', // PDT
      -5: 'America/New_York',
      -4: 'America/New_York', // EDT
      9: 'Asia/Seoul',
      0: 'UTC',
    };
    return offsetMap[offset.inHours] ?? 'America/Los_Angeles';
  }
}
