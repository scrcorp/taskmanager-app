/// 시각 휠 피커 (Issue 10 Step 4) — 시(00~23) · 분(step 단위) 두 컬럼 스크롤.
///
/// 키오스크 터치 친화 (키보드 입력 대신). ListWheelScrollView 기반.
/// 분 컬럼은 [scheduleStepMinutes] 배수만 노출한다 — 1분 단위는 터치로 맞추기 어렵고
/// 서버도 키오스크 경로를 같은 step 으로 검증하므로, 저장 못 할 값을 아예 못 고르게 한다.
/// 예외: 넘겨받은 초기값이 step 을 벗어나면 그 값도 눈금에 포함한다 (기존 값 보존).

import 'package:flutter/material.dart';
import 'package:htm_core/htm_core.dart';

import '../utils/schedule_edit_logic.dart';

class TimeWheel extends StatefulWidget {
  final int initialMinutes; // 0..1439 (hh*60+mm)
  final ValueChanged<int> onChanged;

  const TimeWheel({super.key, required this.initialMinutes, required this.onChanged});

  @override
  State<TimeWheel> createState() => _TimeWheelState();
}

class _TimeWheelState extends State<TimeWheel> {
  late final FixedExtentScrollController _hCtrl;
  late final FixedExtentScrollController _mCtrl;
  late final List<int> _minutes; // 분 컬럼에 노출할 값들
  late int _h;
  late int _mIndex;

  int get _m => _minutes[_mIndex];

  @override
  void initState() {
    super.initState();
    final initialMinute = widget.initialMinutes % 60;
    // 분 눈금 = step 배수. 단, 기존 값이 step 을 벗어나 있으면(워크인의 실제 clock-in
    // 시각 등) 그 값도 눈금에 넣어 **화면에 있는 그대로** 보여준다. 임의로 반올림해서
    // 보여주면 매니저가 안 건드린 값이 바뀐 것처럼 보인다. 다른 눈금을 고르는 순간
    // 값은 step 단위가 되고, 이 예외 눈금은 사라진다.
    _minutes = [
      for (var m = 0; m < 60; m += scheduleStepMinutes) m,
      if (initialMinute % scheduleStepMinutes != 0) initialMinute,
    ]..sort();
    _h = (widget.initialMinutes ~/ 60).clamp(0, 23);
    _mIndex = _minutes.indexOf(initialMinute).clamp(0, _minutes.length - 1);
    _hCtrl = FixedExtentScrollController(initialItem: _h);
    _mCtrl = FixedExtentScrollController(initialItem: _mIndex);
  }

  @override
  void dispose() {
    _hCtrl.dispose();
    _mCtrl.dispose();
    super.dispose();
  }

  void _emit() => widget.onChanged(_h * 60 + _m);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: Stack(
        children: [
          // 가운데 선택 하이라이트
          Center(
            child: Container(
              height: 44,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _column(_hCtrl, [for (var h = 0; h < 24; h++) h], (v) {
                setState(() => _h = v);
                _emit();
              }),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(':',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.text)),
              ),
              _column(_mCtrl, _minutes, (v) {
                setState(() => _mIndex = v);
                _emit();
              }),
            ],
          ),
        ],
      ),
    );
  }

  /// [values] 를 순서대로 그리는 휠 컬럼. 콜백은 선택된 **인덱스**를 준다.
  Widget _column(FixedExtentScrollController ctrl, List<int> values, ValueChanged<int> onSel) {
    return SizedBox(
      width: 72,
      child: ListWheelScrollView.useDelegate(
        controller: ctrl,
        itemExtent: 44,
        physics: const FixedExtentScrollPhysics(),
        perspective: 0.004,
        diameterRatio: 1.6,
        onSelectedItemChanged: onSel,
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: values.length,
          builder: (context, i) {
            return Center(
              child: Text(
                values[i].toString().padLeft(2, '0'),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
