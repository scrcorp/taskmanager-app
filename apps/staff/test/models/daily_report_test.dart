import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/daily_report.dart';

void main() {
  group('DailyReport.fromJson (unified payload)', () {
    Map<String, dynamic> baseJson() => {
          'id': 'r-1',
          'type': 'daily',
          'organization_id': 'org-1',
          'store_id': 'store-1',
          'store_name': 'Downtown',
          'template_id': 'tpl-1',
          'author_id': 'user-1',
          'author_name': 'Alice',
          'title': null,
          'status': 'submitted',
          'report_date': '2026-06-29',
          'submitted_at': '2026-06-29T13:05:00Z',
          'deadline_at': '2026-06-29T14:00:00Z',
          'is_overdue': false,
          'is_late': true,
          'reviewed_by_id': null,
          'reviewed_by_name': null,
          'reviewed_at': null,
          'created_at': '2026-06-29T12:00:00Z',
          'updated_at': '2026-06-29T13:05:00Z',
          'payload': {
            'period': 'dinner',
            'sections': [
              {
                'id': 's-1',
                'title': 'Sales',
                'content': 'Good day',
                'sort_order': 0,
                'template_section_id': 'ts-1',
              },
              {
                'id': 's-2',
                'title': 'Issues',
                'content': null,
                'sort_order': 1,
                'template_section_id': 'ts-2',
              },
            ],
          },
          'comment_count': 1,
          'comments': [
            {
              'id': 'c-1',
              'user_id': 'gm-1',
              'user_name': 'Bob',
              'content': 'Nice',
              'created_at': '2026-06-29T15:00:00Z',
            },
          ],
          'acknowledgement_count': 1,
          'acknowledgements': [
            {
              'user_id': 'gm-1',
              'user_name': 'Bob',
              'acknowledged_at': '2026-06-29T16:00:00Z',
            },
          ],
        };

    test('parses period and sections out of payload', () {
      final r = DailyReport.fromJson(baseJson());
      expect(r.period, 'dinner');
      expect(r.periodLabel, 'Dinner');
      expect(r.sections.length, 2);
      expect(r.sections.first.title, 'Sales');
      expect(r.sections.first.content, 'Good day');
      expect(r.sections.first.templateSectionId, 'ts-1');
      expect(r.sections[1].content, isNull);
      // payload sections carry no description/required by default.
      expect(r.sections.first.isRequired, false);
      expect(r.sections.first.description, isNull);
    });

    test('parses deadline / late / overdue flags', () {
      final r = DailyReport.fromJson(baseJson());
      expect(r.deadlineAt, isNotNull);
      expect(r.isOverdue, false);
      expect(r.isLate, true);
    });

    test('parses acknowledgements and acknowledgedBy', () {
      final r = DailyReport.fromJson(baseJson());
      expect(r.acknowledgementCount, 1);
      expect(r.acknowledgements.single.userName, 'Bob');
      expect(r.acknowledgedBy('gm-1'), true);
      expect(r.acknowledgedBy('nobody'), false);
    });

    test('parses reviewed state when present', () {
      final json = baseJson()
        ..['status'] = 'reviewed'
        ..['reviewed_by_id'] = 'gm-1'
        ..['reviewed_by_name'] = 'Bob'
        ..['reviewed_at'] = '2026-06-29T17:00:00Z';
      final r = DailyReport.fromJson(json);
      expect(r.status, 'reviewed');
      expect(r.statusLabel, 'Reviewed');
      expect(r.reviewedByName, 'Bob');
      expect(r.reviewedAt, isNotNull);
    });

    test('defaults gracefully when payload/optional fields missing', () {
      final r = DailyReport.fromJson({
        'id': 'r-2',
        'store_id': 'store-1',
        'author_id': 'user-1',
        'status': 'draft',
        'report_date': '2026-06-29',
        'created_at': '2026-06-29T12:00:00Z',
        'updated_at': '2026-06-29T12:00:00Z',
      });
      expect(r.type, 'daily');
      expect(r.period, 'lunch');
      expect(r.sections, isEmpty);
      expect(r.deadlineAt, isNull);
      expect(r.isOverdue, false);
      expect(r.acknowledgements, isEmpty);
    });

    test('titlecases unknown period codes', () {
      final json = baseJson();
      (json['payload'] as Map<String, dynamic>)['period'] = 'brunch';
      final r = DailyReport.fromJson(json);
      expect(r.periodLabel, 'Brunch');
    });
  });

  group('DailyReportTemplate.fromJson', () {
    test('reads sections from payload', () {
      final tpl = DailyReportTemplate.fromJson({
        'id': 'tpl-1',
        'name': 'Daily',
        'payload': {
          'sections': [
            {
              'id': 'ts-1',
              'title': 'Sales',
              'description': 'Enter sales summary',
              'is_required': true,
              'sort_order': 0,
            },
          ],
        },
      });
      expect(tpl.sections.single.title, 'Sales');
      expect(tpl.sections.single.description, 'Enter sales summary');
      expect(tpl.sections.single.isRequired, true);
    });
  });

  group('EffectiveReportType.fromJson', () {
    test('parses scope and deadline fields', () {
      final e = EffectiveReportType.fromJson({
        'code': 'lunch',
        'label': 'Lunch',
        'sort_order': 1,
        'is_active': true,
        'default_deadline_local_time': '15:00',
        'deadline_day_offset': 0,
        'scope': 'store',
        'id': 'rt-1',
        'org_type_id': 'rt-org-1',
      });
      expect(e.code, 'lunch');
      expect(e.label, 'Lunch');
      expect(e.scope, 'store');
      expect(e.defaultDeadlineLocalTime, '15:00');
      expect(e.id, 'rt-1');
      expect(e.orgTypeId, 'rt-org-1');
    });

    test('falls back to code when label missing', () {
      final e = EffectiveReportType.fromJson({'code': 'morning'});
      expect(e.label, 'morning');
      expect(e.isActive, true);
    });
  });
}
