import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/checklist.dart';

void main() {
  group('ChecklistItem', () {
    test('hasUnresolvedRejection - rejected + no resubmission', () {
      final item = ChecklistItem.fromJson({
        'id': 'item-1',
        'title': 'Test',
        'is_completed': true,
        'review_result': 'fail',
        'reviewer_id': 'mgr-1',
        'reviewed_at': '2026-03-05T10:00:00',
        'reviews_log': [
          {'id': 'log-1', 'old_result': null, 'new_result': 'fail', 'created_at': '2026-03-05T10:00:00'},
        ],
        'submissions': [
          {'id': 'sub-1', 'version': 1, 'submitted_at': '2026-03-05T09:00:00'},
        ],
        'files': [],
        'messages': [],
      }, 0);

      expect(item.isRejected, true);
      expect(item.isResolved, false);
      expect(item.hasUnresolvedRejection, true);
    });

    test('hasUnresolvedRejection - rejected + resubmitted', () {
      final item = ChecklistItem.fromJson({
        'id': 'item-1',
        'title': 'Test',
        'is_completed': true,
        'review_result': 'pending_re_review',
        'reviews_log': [
          {'id': 'log-1', 'old_result': null, 'new_result': 'fail', 'created_at': '2026-03-05T10:00:00'},
          {'id': 'log-2', 'old_result': 'fail', 'new_result': 'pending_re_review', 'created_at': '2026-03-05T11:00:00'},
        ],
        'submissions': [
          {'id': 'sub-1', 'version': 1, 'submitted_at': '2026-03-05T09:00:00'},
          {'id': 'sub-2', 'version': 2, 'submitted_at': '2026-03-05T11:00:00'},
        ],
        'files': [],
        'messages': [],
      }, 0);

      expect(item.isRejected, false);
      expect(item.isPendingReReview, true);
      expect(item.hasUnresolvedRejection, false);
    });

    test('hasUnresolvedRejection - not rejected', () {
      final item = ChecklistItem.fromJson({
        'id': 'item-1',
        'title': 'Test',
        'is_completed': true,
        'review_result': null,
        'submissions': [],
        'reviews_log': [],
        'files': [],
        'messages': [],
      }, 0);

      expect(item.hasUnresolvedRejection, false);
    });

    test('fullHistory - builds from structured data', () {
      final item = ChecklistItem.fromJson({
        'id': 'item-1',
        'title': 'Test',
        'is_completed': true,
        'completed_at': '2026-03-05T09:00:00',
        'completed_by': 'staff-1',
        'review_result': 'pass',
        'reviewer_id': 'mgr-1',
        'reviewed_at': '2026-03-05T10:00:00',
        'submissions': [
          {'id': 'sub-1', 'version': 1, 'note': 'Done', 'submitted_at': '2026-03-05T09:00:00'},
        ],
        'reviews_log': [
          {'id': 'log-1', 'old_result': null, 'new_result': 'pass', 'comment': 'Good', 'changed_by': 'mgr-1', 'created_at': '2026-03-05T10:00:00'},
        ],
        'files': [],
        'messages': [],
      }, 0);

      final history = item.fullHistory;
      expect(history.length, greaterThanOrEqualTo(2));
    });
  });

  group('ChecklistSnapshot', () {
    ChecklistSnapshot buildSnapshot(List<Map<String, dynamic>> itemsJson) {
      return ChecklistSnapshot.fromItemsList(
        itemsJson.asMap().entries.map((e) => e.value).toList(),
      );
    }

    test('completedItems - unresolved rejection excluded', () {
      final snapshot = buildSnapshot([
        {'title': 'A', 'is_completed': true, 'submissions': [], 'reviews_log': [], 'files': [], 'messages': []},
        {'title': 'B', 'is_completed': true, 'review_result': 'fail', 'reviews_log': [{'id': 'l1', 'new_result': 'fail', 'created_at': '2026-03-05T10:00:00'}], 'submissions': [{'id': 's1', 'version': 1, 'submitted_at': '2026-03-05T09:00:00'}], 'files': [], 'messages': []},
        {'title': 'C', 'is_completed': false, 'submissions': [], 'reviews_log': [], 'files': [], 'messages': []},
      ]);

      expect(snapshot.totalItems, 3);
      expect(snapshot.completedItems, 1);
      expect(snapshot.isAllCompleted, false);
    });

    test('completedItems - resolved rejection included', () {
      final snapshot = buildSnapshot([
        {'title': 'A', 'is_completed': true, 'submissions': [], 'reviews_log': [], 'files': [], 'messages': []},
        {
          'title': 'B', 'is_completed': true, 'review_result': 'pending_re_review',
          'submissions': [
            {'id': 's1', 'version': 1, 'submitted_at': '2026-03-05T09:00:00'},
            {'id': 's2', 'version': 2, 'submitted_at': '2026-03-05T11:00:00'},
          ],
          'reviews_log': [
            {'id': 'l1', 'new_result': 'fail', 'created_at': '2026-03-05T10:00:00'},
          ],
          'files': [], 'messages': [],
        },
        {'title': 'C', 'is_completed': true, 'submissions': [], 'reviews_log': [], 'files': [], 'messages': []},
      ]);

      expect(snapshot.completedItems, 3);
      expect(snapshot.isAllCompleted, true);
    });

    test('empty snapshot', () {
      final snapshot = buildSnapshot([]);

      expect(snapshot.totalItems, 0);
      expect(snapshot.completedItems, 0);
      expect(snapshot.progress, 0);
      expect(snapshot.isAllCompleted, false);
      expect(snapshot.hasRejections, false);
    });
  });

  group('ChecklistItem - review_result', () {
    test('review_result=fail → isRejected', () {
      final item = ChecklistItem.fromJson({
        'id': 'item-1',
        'title': 'Test',
        'is_completed': true,
        'review_result': 'fail',
        'reviewer_id': 'mgr-1',
        'reviewer_name': 'Manager',
        'reviewed_at': '2026-03-05T10:00:00',
        'reviews_log': [
          {'id': 'l1', 'old_result': null, 'new_result': 'fail', 'comment': 'Not good', 'changed_by': 'mgr-1', 'changed_by_name': 'Manager', 'created_at': '2026-03-05T10:00:00'},
        ],
        'submissions': [{'id': 's1', 'version': 1, 'submitted_at': '2026-03-05T09:00:00'}],
        'files': [],
        'messages': [],
      }, 0);

      expect(item.isRejected, true);
      expect(item.isApproved, false);
      expect(item.rejectionComment, 'Not good');
      expect(item.rejectedBy, 'Manager');
    });

    test('review_result=pass → isApproved', () {
      final item = ChecklistItem.fromJson({
        'id': 'item-1',
        'title': 'Test',
        'is_completed': true,
        'review_result': 'pass',
        'reviewer_name': 'Manager',
        'reviewed_at': '2026-03-05T10:00:00',
        'reviews_log': [
          {'id': 'l1', 'new_result': 'pass', 'comment': 'Good job', 'changed_by_name': 'Manager', 'created_at': '2026-03-05T10:00:00'},
        ],
        'submissions': [],
        'files': [],
        'messages': [],
      }, 0);

      expect(item.isApproved, true);
      expect(item.isRejected, false);
      expect(item.approvalComment, 'Good job');
      expect(item.approvedBy, 'Manager');
    });

    test('review_result=pending_re_review → not rejected', () {
      final item = ChecklistItem.fromJson({
        'id': 'item-1',
        'title': 'Test',
        'is_completed': true,
        'review_result': 'pending_re_review',
        'submissions': [
          {'id': 's1', 'version': 1, 'submitted_at': '2026-03-05T09:00:00'},
          {'id': 's2', 'version': 2, 'submitted_at': '2026-03-05T11:00:00'},
        ],
        'reviews_log': [],
        'files': [],
        'messages': [],
      }, 0);

      expect(item.isRejected, false);
      expect(item.isPendingReReview, true);
      expect(item.hasUnresolvedRejection, false);
    });
  });

  group('ChecklistSnapshot.fromJson', () {
    test('Map format with items key', () {
      final snapshot = ChecklistSnapshot.fromJson({
        'template_id': 'tmpl-1',
        'template_name': 'Opening',
        'snapshot_at': '2026-03-05T08:00:00',
        'items': [
          {'id': 'i1', 'title': 'Item 1', 'is_completed': false, 'submissions': [], 'reviews_log': [], 'files': [], 'messages': []},
          {'id': 'i2', 'title': 'Item 2', 'is_completed': true, 'submissions': [], 'reviews_log': [], 'files': [], 'messages': []},
        ],
      });

      expect(snapshot.templateId, 'tmpl-1');
      expect(snapshot.templateName, 'Opening');
      expect(snapshot.totalItems, 2);
      expect(snapshot.completedItems, 1);
    });

    test('null items → empty list', () {
      final snapshot = ChecklistSnapshot.fromJson({
        'template_id': 'tmpl-1',
      });

      expect(snapshot.totalItems, 0);
    });
  });
}
