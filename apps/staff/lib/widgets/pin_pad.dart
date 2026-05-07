/// 숫자 PIN 입력 패드 (6자리 기본)
///
/// 공용 tablet에서 직원이 clock-in/out 용 6자리 PIN을 입력할 때 사용.
/// 완료 시 `onCompleted(pin)` 콜백으로 값 전달.
/// `enabled`가 false이면 버튼 비활성화 (서버 호출 중).
import 'package:flutter/material.dart';
import '../config/theme.dart';

/// PIN 패드 위젯
class PinPad extends StatefulWidget {
  final int length;
  final bool enabled;
  final ValueChanged<String> onCompleted;

  const PinPad({
    super.key,
    this.length = 6,
    this.enabled = true,
    required this.onCompleted,
  });

  @override
  State<PinPad> createState() => PinPadState();
}

class PinPadState extends State<PinPad> {
  String _value = '';

  /// 외부에서 초기화 가능 (ex. 액션 완료 후)
  void reset() {
    setState(() => _value = '');
  }

  void _append(String digit) {
    if (!widget.enabled) return;
    if (_value.length >= widget.length) return;
    setState(() => _value = '$_value$digit');
    if (_value.length == widget.length) {
      widget.onCompleted(_value);
    }
  }

  void _delete() {
    if (!widget.enabled) return;
    if (_value.isEmpty) return;
    setState(() => _value = _value.substring(0, _value.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.length, (i) {
            final filled = i < _value.length;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: filled ? AppColors.accent : AppColors.border,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 24),
        // keys grid 3x4
        _row(['1', '2', '3']),
        _row(['4', '5', '6']),
        _row(['7', '8', '9']),
        _row(['', '0', 'del']),
      ],
    );
  }

  Widget _row(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: keys.map((k) => _key(k)).toList(),
    );
  }

  Widget _key(String k) {
    Widget content;
    VoidCallback? onTap;
    if (k.isEmpty) {
      return const SizedBox(width: 84, height: 84);
    }
    if (k == 'del') {
      content = const Icon(Icons.backspace_outlined,
          color: AppColors.text, size: 22);
      onTap = widget.enabled ? _delete : null;
    } else {
      content = Text(
        k,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
      );
      onTap = widget.enabled ? () => _append(k) : null;
    }

    return Padding(
      padding: const EdgeInsets.all(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(42),
        child: Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.white,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
          ),
          child: content,
        ),
      ),
    );
  }
}
