/// PIN numpad pure logic — Phase 5 Recovery B.
///
/// PinNumpad widget 의 state transition 을 분리한 pure helper.
/// 모두 입력만으로 출력 결정 (no IO, no random).

/// 입력란에 표시할 값. reveal=false 면 자리수만큼 '•' 마스킹.
/// pin 이 빈 문자열이면 ''.
String maskedPin(String pin, bool reveal) {
  if (pin.isEmpty) return '';
  return reveal ? pin : '•' * pin.length;
}

/// Verify Identity 버튼 활성 여부.
///   - enabled=false → false
///   - pin.length < minLength → false
///   - 그 외 → true
bool canSubmitPin(String pin, int minLength, {bool enabled = true}) {
  if (!enabled) return false;
  return pin.length >= minLength;
}

/// 숫자 키 입력. maxLength 도달 시 무시.
/// digit 은 단일 숫자 문자 '0'~'9' 가정.
String appendDigit(String pin, String digit, int maxLength) {
  if (pin.length >= maxLength) return pin;
  return pin + digit;
}

/// 마지막 한 글자 제거. 빈 문자열이면 그대로.
String backspaceDigit(String pin) {
  if (pin.isEmpty) return pin;
  return pin.substring(0, pin.length - 1);
}
