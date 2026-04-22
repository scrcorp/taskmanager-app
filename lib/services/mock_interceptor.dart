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
    {'id': 's1', 'name': 'Bean & Brew', 'address': '123 Main St'},
    {'id': 's2', 'name': 'The Pier', 'address': '456 Harbor Rd'},
    {'id': 's3', 'name': 'Sunrise Cafe', 'address': '789 Dawn Ave'},
    {'id': 's4', 'name': 'Downtown Deli', 'address': '321 Center Blvd'},
    {'id': 's5', 'name': 'Park Side Kitchen', 'address': '654 Green Way'},
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
            'email_verified': true,
            'is_active': true,
            'role_name': 'Staff',
            'role_level': 40,
            'organization_name': 'Demo Org',
            'company_code': 'MOCK01',
            'permissions': <String>[],
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

      // ── Clock endpoints ──

      // POST /clock/in
      if (path == '/clock/in' && method == 'POST') {
        final pin = (options.data as Map<String, dynamic>?)?['pin'] ?? '';
        if (pin == '123456' || pin == '111111' || pin == '222222') {
          return handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'status': 'clocked_in',
              'user_name': pin == '123456' ? 'Elena Rodriguez' : pin == '111111' ? 'Marcus Chen' : 'Jessica Warren',
              'clock_in_time': DateTime.now().toIso8601String(),
            },
          ));
        }
        return handler.resolve(Response(
          requestOptions: options,
          statusCode: 401,
          data: {'detail': 'Invalid Employee ID'},
        ));
      }

      // POST /clock/out
      if (path == '/clock/out' && method == 'POST') {
        final pin = (options.data as Map<String, dynamic>?)?['pin'] ?? '';
        if (pin == '123456' || pin == '111111' || pin == '222222') {
          return handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'status': 'clocked_out',
              'user_name': pin == '123456' ? 'Elena Rodriguez' : pin == '111111' ? 'Marcus Chen' : 'Jessica Warren',
              'clock_out_time': DateTime.now().toIso8601String(),
            },
          ));
        }
        return handler.resolve(Response(
          requestOptions: options,
          statusCode: 401,
          data: {'detail': 'Invalid Employee ID'},
        ));
      }

      // POST /clock/break
      if (path == '/clock/break' && method == 'POST') {
        final pin = (options.data as Map<String, dynamic>?)?['pin'] ?? '';
        if (pin == '123456' || pin == '111111' || pin == '222222') {
          return handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'status': 'on_break',
              'user_name': pin == '123456' ? 'Elena Rodriguez' : pin == '111111' ? 'Marcus Chen' : 'Jessica Warren',
            },
          ));
        }
        return handler.resolve(Response(
          requestOptions: options,
          statusCode: 401,
          data: {'detail': 'Invalid Employee ID'},
        ));
      }

      // GET /clock/on-shift
      if (path == '/clock/on-shift' && method == 'GET') {
        return handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: [
            {'user_id': 'u1', 'name': 'Elena Rodriguez', 'role': 'AM·Barista', 'since': '09:32', 'status': 'working'},
            {'user_id': 'u2', 'name': 'Marcus Chen', 'role': 'Floor Supervisor', 'since': '09:00', 'status': 'working'},
            {'user_id': 'u3', 'name': 'Jessica Warren', 'role': 'PM·Grill', 'since': '14:00', 'status': 'break'},
          ],
        ));
      }

      // GET /clock/coming-up
      if (path == '/clock/coming-up' && method == 'GET') {
        return handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: [
            {'user_id': 'u4', 'name': 'David Miller', 'role': 'Inventory', 'start_time': '11:00', 'end_time': '19:00'},
            {'user_id': 'u5', 'name': 'Amara Okafor', 'role': 'Support', 'start_time': '10:30', 'end_time': '18:30'},
          ],
        ));
      }


      // GET /app/my/schedules (오늘 스케줄 + 체크리스트)
      if (path == '/app/my/schedules' && method == 'GET') {
        final today = DateTime.now();
        final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
        return handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: [
            {
              'id': 'sched1',
              'store': {'id': 's1', 'name': 'Bean & Brew'},
              'work_role_id': 'wr1',
              'work_role_name': 'AM·Barista',
              'status': 'confirmed',
              'work_date': todayStr,
              'start_time': '09:00',
              'end_time': '17:00',
              'net_work_minutes': 480,
              'checklist_instance_id': 'cl1',
              'total_items': 5,
              'completed_items': 2,
              'checklist_snapshot': {
                'template_id': 'tpl1',
                'template_name': 'Opening Checklist',
                'items': [
                  {'id': 'ci1', 'item_index': 0, 'title': 'Clean counter tops', 'description': 'Wipe down all counter surfaces', 'verification_type': 'photo', 'min_photos': 1, 'max_photos': 3, 'sort_order': 0, 'recurrence_type': 'daily', 'is_completed': true, 'completed_at': '${todayStr}T09:15:00Z', 'completed_by_name': 'Alex Kim', 'files': [], 'submissions': [{'id': 'sub1', 'version': 1, 'note': 'All clean', 'submitted_at': '${todayStr}T09:15:00Z', 'submitted_by_name': 'Alex Kim'}], 'reviews_log': [], 'messages': [{'id': 'msg1', 'author_name': 'Manager', 'content': 'Good job, looks spotless!', 'created_at': '${todayStr}T09:20:00Z'}]},
                  {'id': 'ci2', 'item_index': 1, 'title': 'Check espresso machine', 'description': 'Run test shot and check pressure', 'verification_type': 'photo_text', 'min_photos': 1, 'max_photos': 2, 'sort_order': 1, 'recurrence_type': 'daily', 'is_completed': true, 'completed_at': '${todayStr}T09:25:00Z', 'completed_by_name': 'Alex Kim', 'review_result': 'pass', 'reviewer_name': 'Manager', 'reviewed_at': '${todayStr}T09:30:00Z', 'files': [], 'submissions': [{'id': 'sub2', 'version': 1, 'note': 'Pressure at 9 bar, good', 'submitted_at': '${todayStr}T09:25:00Z', 'submitted_by_name': 'Alex Kim'}], 'reviews_log': [{'id': 'rl1', 'new_result': 'pass', 'comment': 'Looks good', 'changed_by_name': 'Manager', 'created_at': '${todayStr}T09:30:00Z'}], 'messages': []},
                  {'id': 'ci3', 'item_index': 2, 'title': 'Restock milk & syrup', 'description': 'Check fridge inventory and restock if low', 'verification_type': 'photo', 'min_photos': 1, 'max_photos': 2, 'sort_order': 2, 'recurrence_type': 'daily', 'is_completed': false, 'files': [], 'submissions': [], 'reviews_log': [], 'messages': [{'id': 'msg2', 'author_name': 'Manager', 'content': 'We got a new shipment today, check the back', 'created_at': '${todayStr}T08:00:00Z'}]},
                  {'id': 'ci4', 'item_index': 3, 'title': 'Set up display case', 'description': 'Arrange pastries in display', 'verification_type': 'photo', 'min_photos': 1, 'max_photos': 3, 'sort_order': 3, 'recurrence_type': 'daily', 'is_completed': false, 'files': [], 'submissions': [], 'reviews_log': [], 'messages': []},
                  {'id': 'ci5', 'item_index': 4, 'title': 'Floor sweep & mop', 'description': 'Sweep and mop entire floor area', 'verification_type': 'none', 'sort_order': 4, 'recurrence_type': 'daily', 'is_completed': false, 'files': [], 'submissions': [], 'reviews_log': [], 'messages': []},
                ],
              },
              'created_at': '${todayStr}T00:00:00Z',
            },
          ],
        ));
      }

      // GET /app/my/schedules/:id (단일 스케줄 상세)
      if (path.startsWith('/app/my/schedules/') && method == 'GET' && !path.contains('checklist')) {
        final today = DateTime.now();
        final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
        return handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            'id': 'sched1',
            'store': {'id': 's1', 'name': 'Bean & Brew'},
            'work_role_id': 'wr1',
            'work_role_name': 'AM·Barista',
            'status': 'confirmed',
            'work_date': todayStr,
            'start_time': '09:00',
            'end_time': '17:00',
            'net_work_minutes': 480,
            'checklist_instance_id': 'cl1',
            'total_items': 5,
            'completed_items': 2,
            'checklist_snapshot': {
              'template_id': 'tpl1',
              'template_name': 'Opening Checklist',
              'items': [
                {'id': 'ci1', 'item_index': 0, 'title': 'Clean counter tops', 'description': 'Wipe down all counter surfaces', 'verification_type': 'photo', 'min_photos': 1, 'max_photos': 3, 'sort_order': 0, 'recurrence_type': 'daily', 'is_completed': true, 'completed_at': '${todayStr}T09:15:00Z', 'completed_by_name': 'Alex Kim', 'files': [], 'submissions': [{'id': 'sub1', 'version': 1, 'note': 'All clean', 'submitted_at': '${todayStr}T09:15:00Z', 'submitted_by_name': 'Alex Kim'}], 'reviews_log': [], 'messages': [{'id': 'msg1', 'author_name': 'Manager', 'content': 'Good job, looks spotless!', 'created_at': '${todayStr}T09:20:00Z'}]},
                {'id': 'ci2', 'item_index': 1, 'title': 'Check espresso machine', 'description': 'Run test shot and check pressure', 'verification_type': 'photo_text', 'min_photos': 1, 'max_photos': 2, 'sort_order': 1, 'recurrence_type': 'daily', 'is_completed': true, 'completed_at': '${todayStr}T09:25:00Z', 'completed_by_name': 'Alex Kim', 'review_result': 'pass', 'reviewer_name': 'Manager', 'reviewed_at': '${todayStr}T09:30:00Z', 'files': [], 'submissions': [{'id': 'sub2', 'version': 1, 'note': 'Pressure at 9 bar, good', 'submitted_at': '${todayStr}T09:25:00Z', 'submitted_by_name': 'Alex Kim'}], 'reviews_log': [{'id': 'rl1', 'new_result': 'pass', 'comment': 'Looks good', 'changed_by_name': 'Manager', 'created_at': '${todayStr}T09:30:00Z'}], 'messages': []},
                {'id': 'ci3', 'item_index': 2, 'title': 'Restock milk & syrup', 'description': 'Check fridge inventory and restock if low', 'verification_type': 'photo', 'min_photos': 1, 'max_photos': 2, 'sort_order': 2, 'recurrence_type': 'daily', 'is_completed': false, 'files': [], 'submissions': [], 'reviews_log': [], 'messages': [{'id': 'msg2', 'author_name': 'Manager', 'content': 'We got a new shipment today, check the back', 'created_at': '${todayStr}T08:00:00Z'}]},
                {'id': 'ci4', 'item_index': 3, 'title': 'Set up display case', 'description': 'Arrange pastries in display', 'verification_type': 'photo', 'min_photos': 1, 'max_photos': 3, 'sort_order': 3, 'recurrence_type': 'daily', 'is_completed': false, 'files': [], 'submissions': [], 'reviews_log': [], 'messages': []},
                {'id': 'ci5', 'item_index': 4, 'title': 'Floor sweep & mop', 'description': 'Sweep and mop entire floor area', 'verification_type': 'none', 'sort_order': 4, 'recurrence_type': 'daily', 'is_completed': false, 'files': [], 'submissions': [], 'reviews_log': [], 'messages': []},
              ],
            },
            'created_at': '${todayStr}T00:00:00Z',
          },
        ));
      }

      // GET /app/my/attendance/summary (모바일 근태 요약)
      if (path == '/app/my/attendance/summary' && method == 'GET') {
        return handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            'days_worked': 14,
            'late_count': 1,
            'early_leave_count': 0,
            'total_scheduled': 18,
            'month': 'April 2026',
          },
        ));
      }

      // GET /app/my/today-team (모바일 오늘 동료)
      if (path == '/app/my/today-team' && method == 'GET') {
        return handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: [
            {'user_id': 'u1', 'name': 'Elena Rodriguez', 'role': 'AM·Barista', 'shift': 'AM'},
            {'user_id': 'u2', 'name': 'Marcus Chen', 'role': 'Floor Supervisor', 'shift': 'AM'},
            {'user_id': 'u3', 'name': 'Jessica Warren', 'role': 'PM·Grill', 'shift': 'PM'},
            {'user_id': 'u4', 'name': 'David Miller', 'role': 'Inventory', 'shift': 'AM'},
          ],
        ));
      }

    // 매칭 안 되면 404
    handler.resolve(Response(
      requestOptions: options,
      statusCode: 404,
      data: {'detail': 'Mock: endpoint not found: $path'},
    ));
  }
}
