/// 토스트 알림 매니저 — 싱글턴 패턴
///
/// Overlay를 사용하여 화면 우상단에 토스트 메시지를 표시.
/// 여러 토스트를 동시에 스택으로 표시하며 자동 소멸.
/// success/error/warning/info 편의 메서드 제공.
import 'package:flutter/material.dart';
import '../widgets/app_toast.dart';

/// 토스트 매니저 싱글턴
///
/// 앱 전역에서 `ToastManager().success(context, 'message')` 형태로 사용.
/// 내부적으로 Overlay에 _ToastOverlay 위젯을 삽입하여 토스트를 관리.
class ToastManager {
  static final ToastManager _instance = ToastManager._();
  factory ToastManager() => _instance;
  ToastManager._();

  OverlayEntry? _overlayEntry;
  /// 현재 표시 중인 토스트 항목 목록
  final List<_ToastItem> _toasts = [];
  final GlobalKey<_ToastOverlayState> _overlayKey = GlobalKey();

  /// 토스트 표시 — 새 항목을 추가하고 Overlay를 갱신
  void show(
    BuildContext context, {
    required String message,
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final id = DateTime.now().microsecondsSinceEpoch;
    _toasts.add(_ToastItem(id: id, message: message, type: type, duration: duration));

    if (_overlayEntry == null) {
      // 첫 토스트: Overlay에 위젯 삽입
      _overlayEntry = OverlayEntry(
        builder: (_) => _ToastOverlay(
          key: _overlayKey,
          toasts: _toasts,
          onRemove: _removeToast,
        ),
      );
      Overlay.of(context).insert(_overlayEntry!);
    } else {
      // 이미 표시 중: 리빌드하여 새 토스트 반영
      _overlayKey.currentState?._rebuild();
    }
  }

  /// 토스트 제거 — 목록에서 삭제 후 비어있으면 Overlay 제거
  void _removeToast(int id) {
    _toasts.removeWhere((t) => t.id == id);
    if (_toasts.isEmpty) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    } else {
      _overlayKey.currentState?._rebuild();
    }
  }

  /// 성공 토스트 (녹색)
  void success(BuildContext context, String message) =>
      show(context, message: message, type: ToastType.success);

  /// 에러 토스트 (빨간색)
  void error(BuildContext context, String message) =>
      show(context, message: message, type: ToastType.error);

  /// 경고 토스트 (노란색)
  void warning(BuildContext context, String message) =>
      show(context, message: message, type: ToastType.warning);

  /// 정보 토스트 (파란색)
  void info(BuildContext context, String message) =>
      show(context, message: message, type: ToastType.info);
}

/// 토스트 항목 데이터
class _ToastItem {
  final int id;
  final String message;
  final ToastType type;
  final Duration duration;

  const _ToastItem({
    required this.id,
    required this.message,
    required this.type,
    required this.duration,
  });
}

/// 토스트 오버레이 위젯 — 우상단에 토스트 목록을 세로 스택으로 표시
class _ToastOverlay extends StatefulWidget {
  final List<_ToastItem> toasts;
  final void Function(int id) onRemove;

  const _ToastOverlay({
    super.key,
    required this.toasts,
    required this.onRemove,
  });

  @override
  State<_ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<_ToastOverlay> {
  /// 외부에서 호출하여 토스트 목록 변경 시 리빌드
  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: widget.toasts
              .map((t) => AppToast(
                    key: ValueKey(t.id),
                    message: t.message,
                    type: t.type,
                    duration: t.duration,
                    onDismiss: () => widget.onRemove(t.id),
                  ))
              .toList(),
        ),
      ),
    );
  }
}
