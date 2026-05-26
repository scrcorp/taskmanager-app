/// tip_models unit tests — Phase 5 Stage H-2c.

import 'package:attendance/models/tip_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TipReceiver.fromJson', () {
    test('전체 정상', () {
      final r = TipReceiver.fromJson({
        'user_id': 'u1',
        'user_name': 'Sarah',
        'role': 'Barista',
        'worked_hours': 6.5,
      });
      expect(r.userId, 'u1');
      expect(r.userName, 'Sarah');
      expect(r.role, 'Barista');
      expect(r.workedHours, 6.5);
    });

    test('role 빠지면 work_role 으로 fallback', () {
      final r = TipReceiver.fromJson({
        'user_id': 'u1',
        'user_name': 'Sarah',
        'work_role': 'Server',
        'worked_hours': 4,
      });
      expect(r.role, 'Server');
    });

    test('role / work_role 둘 다 없으면 null', () {
      final r = TipReceiver.fromJson({
        'user_id': 'u1',
        'user_name': 'Sarah',
        'worked_hours': 4,
      });
      expect(r.role, isNull);
    });

    test('worked_hours null → 0', () {
      final r = TipReceiver.fromJson({
        'user_id': 'u1',
        'user_name': 'Sarah',
      });
      expect(r.workedHours, 0);
    });

    test('worked_hours int 도 double 로', () {
      final r = TipReceiver.fromJson({
        'user_id': 'u1',
        'user_name': 'Sarah',
        'worked_hours': 8,
      });
      expect(r.workedHours, 8.0);
      expect(r.workedHours, isA<double>());
    });

    test('user_id / user_name 비어있으면 "" fallback', () {
      final r = TipReceiver.fromJson({});
      expect(r.userId, '');
      expect(r.userName, '');
    });

    test('server eligible-receivers 응답 ({id, full_name}) 도 인식', () {
      final r = TipReceiver.fromJson({'id': 'u9', 'full_name': 'Marcus Lee'});
      expect(r.userId, 'u9');
      expect(r.userName, 'Marcus Lee');
    });

    test('user_id 가 우선, id 는 fallback', () {
      final r = TipReceiver.fromJson({'user_id': 'A', 'id': 'B', 'user_name': 'X', 'full_name': 'Y'});
      expect(r.userId, 'A');
      expect(r.userName, 'X');
    });
  });

  group('TipDistribution.toJson', () {
    test('receiver_id + amount 포함', () {
      const d = TipDistribution(receiverId: 'u1', amount: 12.5);
      expect(d.toJson(), {'receiver_id': 'u1', 'amount': 12.5});
    });
  });

  group('TipPayload.toJson', () {
    test('card/cash 소수점 2자리 문자열 + distributions 변환', () {
      const p = TipPayload(
        cardTips: 60,
        cashTipsKept: 12.5,
        distributions: [
          TipDistribution(receiverId: 'u1', amount: 30),
          TipDistribution(receiverId: 'u2', amount: 30),
        ],
      );
      final j = p.toJson();
      expect(j['card_tips'], '60.00');
      expect(j['cash_tips_kept'], '12.50');
      expect(j['distributions'], hasLength(2));
      expect((j['distributions'] as List).first, {'receiver_id': 'u1', 'amount': 30.0});
    });

    test('distributions 빈 list', () {
      const p = TipPayload(cardTips: 10, cashTipsKept: 5, distributions: []);
      final j = p.toJson();
      expect(j['distributions'], isEmpty);
    });

    test('card 0 / cash 0', () {
      const p = TipPayload(cardTips: 0, cashTipsKept: 0, distributions: []);
      expect(p.toJson()['card_tips'], '0.00');
      expect(p.toJson()['cash_tips_kept'], '0.00');
    });
  });
}
