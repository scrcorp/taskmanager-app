import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/checklist.dart';
import 'package:app/widgets/time_watermark.dart';

void main() {
  group('photoWatermarkTime', () {
    final capture = DateTime.utc(2026, 3, 5, 9, 0);
    final received = DateTime.utc(2026, 3, 5, 10, 0);

    test('capture_time 우선', () {
      expect(photoWatermarkTime(capture, received), capture);
    });

    test('capture_time 없으면 null (received_at 폴백 안 함)', () {
      expect(photoWatermarkTime(null, received), isNull);
    });

    test('둘 다 없으면 null', () {
      expect(photoWatermarkTime(null, null), isNull);
    });
  });

  group('ItemFile - capture/received parsing', () {
    test('capture_time/received_at 파싱 + watermarkTime=capture 우선', () {
      final f = ItemFile.fromJson({
        'id': 'f1',
        'context': 'submission',
        'context_id': 's1',
        'file_url': 'http://x/a.webp',
        'file_type': 'photo',
        'capture_time': '2026-03-05T09:00:00Z',
        'received_at': '2026-03-05T10:00:00Z',
      });
      expect(f.captureTime, DateTime.utc(2026, 3, 5, 9, 0));
      expect(f.receivedAt, DateTime.utc(2026, 3, 5, 10, 0));
      expect(f.watermarkTime, f.captureTime);
    });

    test('capture_time 없으면 watermarkTime=null (received_at 폴백 안 함)', () {
      final f = ItemFile.fromJson({
        'id': 'f1',
        'context': 'submission',
        'file_url': 'http://x/a.webp',
        'received_at': '2026-03-05T10:00:00Z',
      });
      expect(f.captureTime, isNull);
      expect(f.watermarkTime, isNull);
    });

    test('시간 정보 전혀 없으면 watermarkTime=null', () {
      final f = ItemFile.fromJson({
        'id': 'f1',
        'context': 'submission',
        'file_url': 'http://x/a.webp',
      });
      expect(f.watermarkTime, isNull);
    });

    test('잘못된 시각 문자열은 null 로 처리', () {
      final f = ItemFile.fromJson({
        'id': 'f1',
        'context': 'submission',
        'file_url': 'http://x/a.webp',
        'capture_time': 'not-a-date',
      });
      expect(f.captureTime, isNull);
    });
  });

  group('ChecklistItem photo times - index 정렬', () {
    ChecklistItem build() => ChecklistItem.fromJson({
      'id': 'item-1',
      'title': 'Test',
      'is_completed': true,
      'review_result': 'pass',
      'reviewed_at': '2026-03-05T12:00:00',
      'submissions': [
        {'id': 's1', 'version': 1, 'submitted_at': '2026-03-05T09:00:00'},
      ],
      'reviews_log': [
        {'id': 'l1', 'new_result': 'pass', 'created_at': '2026-03-05T12:00:00'},
      ],
      'files': [
        // submission 2장: 하나는 capture 있음, 하나는 capture 없음(→ No time)
        {
          'id': 'f1',
          'context': 'submission',
          'context_id': 's1',
          'file_url': 'http://x/sub1.webp',
          'file_type': 'photo',
          'sort_order': 0,
          'capture_time': '2026-03-05T08:55:00Z',
          'received_at': '2026-03-05T09:01:00Z',
        },
        {
          'id': 'f2',
          'context': 'submission',
          'context_id': 's1',
          'file_url': 'http://x/sub2.webp',
          'file_type': 'photo',
          'sort_order': 1,
          'received_at': '2026-03-05T09:02:00Z',
        },
        // review 1장
        {
          'id': 'f3',
          'context': 'review',
          'file_url': 'http://x/rev1.webp',
          'file_type': 'photo',
          'capture_time': '2026-03-05T11:59:00Z',
        },
      ],
      'messages': [],
    }, 0);

    test('photoUrls 와 photoTimes 길이/정렬 일치', () {
      final item = build();
      expect(item.photoUrls, ['http://x/sub1.webp', 'http://x/sub2.webp']);
      expect(item.photoTimes.length, item.photoUrls.length);
      expect(item.photoTimes[0], DateTime.utc(2026, 3, 5, 8, 55)); // capture 표시
      expect(
        item.photoTimes[1],
        isNull,
      ); // capture 없음 → null(No time), received 폴백 안 함
    });

    test('reviewPhotoTimes 및 approvalPhotoTimes', () {
      final item = build();
      expect(item.reviewPhotoUrls, ['http://x/rev1.webp']);
      expect(item.reviewPhotoTimes, [DateTime.utc(2026, 3, 5, 11, 59)]);
      // review_result=pass → approval 별칭에 노출
      expect(item.approvalPhotoTimes, item.reviewPhotoTimes);
      expect(item.rejectionPhotoTimes, isEmpty);
    });
  });

  group('ChecklistItemEvent.photoTimes - fullHistory 정렬', () {
    test('submission 이벤트가 photoUrls 와 같은 순서의 photoTimes 를 가진다', () {
      final item = ChecklistItem.fromJson({
        'id': 'item-1',
        'title': 'Test',
        'is_completed': true,
        'submissions': [
          {
            'id': 's1',
            'version': 1,
            'note': 'done',
            'submitted_at': '2026-03-05T09:00:00',
          },
        ],
        'reviews_log': [],
        'files': [
          {
            'id': 'f1',
            'context': 'submission',
            'context_id': 's1',
            'file_url': 'http://x/a.webp',
            'file_type': 'photo',
            'sort_order': 0,
            'capture_time': '2026-03-05T08:55:00Z',
          },
          {
            'id': 'f2',
            'context': 'submission',
            'context_id': 's1',
            'file_url': 'http://x/b.webp',
            'file_type': 'photo',
            'sort_order': 1,
            'received_at': '2026-03-05T09:01:00Z',
          },
        ],
        'messages': [],
      }, 0);

      final subEvent = item.fullHistory.firstWhere(
        (e) => e.photoUrls.isNotEmpty,
      );
      expect(subEvent.photoUrls, ['http://x/a.webp', 'http://x/b.webp']);
      expect(subEvent.photoTimes.length, subEvent.photoUrls.length);
      expect(subEvent.photoTimes[0], DateTime.utc(2026, 3, 5, 8, 55));
      expect(subEvent.photoTimes[1], isNull); // capture 없음 → null(No time)
    });

    test('photoTimes 기본값은 빈 리스트', () {
      const event = ChecklistItemEvent(type: 'comment');
      expect(event.photoTimes, isEmpty);
    });
  });
}
