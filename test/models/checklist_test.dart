import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/checklist.dart';

void main() {
  group('ChecklistItem', () {
    test('hasUnresolvedRejection - 반려됨 + 미응답', () {
      final item = ChecklistItem.fromJson({
        'title': 'Test',
        'is_completed': true,
        'is_rejected': true,
        'rejected_at': '2026-03-05T10:00:00',
        'rejected_by': 'Manager',
        'rejection_comment': 'Redo this',
        'responded_at': null,
      }, 0);

      expect(item.isRejected, true);
      expect(item.isResolved, false);
      expect(item.hasUnresolvedRejection, true);
    });

    test('hasUnresolvedRejection - 반려됨 + 재응답 완료', () {
      final item = ChecklistItem.fromJson({
        'title': 'Test',
        'is_completed': true,
        'is_rejected': true,
        'rejected_at': '2026-03-05T10:00:00',
        'responded_at': '2026-03-05T11:00:00',
        'responded_by': 'Staff',
        'response_comment': 'Fixed',
      }, 0);

      expect(item.isRejected, true);
      expect(item.isResolved, true);
      expect(item.hasUnresolvedRejection, false);
    });

    test('hasUnresolvedRejection - 반려 안 됨', () {
      final item = ChecklistItem.fromJson({
        'title': 'Test',
        'is_completed': true,
        'is_rejected': false,
      }, 0);

      expect(item.hasUnresolvedRejection, false);
    });

    test('fullHistory - 서버 history 없을 때 개별 필드에서 재구성', () {
      final item = ChecklistItem.fromJson({
        'title': 'Test',
        'is_completed': true,
        'completed_at': '2026-03-05T09:00:00',
        'completed_by': 'Staff',
        'is_rejected': true,
        'rejected_at': '2026-03-05T10:00:00',
        'rejected_by': 'Manager',
        'rejection_comment': 'Redo',
        'responded_at': '2026-03-05T11:00:00',
        'responded_by': 'Staff',
        'response_comment': 'Done',
        'photo_url': 'https://example.com/photo.jpg',
      }, 0);

      final history = item.fullHistory;
      expect(history.length, 3);
      expect(history[0].type, 'completed');
      expect(history[1].type, 'rejected');
      expect(history[2].type, 'responded');
    });

    test('fullHistory - 서버 history 있을 때 그대로 사용', () {
      final item = ChecklistItem.fromJson({
        'title': 'Test',
        'is_completed': true,
        'history': [
          {'type': 'completed', 'at': '2026-03-05T09:00:00'},
          {'type': 'rejected', 'at': '2026-03-05T10:00:00', 'comment': 'Redo'},
        ],
      }, 0);

      final history = item.fullHistory;
      expect(history.length, 2);
      expect(history[0].type, 'completed');
      expect(history[1].type, 'rejected');
    });
  });

  group('ChecklistSnapshot', () {
    ChecklistSnapshot _buildSnapshot(List<Map<String, dynamic>> itemsJson) {
      return ChecklistSnapshot.fromItemsList(
        itemsJson.asMap().entries.map((e) => e.value).toList(),
      );
    }

    test('completedItems - 미해결 반려 항목 제외', () {
      final snapshot = _buildSnapshot([
        {'title': 'A', 'is_completed': true},
        {'title': 'B', 'is_completed': true, 'is_rejected': true},
        {'title': 'C', 'is_completed': false},
      ]);

      // B는 반려됨 + 미응답 → 완료 카운트에서 제외
      expect(snapshot.totalItems, 3);
      expect(snapshot.completedItems, 1);
      expect(snapshot.isAllCompleted, false);
    });

    test('completedItems - 재응답 완료된 반려 항목은 포함', () {
      final snapshot = _buildSnapshot([
        {'title': 'A', 'is_completed': true},
        {
          'title': 'B',
          'is_completed': true,
          'is_rejected': true,
          'responded_at': '2026-03-05T11:00:00',
        },
        {'title': 'C', 'is_completed': true},
      ]);

      // B는 반려됨 + 재응답 완료 → 완료 카운트에 포함
      expect(snapshot.completedItems, 3);
      expect(snapshot.isAllCompleted, true);
    });

    test('progress - 정확한 비율 계산', () {
      final snapshot = _buildSnapshot([
        {'title': 'A', 'is_completed': true},
        {'title': 'B', 'is_completed': true, 'is_rejected': true},
        {'title': 'C', 'is_completed': false},
        {'title': 'D', 'is_completed': true},
      ]);

      // 4개 중 A, D만 완료 (B는 미해결 반려)
      expect(snapshot.completedItems, 2);
      expect(snapshot.progress, 0.5);
    });

    test('unresolvedRejections - 미해결 반려 항목 목록', () {
      final snapshot = _buildSnapshot([
        {'title': 'A', 'is_completed': true},
        {'title': 'B', 'is_completed': true, 'is_rejected': true},
        {
          'title': 'C',
          'is_completed': true,
          'is_rejected': true,
          'responded_at': '2026-03-05T11:00:00',
        },
        {'title': 'D', 'is_completed': true, 'is_rejected': true},
      ]);

      // B, D는 미해결 반려. C는 재응답 완료.
      expect(snapshot.unresolvedRejections.length, 2);
      expect(snapshot.unresolvedRejections[0].title, 'B');
      expect(snapshot.unresolvedRejections[1].title, 'D');
    });

    test('rejectedItems - 전체 반려 항목 수', () {
      final snapshot = _buildSnapshot([
        {'title': 'A', 'is_completed': true},
        {'title': 'B', 'is_completed': true, 'is_rejected': true},
        {
          'title': 'C',
          'is_completed': true,
          'is_rejected': true,
          'responded_at': '2026-03-05T11:00:00',
        },
      ]);

      // B, C 모두 반려됨 (재응답 여부 무관)
      expect(snapshot.rejectedItems, 2);
      expect(snapshot.hasRejections, true);
    });

    test('빈 스냅샷', () {
      final snapshot = _buildSnapshot([]);

      expect(snapshot.totalItems, 0);
      expect(snapshot.completedItems, 0);
      expect(snapshot.progress, 0);
      expect(snapshot.isAllCompleted, false);
      expect(snapshot.hasRejections, false);
    });
  });

  group('ChecklistItemEvent', () {
    test('fromJson 파싱', () {
      final event = ChecklistItemEvent.fromJson({
        'type': 'rejected',
        'comment': 'Please redo',
        'photo_urls': ['url1', 'url2'],
        'by': 'Manager',
        'at': '2026-03-05T10:30:00',
      });

      expect(event.type, 'rejected');
      expect(event.comment, 'Please redo');
      expect(event.photoUrls.length, 2);
      expect(event.by, 'Manager');
      expect(event.atDisplay, '03/05 10:30');
    });

    test('atDisplay - null 처리', () {
      final event = ChecklistItemEvent.fromJson({
        'type': 'pending',
      });

      expect(event.atDisplay, null);
    });
  });

  group('ChecklistItem - review_status 통합 필드', () {
    test('review_status=fail → isRejected', () {
      final item = ChecklistItem.fromJson({
        'title': 'Test',
        'is_completed': true,
        'review_status': 'fail',
        'review_comment': 'Not good',
        'review_photo_urls': ['url1'],
        'reviewed_by': 'Manager',
        'reviewed_at': '2026-03-05T10:00:00',
      }, 0);

      expect(item.isRejected, true);
      expect(item.isApproved, false);
      expect(item.isCaution, false);
      expect(item.rejectionComment, 'Not good');
      expect(item.rejectionPhotoUrls, ['url1']);
      expect(item.rejectedBy, 'Manager');
    });

    test('review_status=pass → isApproved', () {
      final item = ChecklistItem.fromJson({
        'title': 'Test',
        'is_completed': true,
        'review_status': 'pass',
        'review_comment': 'Good job',
        'reviewed_by': 'Manager',
        'reviewed_at': '2026-03-05T10:00:00',
      }, 0);

      expect(item.isApproved, true);
      expect(item.isRejected, false);
      expect(item.approvalComment, 'Good job');
      expect(item.approvedBy, 'Manager');
    });

    test('review_status=caution → isCaution', () {
      final item = ChecklistItem.fromJson({
        'title': 'Test',
        'is_completed': true,
        'review_status': 'caution',
      }, 0);

      expect(item.isCaution, true);
      expect(item.isRejected, false);
      expect(item.isApproved, false);
    });

    test('review_status=pending_re_review → 재검토 대기 (반려 아님)', () {
      final item = ChecklistItem.fromJson({
        'title': 'Test',
        'is_completed': true,
        'review_status': 'pending_re_review',
        'review_comment': 'Check again',
        'responded_at': '2026-03-05T11:00:00',
      }, 0);

      expect(item.isRejected, false); // pending_re_review는 반려가 아님
      expect(item.isPendingReReview, true);
      expect(item.isResolved, true);
      expect(item.hasUnresolvedRejection, false);
    });

    test('review_status 우선, is_rejected 폴백', () {
      // review_status가 있으면 is_rejected 무시
      final item = ChecklistItem.fromJson({
        'title': 'Test',
        'is_completed': true,
        'review_status': 'pass',
        'is_rejected': true, // 무시됨
      }, 0);

      expect(item.isApproved, true);
      expect(item.isRejected, false);
    });

    test('fullHistory - approved 이벤트 재구성', () {
      final item = ChecklistItem.fromJson({
        'title': 'Test',
        'is_completed': true,
        'completed_at': '2026-03-05T09:00:00',
        'review_status': 'pass',
        'review_comment': 'Well done',
        'reviewed_at': '2026-03-05T10:00:00',
        'reviewed_by': 'Manager',
      }, 0);

      final history = item.fullHistory;
      expect(history.length, 2);
      expect(history[0].type, 'completed');
      expect(history[1].type, 'approved');
      expect(history[1].comment, 'Well done');
    });
  });

  group('ChecklistSnapshot.fromJson', () {
    test('Map 형태 파싱', () {
      final snapshot = ChecklistSnapshot.fromJson({
        'template_id': 'tmpl-1',
        'template_name': 'Opening',
        'snapshot_at': '2026-03-05T08:00:00',
        'items': [
          {'title': 'Item 1', 'is_completed': false},
          {'title': 'Item 2', 'is_completed': true},
        ],
      });

      expect(snapshot.templateId, 'tmpl-1');
      expect(snapshot.templateName, 'Opening');
      expect(snapshot.totalItems, 2);
      expect(snapshot.completedItems, 1);
    });

    test('items가 null일 때 빈 목록', () {
      final snapshot = ChecklistSnapshot.fromJson({
        'template_id': 'tmpl-1',
      });

      expect(snapshot.totalItems, 0);
    });
  });
}
