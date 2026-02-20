import 'package:dio/dio.dart';

import '../models/assignment.dart';
import '../models/store.dart';
import '../models/checklist.dart';
import '../models/task.dart';
import '../models/announcement.dart';
import '../models/notification.dart';
import '../utils/token_storage.dart';
import 'auth_service.dart';
import 'assignment_service.dart';
import 'task_service.dart';
import 'announcement_service.dart';
import 'notification_service.dart';

// Dummy Dio instance — never used since all methods are overridden
final _dummyDio = Dio();

/// Mock auth service — works without server
class MockAuthService extends AuthService {
  MockAuthService() : super(_dummyDio);

  @override
  Future<void> login(String username, String password) async {
    await Future.delayed(const Duration(milliseconds: 300));
    await TokenStorage.setTokens('mock_access_token', 'mock_refresh_token');
  }

  @override
  Future<void> register({
    required String username,
    required String password,
    required String fullName,
    String? email,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    await TokenStorage.setTokens('mock_access_token', 'mock_refresh_token');
  }

  @override
  Future<Map<String, dynamic>> getMe() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return {
      'id': 'mock-user-001',
      'organization_id': 'mock-org-001',
      'role_id': 'mock-role-001',
      'username': 'demo_user',
      'email': 'demo@example.com',
      'first_name': 'Demo',
      'last_name': 'User',
      'is_active': true,
      'role_name': 'Staff',
      'role_level': 4,
      'created_at': '2026-01-01T00:00:00Z',
    };
  }

  @override
  Future<void> logout() async {
    await TokenStorage.clearTokens();
  }
}

/// Mock assignment service
class MockAssignmentService extends AssignmentService {
  MockAssignmentService() : super(_dummyDio);

  @override
  Future<List<Assignment>> getMyAssignments({String? workDate, String? status}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    var result = List<Assignment>.from(_mockAssignments);
    if (status != null) {
      result = result.where((a) => a.status == status).toList();
    }
    return result;
  }

  @override
  Future<Assignment> getAssignment(String id) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _mockAssignments.firstWhere((a) => a.id == id);
  }

  @override
  Future<void> toggleChecklistItem(String assignmentId, int itemIndex, bool isCompleted) async {
    await Future.delayed(const Duration(milliseconds: 100));
  }
}

/// Mock task service
class MockTaskService extends TaskService {
  MockTaskService() : super(_dummyDio);

  @override
  Future<List<AdditionalTask>> getMyTasks({String? status}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (status != null) {
      return _mockTasks.where((t) => t.status == status).toList();
    }
    return _mockTasks;
  }

  @override
  Future<AdditionalTask> getTask(String id) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _mockTasks.firstWhere((t) => t.id == id);
  }

  @override
  Future<void> completeTask(String id) async {
    await Future.delayed(const Duration(milliseconds: 150));
  }
}

/// Mock announcement service
class MockAnnouncementService extends AnnouncementService {
  MockAnnouncementService() : super(_dummyDio);

  @override
  Future<List<Announcement>> getAnnouncements({int? page, int? perPage}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _mockAnnouncements;
  }

  @override
  Future<Announcement> getAnnouncement(String id) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _mockAnnouncements.firstWhere((a) => a.id == id);
  }
}

/// Mock notification service
class MockNotificationService extends NotificationService {
  MockNotificationService() : super(_dummyDio);

  @override
  Future<List<AppNotification>> getNotifications({int? page, int? perPage}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _mockNotifications;
  }

  @override
  Future<int> getUnreadCount() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _mockNotifications.where((n) => !n.isRead).length;
  }

  @override
  Future<void> markAsRead(String id) async {
    await Future.delayed(const Duration(milliseconds: 100));
  }

  @override
  Future<void> markAllAsRead() async {
    await Future.delayed(const Duration(milliseconds: 100));
  }
}

// ─── Mock Data ───────────────────────────────────────────────

final _mockAssignments = [
  Assignment(
    id: 'asgn-001',
    store: const Store(id: 'store-001', name: 'Cafe Bloom'),
    shift: const ShiftInfo(id: 'shift-001', name: 'Morning (09:00-14:00)'),
    position: const PositionInfo(id: 'pos-001', name: 'Barista'),
    status: 'in_progress',
    workDate: DateTime.now(),
    checklistSnapshot: ChecklistSnapshot(
      templateId: 'tmpl-001',
      templateName: 'Barista Opening Checklist',
      items: const [
        ChecklistItem(index: 0, title: 'Check espresso machine', verificationType: 'none', isCompleted: true, sortOrder: 0),
        ChecklistItem(index: 1, title: 'Prepare milk station', verificationType: 'none', isCompleted: true, sortOrder: 1),
        ChecklistItem(index: 2, title: 'Stock cups and lids', verificationType: 'none', isCompleted: false, sortOrder: 2),
        ChecklistItem(index: 3, title: 'Clean counter area', verificationType: 'photo', isCompleted: false, sortOrder: 3),
      ],
    ),
  ),
  Assignment(
    id: 'asgn-002',
    store: const Store(id: 'store-002', name: 'Bistro Garden'),
    shift: const ShiftInfo(id: 'shift-002', name: 'Evening (17:00-22:00)'),
    position: const PositionInfo(id: 'pos-002', name: 'Server'),
    status: 'assigned',
    workDate: DateTime.now().add(const Duration(days: 1)),
  ),
  Assignment(
    id: 'asgn-003',
    store: const Store(id: 'store-001', name: 'Cafe Bloom'),
    shift: const ShiftInfo(id: 'shift-001', name: 'Morning (09:00-14:00)'),
    position: const PositionInfo(id: 'pos-001', name: 'Barista'),
    status: 'completed',
    workDate: DateTime.now().subtract(const Duration(days: 1)),
    checklistSnapshot: ChecklistSnapshot(
      templateId: 'tmpl-001',
      templateName: 'Barista Opening Checklist',
      items: const [
        ChecklistItem(index: 0, title: 'Check espresso machine', verificationType: 'none', isCompleted: true, sortOrder: 0),
        ChecklistItem(index: 1, title: 'Prepare milk station', verificationType: 'none', isCompleted: true, sortOrder: 1),
      ],
    ),
  ),
];

final _mockTasks = [
  AdditionalTask(
    id: 'task-001',
    store: const Store(id: 'store-001', name: 'Cafe Bloom'),
    title: 'Restock pastry display',
    description: 'Check inventory and restock the pastry display case before lunch rush.',
    priority: 'high',
    status: 'pending',
    dueDate: DateTime.now().add(const Duration(hours: 3)),
    createdByName: 'Manager Kim',
    createdAt: DateTime.now().subtract(const Duration(hours: 1)),
  ),
  AdditionalTask(
    id: 'task-002',
    store: const Store(id: 'store-002', name: 'Bistro Garden'),
    title: 'Update menu board',
    description: "Write today's specials on the menu board.",
    priority: 'normal',
    status: 'in_progress',
    dueDate: DateTime.now().add(const Duration(hours: 5)),
    createdByName: 'Manager Park',
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
  ),
  AdditionalTask(
    id: 'task-003',
    title: 'Submit weekly feedback',
    description: 'Fill out the weekly staff feedback form.',
    priority: 'low',
    status: 'completed',
    createdByName: 'HR Team',
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
  ),
];

final _mockAnnouncements = [
  Announcement(
    id: 'ann-001',
    store: const Store(id: 'store-001', name: 'Cafe Bloom'),
    title: 'New Spring Menu Launch',
    content: 'We are launching a new spring menu next Monday. Please review the new items and preparation guides attached in the staff portal. Training sessions will be held this Friday.',
    createdByName: 'Manager Kim',
    createdAt: DateTime.now().subtract(const Duration(hours: 5)),
  ),
  Announcement(
    id: 'ann-002',
    title: 'Updated Break Policy',
    content: 'Starting next week, all staff are required to log their break times in the app. Please make sure to clock in and out for each break.',
    createdByName: 'HR Team',
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
  ),
  Announcement(
    id: 'ann-003',
    store: const Store(id: 'store-002', name: 'Bistro Garden'),
    title: 'Weekend Shift Bonus',
    content: 'Staff working weekend shifts this month will receive a 15% bonus. Sign up for available slots through the schedule page.',
    createdByName: 'Manager Park',
    createdAt: DateTime.now().subtract(const Duration(days: 3)),
  ),
];

final _mockNotifications = [
  AppNotification(
    id: 'notif-001',
    type: 'work_assigned',
    message: 'You have been assigned to Cafe Bloom - Morning shift tomorrow.',
    referenceType: 'work_assignment',
    referenceId: 'asgn-002',
    isRead: false,
    createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
  ),
  AppNotification(
    id: 'notif-002',
    type: 'additional_task',
    message: 'New task: Restock pastry display (High priority)',
    referenceType: 'additional_task',
    referenceId: 'task-001',
    isRead: false,
    createdAt: DateTime.now().subtract(const Duration(hours: 1)),
  ),
  AppNotification(
    id: 'notif-003',
    type: 'announcement',
    message: 'New announcement: New Spring Menu Launch',
    referenceType: 'announcement',
    referenceId: 'ann-001',
    isRead: true,
    createdAt: DateTime.now().subtract(const Duration(hours: 5)),
  ),
];
