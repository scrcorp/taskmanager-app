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

import '../../models/warning.dart';

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
  // 마지막으로 렌더된 패드 크기 — stroke 좌표를 0..1 로 정규화할 때 사용.
  Size _padSize = Size.zero;

  bool get hasInk => _points.any((p) => p != null);

  void clear() {
    setState(() => _points.clear());
  }

  /// 그려진 stroke 를 0..1 로 정규화한 벡터로 export 한다 (PNG 경로와 독립).
  ///
  /// Warning 서명 제출(`/sign`) 및 저장된 서명(`/saved-signature`)에 사용.
  /// 잉크가 없으면 null 반환. aspect = 패드 width/height.
  SignatureStrokes? exportStrokes() {
    if (!hasInk) return null;
    final w = _padSize.width;
    final h = _padSize.height;
    if (w <= 0 || h <= 0) return null;
    final strokes = <List<List<double>>>[];
    var current = <List<double>>[];
    for (final p in _points) {
      if (p == null) {
        if (current.isNotEmpty) {
          strokes.add(current);
          current = <List<double>>[];
        }
        continue;
      }
      current.add([
        (p.dx / w).clamp(0.0, 1.0),
        (p.dy / h).clamp(0.0, 1.0),
      ]);
    }
    if (current.isNotEmpty) strokes.add(current);
    if (strokes.isEmpty) return null;
    return SignatureStrokes(strokes: strokes, aspect: w / h);
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                _padSize = Size(constraints.maxWidth, constraints.maxHeight);
                return GestureDetector(
                  onPanStart: (d) => _addPoint(d.localPosition),
                  onPanUpdate: (d) => _addPoint(d.localPosition),
                  onPanEnd: (_) => _addPoint(null),
                  child: CustomPaint(
                    painter: _SignaturePainter(_points),
                    size: Size.infinite,
                  ),
                );
              },
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
