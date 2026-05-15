/// 서명 캔버스 + 캡처 위젯.
///
/// 가이드 §1.11 / §8.7 결정사항:
/// - 사인 그리기 → "Apply" → preview 상태 → 명시적 Submit.
/// - 좌표 스케일링: Flutter 는 logical pixel 사용이라 web/native 양쪽에서 자동 처리되지만,
///   PNG 캡처 시 pixelRatio 명시 (3.0 권장) 하여 해상도 충분히 확보.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:htm_core/htm_core.dart';

class SignaturePad extends StatefulWidget {
  /// 캡처된 PNG bytes 콜백 (Apply / Save 시 호출).
  final void Function(Uint8List png) onCaptured;
  final double height;
  const SignaturePad({
    super.key,
    required this.onCaptured,
    this.height = 200,
  });

  @override
  State<SignaturePad> createState() => SignaturePadState();
}

class SignaturePadState extends State<SignaturePad> {
  final _key = GlobalKey();
  // 각 stroke = List<Offset?> (null = stroke 종료점). 단일 List<Offset?> 로 누적.
  final List<Offset?> _points = [];

  bool get hasInk => _points.any((p) => p != null);

  void clear() {
    setState(() => _points.clear());
  }

  Future<Uint8List?> capture() async {
    if (!hasInk) return null;
    final ctx = _key.currentContext;
    if (ctx == null) return null;
    final boundary =
        ctx.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return null;
    final data = bytes.buffer.asUint8List();
    widget.onCaptured(data);
    return data;
  }

  void _addPoint(Offset? p) {
    setState(() => _points.add(p));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: RepaintBoundary(
          key: _key,
          child: SizedBox(
            width: double.infinity,
            height: widget.height,
            child: GestureDetector(
              onPanStart: (d) => _addPoint(d.localPosition),
              onPanUpdate: (d) => _addPoint(d.localPosition),
              onPanEnd: (_) => _addPoint(null),
              child: CustomPaint(
                painter: _SignaturePainter(_points),
                size: Size.infinite,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<Offset?> points;
  _SignaturePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    // 흰 배경 (캡처 PNG 가 투명하지 않게).
    final bg = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bg);

    final paint = Paint()
      ..color = const Color(0xFF1A1D27)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      if (a != null && b != null) {
        canvas.drawLine(a, b, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter old) => true;
}
