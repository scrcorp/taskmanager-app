/// Mock Dio Interceptor — 서버 없이 UI 테스트용
///
/// 사용법: api_client.dart에서 AuthInterceptor 대신 MockInterceptor 등록
/// dio.interceptors.add(MockInterceptor());
import 'package:dio/dio.dart';

class MockInterceptor extends Interceptor {
  // 신청 데이터 (제출/수정/삭제 시뮬레이션용)
  final List<Map<String, dynamic>> _requests = [
    {'id': 'r1', 'user_id': 'u1', 'store_id': 's1', 'store_name': 'Bean & Brew', 'work_role_id': 'wr1', 'work_role_name': 'AM·Barista', 'work_date': '2026-03-12', 'preferred_start_time': '09:00', 'preferred_end_time': '17:00', 'note': '', 'status': 'modified', 'submitted_at': '2026-03-05T10:00:00Z', 'created_at': '2026-03-05T10:00:00Z', 'original_start_time': '09:00', 'original_end_time': '17:00', 'modified_start_time': '09:00', 'modified_end_time': '13:00'},
    {'id': 'r2', 'user_id': 'u1', 'store_id': 's1', 'store_name': 'Bean & Brew', 'work_role_id': 'wr2', 'work_role_name': 'PM·Grill', 'work_date': '2026-03-08', 'preferred_start_time': '14:00', 'preferred_end_time': '22:00', 'note': 'Please match my hours', 'status': 'rejected', 'submitted_at': '2026-03-04T08:00:00Z', 'created_at': '2026-03-04T08:00:00Z', 'rejected_reason': 'Overstaffed for that time slot'},
    {'id': 'r3', 'user_id': 'u1', 'store_id': 's1', 'store_name': 'Bean & Brew', 'work_role_id': 'wr1', 'work_role_name': 'AM·Barista', 'work_date': '2026-03-16', 'preferred_start_time': '09:00', 'preferred_end_time': '17:00', 'note': '', 'status': 'submitted', 'submitted_at': '2026-03-08T10:00:00Z', 'created_at': '2026-03-08T10:00:00Z'},
    {'id': 'r4', 'user_id': 'u1', 'store_id': 's2', 'store_name': 'The Pier', 'work_role_id': 'wr3', 'work_role_name': 'AM·Counter', 'work_date': '2026-03-18', 'preferred_start_time': '10:00', 'preferred_end_time': '18:00', 'note': 'Afternoon available too', 'status': 'submitted', 'submitted_at': '2026-03-08T10:05:00Z', 'created_at': '2026-03-08T10:05:00Z'},
    {'id': 'r5', 'user_id': 'u1', 'store_id': 's1', 'store_name': 'Bean & Brew', 'work_role_id': 'wr2', 'work_role_name': 'PM·Grill', 'work_date': '2026-03-20', 'preferred_start_time': '14:00', 'preferred_end_time': '22:00', 'note': '', 'status': 'submitted', 'submitted_at': '2026-03-08T11:00:00Z', 'created_at': '2026-03-08T11:00:00Z'},
    {'id': 'r6', 'user_id': 'u1', 'store_id': 's1', 'store_name': 'Bean & Brew', 'work_role_id': 'wr1', 'work_role_name': 'AM·Barista', 'work_date': '2026-03-21', 'preferred_start_time': '09:00', 'preferred_end_time': '17:00', 'note': '', 'status': 'submitted', 'submitted_at': '2026-03-08T11:30:00Z', 'created_at': '2026-03-08T11:30:00Z'},
  ];

  static const _stores = [
    {'id': 's1', 'name': 'Bean & Brew'},
    {'id': 's2', 'name': 'The Pier'},
  ];

  static const _workRoles = [
    {'id': 'wr1', 'store_id': 's1', 'shift_id': 'sh1', 'shift_name': 'AM', 'position_id': 'p1', 'position_name': 'Barista', 'name': 'AM·Barista', 'default_start_time': '09:00', 'default_end_time': '17:00', 'is_active': true},
    {'id': 'wr2', 'store_id': 's1', 'shift_id': 'sh2', 'shift_name': 'PM', 'position_id': 'p2', 'position_name': 'Grill', 'name': 'PM·Grill', 'default_start_time': '14:00', 'default_end_time': '22:00', 'is_active': true},
    {'id': 'wr3', 'store_id': 's2', 'shift_id': 'sh1', 'shift_name': 'AM', 'position_id': 'p3', 'position_name': 'Counter', 'name': 'AM·Counter', 'default_start_time': '10:00', 'default_end_time': '18:00', 'is_active': true},
  ];

  static const _entries = [
    {'id': 'e1', 'user_id': 'u1', 'store_id': 's1', 'store_name': 'Bean & Brew', 'work_role_name': 'AM·Barista', 'work_date': '2026-03-09', 'start_time': '09:00', 'end_time': '13:00', 'net_work_minutes': 240, 'status': 'approved', 'created_at': '2026-03-01T00:00:00Z'},
    {'id': 'e2', 'user_id': 'u1', 'store_id': 's1', 'store_name': 'Bean & Brew', 'work_role_name': 'AM·Barista', 'work_date': '2026-03-09', 'start_time': '13:30', 'end_time': '17:00', 'net_work_minutes': 210, 'status': 'approved', 'created_at': '2026-03-01T00:00:00Z'},
    {'id': 'e3', 'user_id': 'u1', 'store_id': 's1', 'store_name': 'Bean & Brew', 'work_role_name': 'AM·Barista', 'work_date': '2026-03-10', 'start_time': '09:00', 'end_time': '13:00', 'net_work_minutes': 240, 'status': 'approved', 'created_at': '2026-03-01T00:00:00Z'},
    {'id': 'e4', 'user_id': 'u1', 'store_id': 's1', 'store_name': 'Bean & Brew', 'work_role_name': 'AM·Barista', 'work_date': '2026-03-10', 'start_time': '13:30', 'end_time': '17:00', 'net_work_minutes': 210, 'status': 'approved', 'created_at': '2026-03-01T00:00:00Z'},
    {'id': 'e5', 'user_id': 'u1', 'store_id': 's2', 'store_name': 'The Pier', 'work_role_name': 'AM·Counter', 'work_date': '2026-03-11', 'start_time': '10:00', 'end_time': '14:00', 'net_work_minutes': 240, 'status': 'approved', 'created_at': '2026-03-01T00:00:00Z'},
    {'id': 'e6', 'user_id': 'u1', 'store_id': 's2', 'store_name': 'The Pier', 'work_role_name': 'AM·Counter', 'work_date': '2026-03-11', 'start_time': '14:30', 'end_time': '18:00', 'net_work_minutes': 210, 'status': 'approved', 'created_at': '2026-03-01T00:00:00Z'},
    {'id': 'e7', 'user_id': 'u1', 'store_id': 's1', 'store_name': 'Bean & Brew', 'work_role_name': 'PM·Grill', 'work_date': '2026-03-13', 'start_time': '14:00', 'end_time': '18:00', 'net_work_minutes': 240, 'status': 'approved', 'created_at': '2026-03-01T00:00:00Z'},
    {'id': 'e8', 'user_id': 'u1', 'store_id': 's1', 'store_name': 'Bean & Brew', 'work_role_name': 'PM·Grill', 'work_date': '2026-03-13', 'start_time': '18:30', 'end_time': '22:00', 'net_work_minutes': 210, 'status': 'approved', 'created_at': '2026-03-01T00:00:00Z'},
    {'id': 'e9', 'user_id': 'u1', 'store_id': 's1', 'store_name': 'Bean & Brew', 'work_role_name': 'AM·Barista', 'work_date': '2026-03-14', 'start_time': '09:00', 'end_time': '13:00', 'net_work_minutes': 240, 'status': 'approved', 'created_at': '2026-03-01T00:00:00Z'},
    {'id': 'e10', 'user_id': 'u1', 'store_id': 's1', 'store_name': 'Bean & Brew', 'work_role_name': 'AM·Barista', 'work_date': '2026-03-14', 'start_time': '13:30', 'end_time': '17:00', 'net_work_minutes': 210, 'status': 'approved', 'created_at': '2026-03-01T00:00:00Z'},
  ];

  final List<Map<String, dynamic>> _templates = [
    {
      'id': 't1', 'name': 'Regular Schedule', 'is_default': true,
      'items': [
        {'day_of_week': 0, 'work_role_id': 'wr1', 'work_role_name': 'AM·Barista', 'store_name': 'Bean & Brew', 'preferred_start_time': '09:00', 'preferred_end_time': '17:00'},
        {'day_of_week': 1, 'work_role_id': 'wr1', 'work_role_name': 'AM·Barista', 'store_name': 'Bean & Brew', 'preferred_start_time': '09:00', 'preferred_end_time': '17:00'},
        {'day_of_week': 3, 'work_role_id': 'wr3', 'work_role_name': 'AM·Counter', 'store_name': 'The Pier', 'preferred_start_time': '10:00', 'preferred_end_time': '18:00'},
        {'day_of_week': 5, 'work_role_id': 'wr2', 'work_role_name': 'PM·Grill', 'store_name': 'Bean & Brew', 'preferred_start_time': '14:00', 'preferred_end_time': '22:00'},
      ],
    },
    {
      'id': 't2', 'name': 'Exam Period', 'is_default': false,
      'items': [
        {'day_of_week': 5, 'work_role_id': 'wr2', 'work_role_name': 'PM·Grill', 'store_name': 'Bean & Brew', 'preferred_start_time': '14:00', 'preferred_end_time': '22:00'},
        {'day_of_week': 6, 'work_role_id': 'wr1', 'work_role_name': 'AM·Barista', 'store_name': 'Bean & Brew', 'preferred_start_time': '09:00', 'preferred_end_time': '17:00'},
      ],
    },
  ];

  int _nextId = 100;

  String _genId() => 'mock_${_nextId++}';

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    // 약간의 딜레이로 네트워크 시뮬레이션
    await Future.delayed(const Duration(milliseconds: 200));

    final path = options.path;
    final method = options.method;

    try {
      // GET /app/my/stores
      if (path == '/app/my/stores' && method == 'GET') {
        return handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: _stores,
        ));
      }

      // GET /app/my/work-roles
      if (path == '/app/my/work-roles' && method == 'GET') {
        var roles = _workRoles.toList();
        final storeId = options.queryParameters['store_id'];
        if (storeId != null) {
          roles = roles.where((r) => r['store_id'] == storeId).toList();
        }
        return handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: roles,
        ));
      }

      // GET /app/my/schedule-requests
      if (path == '/app/my/schedule-requests' && method == 'GET') {
        var filtered = _requests.toList();
        final from = options.queryParameters['date_from'];
        final to = options.queryParameters['date_to'];
        if (from != null) {
          filtered = filtered
              .where((r) => r['work_date'].compareTo(from) >= 0)
              .toList();
        }
        if (to != null) {
          filtered = filtered
              .where((r) => r['work_date'].compareTo(to) <= 0)
              .toList();
        }
        return handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: filtered,
        ));
      }

      // POST /app/my/schedule-requests
      if (path == '/app/my/schedule-requests' && method == 'POST') {
        final data = options.data as Map<String, dynamic>;
        final storeId = data['store_id'] as String;
        final storeName = _stores
            .firstWhere((s) => s['id'] == storeId,
                orElse: () => {'name': ''})['name'];
        final wrId = data['work_role_id'] as String?;
        final wrName = wrId != null
            ? _workRoles.firstWhere((w) => w['id'] == wrId,
                orElse: () => {'name': ''})['name']
            : null;
        final newReq = {
          'id': _genId(),
          'user_id': 'u1',
          'store_id': storeId,
          'store_name': storeName,
          'work_role_id': wrId,
          'work_role_name': wrName,
          'work_date': data['work_date'],
          'preferred_start_time': data['preferred_start_time'],
          'preferred_end_time': data['preferred_end_time'],
          'note': data['note'],
          'status': 'submitted',
          'submitted_at': DateTime.now().toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
        };
        _requests.add(newReq);
        return handler.resolve(Response(
          requestOptions: options,
          statusCode: 201,
          data: newReq,
        ));
      }

      // PUT /app/my/schedule-requests/{id}
      if (path.startsWith('/app/my/schedule-requests/') && method == 'PUT') {
        final id = path.split('/').last;
        final idx = _requests.indexWhere((r) => r['id'] == id);
        if (idx >= 0) {
          final data = options.data as Map<String, dynamic>;
          final req = Map<String, dynamic>.from(_requests[idx]);
          data.forEach((k, v) {
            if (v != null) req[k] = v;
          });
          _requests[idx] = req;
          return handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: req,
          ));
        }
      }

      // DELETE /app/my/schedule-requests/{id}
      if (path.startsWith('/app/my/schedule-requests/') &&
          method == 'DELETE') {
        final id = path.split('/').last;
        _requests.removeWhere((r) => r['id'] == id);
        return handler.resolve(Response(
          requestOptions: options,
          statusCode: 204,
          data: null,
        ));
      }

      // GET /app/my/schedule-entries
      if (path == '/app/my/schedule-entries' && method == 'GET') {
        var filtered = _entries.toList();
        final from = options.queryParameters['date_from'];
        final to = options.queryParameters['date_to'];
        if (from != null) {
          filtered = filtered
              .where((e) => e['work_date'].toString().compareTo(from) >= 0)
              .toList();
        }
        if (to != null) {
          filtered = filtered
              .where((e) => e['work_date'].toString().compareTo(to) <= 0)
              .toList();
        }
        return handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: filtered,
        ));
      }

      // GET /app/my/schedule-templates
      if (path == '/app/my/schedule-templates' && method == 'GET') {
        return handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: _templates,
        ));
      }

      // POST /app/my/schedule-templates (create)
      if (path == '/app/my/schedule-templates' && method == 'POST') {
        final body = options.data as Map<String, dynamic>;
        if (body['is_default'] == true) {
          for (final t in _templates) { t['is_default'] = false; }
        }
        final newT = {
          'id': _genId(),
          'name': body['name'],
          'is_default': body['is_default'] ?? false,
          'items': body['items'] ?? [],
        };
        _templates.add(newT);
        return handler.resolve(Response(
          requestOptions: options, statusCode: 201, data: newT,
        ));
      }

      // PUT /app/my/schedule-templates/:id (update)
      if (path.startsWith('/app/my/schedule-templates/') && method == 'PUT') {
        final id = path.split('/').last;
        final body = options.data as Map<String, dynamic>;
        final idx = _templates.indexWhere((t) => t['id'] == id);
        if (idx >= 0) {
          if (body['is_default'] == true) {
            for (final t in _templates) { t['is_default'] = false; }
          }
          _templates[idx] = {
            'id': id,
            'name': body['name'] ?? _templates[idx]['name'],
            'is_default': body['is_default'] ?? _templates[idx]['is_default'],
            'items': body['items'] ?? _templates[idx]['items'],
          };
          return handler.resolve(Response(
            requestOptions: options, statusCode: 200, data: _templates[idx],
          ));
        }
      }

      // DELETE /app/my/schedule-templates/:id
      if (path.startsWith('/app/my/schedule-templates/') && method == 'DELETE') {
        final id = path.split('/').last;
        _templates.removeWhere((t) => t['id'] == id);
        return handler.resolve(Response(
          requestOptions: options, statusCode: 204,
        ));
      }

      // POST /app/auth/login
      if (path == '/app/auth/login' && method == 'POST') {
        return handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            'access_token': 'mock_access_token',
            'refresh_token': 'mock_refresh_token',
          },
        ));
      }

      // GET /auth/me
      if (path == '/auth/me' && method == 'GET') {
        return handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            'id': 'u1',
            'organization_id': 'org1',
            'username': 'alex',
            'full_name': 'Alex Kim',
            'email': 'alex@example.com',
            'is_active': true,
            'role_name': 'Staff',
            'role_level': 40,
            'organization_name': 'Demo Org',
            'company_code': 'MOCK01',
          },
        ));
      }

      // POST /auth/logout
      if (path == '/auth/logout' && method == 'POST') {
        return handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: {'message': 'logged out'},
        ));
      }

      // POST /auth/refresh
      if (path == '/auth/refresh' && method == 'POST') {
        return handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            'access_token': 'mock_access_token_refreshed',
            'refresh_token': 'mock_refresh_token',
          },
        ));
      }
    } catch (e) {
      return handler.reject(
        DioException(requestOptions: options, message: 'Mock error: $e'),
      );
    }

    // 매칭 안 되면 404
    handler.resolve(Response(
      requestOptions: options,
      statusCode: 404,
      data: {'detail': 'Mock: endpoint not found: $path'},
    ));
  }
}
