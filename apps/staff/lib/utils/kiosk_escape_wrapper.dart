/// 키오스크 강제종료(escape) 게스처 wrapper.
///
/// 화면 4개 모서리(각 120x120 hot zone)를 시계방향으로 탭하면 해제:
///   TL → TR → BR → BL  (5초 이내)
/// 시퀀스 자체가 비밀번호 역할이므로 코드 입력은 생략.
/// 순서 틀리거나 5초 초과 → 진행도 reset.
///
/// 매니저 안내용:
///   "If the kiosk gets stuck, tap the four corners of the screen in order —
///    top-left, top-right, bottom-right, bottom-left — within 5 seconds."
///
/// Listener 사용 → 일반 탭/롱프레스를 가로채지 않음.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/app_modal.dart';
import 'kiosk_intent.dart';
import 'kiosk_lock.dart';

enum _Corner { tl, tr, br, bl }

const _sequence = <_Corner>[_Corner.tl, _Corner.tr, _Corner.br, _Corner.bl];
const _windowSeconds = 5;
const _cornerSize = 120.0;

class KioskEscapeWrapper extends StatefulWidget {
  final Widget child;
  const KioskEscapeWrapper({super.key, required this.child});

  @override
  State<KioskEscapeWrapper> createState() => _KioskEscapeWrapperState();
}

class _KioskEscapeWrapperState extends State<KioskEscapeWrapper> {
  int _step = 0;
  Timer? _windowTimer;
  bool _processing = false;

  _Corner? _hitCorner(Offset pos, Size size) {
    final left = pos.dx < _cornerSize;
    final right = pos.dx > size.width - _cornerSize;
    final top = pos.dy < _cornerSize;
    final bottom = pos.dy > size.height - _cornerSize;
    if (top && left) return _Corner.tl;
    if (top && right) return _Corner.tr;
    if (bottom && right) return _Corner.br;
    if (bottom && left) return _Corner.bl;
    return null;
  }

  void _onPointerDown(PointerDownEvent e) {
    if (_processing) return;
    final size = MediaQuery.of(context).size;
    final zone = _hitCorner(e.position, size);
    if (zone == null) return; // 코너가 아닌 위치는 무시 (시퀀스에 영향 없음)

    if (zone == _sequence[_step]) {
      _step++;
      if (_step == 1) _startWindowTimer();
      if (_step == _sequence.length) {
        _onSuccess();
      }
    } else {
      // 순서 틀림 → 처음부터. 단, 틀린 탭이 step 0(=TL) 이라면 그 탭을 새 시작점으로.
      _resetProgress();
      if (zone == _sequence[0]) {
        _step = 1;
        _startWindowTimer();
      }
    }
  }

  void _startWindowTimer() {
    _windowTimer?.cancel();
    _windowTimer = Timer(const Duration(seconds: _windowSeconds), _resetProgress);
  }

  void _resetProgress() {
    _windowTimer?.cancel();
    _windowTimer = null;
    _step = 0;
  }

  Future<void> _onSuccess() async {
    _resetProgress();
    if (_processing) return;
    _processing = true;
    try {
      await KioskIntent.disableTemporarily();
      await KioskLock.stop();
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      if (!mounted) return;
      await AppModal.show(
        context,
        title: 'Kiosk Unlocked',
        message:
            'Lock disabled. It will re-enable automatically in 5 minutes.',
        type: ModalType.info,
      );
    } finally {
      _processing = false;
    }
  }

  @override
  void dispose() {
    _windowTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      child: widget.child,
    );
  }
}
