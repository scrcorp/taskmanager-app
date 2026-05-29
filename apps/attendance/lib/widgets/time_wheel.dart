/// 시각 휠 피커 (Issue 10 Step 4) — 시(00~23) · 분(00~59) 두 컬럼 스크롤.
///
/// 키오스크 터치 친화 (키보드 입력 대신). ListWheelScrollView 기반.

import 'package:flutter/material.dart';
import 'package:htm_core/htm_core.dart';

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
  late int _h;
  late int _m;

  @override
  void initState() {
    super.initState();
    _h = (widget.initialMinutes ~/ 60).clamp(0, 23);
    _m = (widget.initialMinutes % 60).clamp(0, 59);
    _hCtrl = FixedExtentScrollController(initialItem: _h);
    _mCtrl = FixedExtentScrollController(initialItem: _m);
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
              _column(_hCtrl, 24, (v) {
                setState(() => _h = v);
                _emit();
              }),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(':',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.text)),
              ),
              _column(_mCtrl, 60, (v) {
                setState(() => _m = v);
                _emit();
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _column(FixedExtentScrollController ctrl, int count, ValueChanged<int> onSel) {
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
          childCount: count,
          builder: (context, i) {
            return Center(
              child: Text(
                i.toString().padLeft(2, '0'),
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
