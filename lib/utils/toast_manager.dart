import 'package:flutter/material.dart';
import '../widgets/app_toast.dart';

class ToastManager {
  static final ToastManager _instance = ToastManager._();
  factory ToastManager() => _instance;
  ToastManager._();

  OverlayEntry? _overlayEntry;
  final List<_ToastItem> _toasts = [];
  final GlobalKey<_ToastOverlayState> _overlayKey = GlobalKey();

  void show(
    BuildContext context, {
    required String message,
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final id = DateTime.now().microsecondsSinceEpoch;
    _toasts.add(_ToastItem(id: id, message: message, type: type, duration: duration));

    if (_overlayEntry == null) {
      _overlayEntry = OverlayEntry(
        builder: (_) => _ToastOverlay(
          key: _overlayKey,
          toasts: _toasts,
          onRemove: _removeToast,
        ),
      );
      Overlay.of(context).insert(_overlayEntry!);
    } else {
      _overlayKey.currentState?._rebuild();
    }
  }

  void _removeToast(int id) {
    _toasts.removeWhere((t) => t.id == id);
    if (_toasts.isEmpty) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    } else {
      _overlayKey.currentState?._rebuild();
    }
  }

  /// Convenience methods
  void success(BuildContext context, String message) =>
      show(context, message: message, type: ToastType.success);

  void error(BuildContext context, String message) =>
      show(context, message: message, type: ToastType.error);

  void warning(BuildContext context, String message) =>
      show(context, message: message, type: ToastType.warning);

  void info(BuildContext context, String message) =>
      show(context, message: message, type: ToastType.info);
}

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
