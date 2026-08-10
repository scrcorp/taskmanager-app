/// 근태 보정 사유 입력 — preset 칩 + "Other" 자유 입력.
///
/// preset 라벨은 console 의 `correctionPresets.ts` 와 **같은 문자열**이어야 한다.
/// 서버는 이 값을 그대로 attendance_corrections.reason 에 저장하고, 콘솔 Activity
/// History 는 저장된 문자열을 그대로 읽는다 — 한쪽만 바꾸면 이력이 갈라진다.

import 'package:flutter/material.dart';
import 'package:htm_core/htm_core.dart';

/// 보정 사유 프리셋 (console correctionPresets.ts 와 동일).
const kCorrectionReasonPresets = <String>[
  'Forgot to clock in',
  'Forgot to clock out',
  'Wrong time recorded',
  'Device / network issue',
  'Schedule change',
  'Break correction',
];

/// preset 선택 + Other 자유 입력을 묶은 위젯.
///
/// 상태(선택된 preset / 입력 텍스트)는 이 위젯이 들고, 확정된 사유 문자열만
/// [onChanged] 로 올려보낸다. 미선택이거나 Other 인데 비어 있으면 "".
class ReasonPicker extends StatefulWidget {
  final ValueChanged<String> onChanged;

  const ReasonPicker({super.key, required this.onChanged});

  @override
  State<ReasonPicker> createState() => _ReasonPickerState();
}

class _ReasonPickerState extends State<ReasonPicker> {
  String? _preset; // null = 미선택, 'Other' = 자유 입력
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _emit() {
    final preset = _preset;
    if (preset == null || preset == 'Other') {
      widget.onChanged(_ctrl.text.trim());
      return;
    }
    widget.onChanged(preset);
  }

  void _select(String label) {
    setState(() {
      _preset = _preset == label ? null : label;
      if (_preset != 'Other') _ctrl.clear();
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in kCorrectionReasonPresets)
              ReasonChip(label: p, selected: _preset == p, onTap: () => _select(p)),
            ReasonChip(
              label: 'Other',
              selected: _preset == 'Other',
              onTap: () => _select('Other'),
            ),
          ],
        ),
        if (_preset == 'Other') ...[
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: TextField(
              controller: _ctrl,
              maxLines: 2,
              autofocus: true,
              onChanged: (_) => _emit(),
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Describe the reason',
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// 사유 칩 하나. (manage action modal 과 모양을 맞춘다)
class ReasonChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const ReasonChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accent.withValues(alpha: 0.15) : AppColors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.accent : AppColors.text,
            ),
          ),
        ),
      ),
    );
  }
}
