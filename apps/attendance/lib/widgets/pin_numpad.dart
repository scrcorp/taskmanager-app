/// PinNumpad — 4~6 자리 단일 input + Show PIN toggle + numpad.
///
/// mockup 결정 (2026-05-22):
///   - 단일 input box (PIN 또는 ● 마스킹)
///   - "Show PIN" / "Hide PIN" 텍스트 toggle (accent 컬러, 크게)
///   - 3x4 grid: 1-9 + CLEAR / 0 / DEL
///   - Verify Identity 버튼 — minLength 이상이면 활성
///
/// Phase 5 Main 화면 안에 widget 으로 삽입.

import 'package:flutter/material.dart';
import 'package:htm_core/htm_core.dart';

import '../l10n/app_localizations.dart';
import '../utils/pin_input_logic.dart';

class PinNumpad extends StatefulWidget {
  final ValueChanged<String> onSubmit;
  final int minLength;
  final int maxLength;
  final bool enabled;

  const PinNumpad({
    super.key,
    required this.onSubmit,
    this.minLength = 4,
    this.maxLength = 6,
    this.enabled = true,
  });

  @override
  State<PinNumpad> createState() => _PinNumpadState();
}

class _PinNumpadState extends State<PinNumpad> {
  String _pin = '';
  bool _reveal = false;

  void _append(String d) {
    if (!widget.enabled) return;
    final next = appendDigit(_pin, d, widget.maxLength);
    if (next == _pin) return;
    setState(() => _pin = next);
  }

  void _backspace() {
    if (!widget.enabled || _pin.isEmpty) return;
    setState(() => _pin = backspaceDigit(_pin));
  }

  void _clear() {
    if (!widget.enabled || _pin.isEmpty) return;
    setState(() => _pin = '');
  }

  void _toggleReveal() {
    if (_pin.isEmpty) return;
    setState(() => _reveal = !_reveal);
  }

  void _submit() {
    if (!widget.enabled) return;
    if (_pin.length < widget.minLength) return;
    final value = _pin;
    setState(() {
      _pin = '';
      _reveal = false;
    });
    widget.onSubmit(value);
  }

  String get _displayValue => maskedPin(_pin, _reveal);

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final canSubmit = canSubmitPin(_pin, widget.minLength, enabled: widget.enabled);
    return LayoutBuilder(
      builder: (ctx, constraints) {
        // 가용 height 에 따라 키 height 동적 계산 — 작은 viewport 에도 fit, 큰 화면에선 더 크게.
        // 고정 영역: input(100) + gap(6) + showPin(40) + gap(8) + 3 keyGaps(24) +
        //            gap(8) + verify(72) + gap(6) + hint(16) = 280
        const fixed = 280.0;
        final available = constraints.maxHeight - fixed;
        final keyH = (available / 4).clamp(64.0, 130.0);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PinInputBox(value: _displayValue, reveal: _reveal),
            const SizedBox(height: 6),
            SizedBox(
              height: 40,
              child: TextButton(
                onPressed: _pin.isEmpty ? null : _toggleReveal,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                child: Text(_reveal ? t.pfPinHide : t.pfPinShow),
              ),
            ),
            const SizedBox(height: 8),
            _Numpad(
              onDigit: _append,
              onClear: _clear,
              onBackspace: _backspace,
              enabledClearDel: _pin.isNotEmpty,
              keyHeight: keyH,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 560,
              height: 72,
              child: ElevatedButton(
                onPressed: canSubmit ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: canSubmit ? 4 : 0,
                ),
                child: Text(
                  t.pfPinVerify,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              t.pfPinHint(widget.minLength, widget.maxLength),
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        );
      },
    );
  }
}

class _PinInputBox extends StatelessWidget {
  final String value;
  final bool reveal;
  const _PinInputBox({required this.value, required this.reveal});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 560,
      height: 92,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 2),
      ),
      child: Text(
        value,
        style: TextStyle(
          fontSize: reveal ? 40 : 46,
          fontWeight: FontWeight.w800,
          color: AppColors.accent,
          letterSpacing: 12,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _Numpad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onClear;
  final VoidCallback onBackspace;
  final bool enabledClearDel;
  final double keyHeight;

  const _Numpad({
    required this.onDigit,
    required this.onClear,
    required this.onBackspace,
    required this.enabledClearDel,
    required this.keyHeight,
  });

  @override
  Widget build(BuildContext context) {
    final digitFont = (keyHeight * 0.45).clamp(28.0, 52.0);
    Widget keyN(String n) => _Key(
          height: keyHeight,
          onTap: () => onDigit(n),
          child: Text(
            n,
            style: TextStyle(fontSize: digitFont, fontWeight: FontWeight.w700, color: AppColors.text),
          ),
        );

    return SizedBox(
      width: 560,
      child: Column(
        children: [
          Row(children: [for (final d in ['1', '2', '3']) Expanded(child: keyN(d))]),
          const SizedBox(height: 8),
          Row(children: [for (final d in ['4', '5', '6']) Expanded(child: keyN(d))]),
          const SizedBox(height: 8),
          Row(children: [for (final d in ['7', '8', '9']) Expanded(child: keyN(d))]),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _Key(
                  height: keyHeight,
                  variant: _KeyVariant.action,
                  onTap: enabledClearDel ? onClear : null,
                  child: Text(
                    AppL10n.of(context).pfPinClear,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.accent),
                  ),
                ),
              ),
              Expanded(child: keyN('0')),
              Expanded(
                child: _Key(
                  height: keyHeight,
                  variant: _KeyVariant.action,
                  onTap: enabledClearDel ? onBackspace : null,
                  child: const Icon(Icons.backspace_outlined, size: 36, color: AppColors.accent),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _KeyVariant { number, action }

class _Key extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;
  final _KeyVariant variant;
  final double height;
  const _Key({
    required this.onTap,
    required this.child,
    required this.height,
    this.variant = _KeyVariant.number,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final bg = variant == _KeyVariant.action
        ? AppColors.bg
        : AppColors.white;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        elevation: variant == _KeyVariant.number && !disabled ? 2 : 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: height,
            alignment: Alignment.center,
            child: Opacity(opacity: disabled ? 0.3 : 1.0, child: child),
          ),
        ),
      ),
    );
  }
}
