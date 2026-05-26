/// TipEntryDialog pure logic — Phase 5 Recovery F.
///
/// 금액 파싱 / 분배 합계 / Submit 활성 / Split evenly 계산.

/// 입력 문자열을 double 로 파싱. 비어있거나 invalid 면 0.
double parseAmount(String? raw) {
  if (raw == null) return 0;
  return double.tryParse(raw.trim()) ?? 0;
}

/// 선택된 receiver 들의 amount 합. 각 amount 는 string 으로 들어옴 (UI input).
double computeDistSum(Iterable<String> amountTexts) {
  return amountTexts.fold<double>(0, (s, t) => s + parseAmount(t));
}

/// 분배 합이 card tips 를 초과했는지. 부동소수점 오차 0.001 tolerance.
bool overDistributed(double distSum, double cardTips) {
  return distSum > cardTips + 0.001;
}

/// Submit 활성 여부.
///   - cardRaw 또는 cashRaw 가 빈 문자열(trim) → false
///   - 분배 합이 card tips 초과 → false
///   - 그 외 → true
bool canSubmitTip({
  required String cardRaw,
  required String cashRaw,
  required double distSum,
}) {
  if (cardRaw.trim().isEmpty) return false;
  if (cashRaw.trim().isEmpty) return false;
  return !overDistributed(distSum, parseAmount(cardRaw));
}

/// Split evenly — 각 receiver 가 받을 금액 (소수점 2자리 fix).
/// receiverCount = 0 또는 cardTips <= 0 이면 "0.00".
String splitEvenlyAmount(double cardTips, int receiverCount) {
  if (receiverCount <= 0 || cardTips <= 0) return '0.00';
  return (cardTips / receiverCount).toStringAsFixed(2);
}
