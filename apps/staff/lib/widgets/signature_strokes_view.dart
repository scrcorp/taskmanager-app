/// 정규화된 서명 stroke 를 그리는 위젯.
///
/// 0..1 로 정규화된 stroke (SignatureStrokes) 를 받아 주어진 박스 안에
/// aspect 비율을 유지하며 렌더한다. notice_detail / PDF view / Sign sheet 의
/// "저장된 서명" 프리뷰에서 공통으로 사용한다 (mockup 의 SignatureView 대응).
import 'package:flutter/material.dart';

import '../models/warning.dart';

class SignatureStrokesView extends StatelessWidget {
  final SignatureStrokes signature;
  final Color color;
  final double strokeWidth;

  const SignatureStrokesView({
    super.key,
    required this.signature,
    this.color = const Color(0xFF1A1C22),
    this.strokeWidth = 2.4,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _StrokesPainter(
        signature: signature,
        color: color,
        strokeWidth: strokeWidth,
      ),
    );
  }
}

class _StrokesPainter extends CustomPainter {
  final SignatureStrokes signature;
  final Color color;
  final double strokeWidth;

  _StrokesPainter({
    required this.signature,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (signature.isEmpty || size.width <= 0 || size.height <= 0) return;

    // aspect 를 유지하며 박스 안에 맞춘다 (xMidYMid meet 와 동일한 효과).
    final aspect = signature.aspect ?? 1.0;
    double drawW = size.width;
    double drawH = drawW / aspect;
    if (drawH > size.height) {
      drawH = size.height;
      drawW = drawH * aspect;
    }
    final dx = (size.width - drawW) / 2;
    final dy = (size.height - drawH) / 2;

    // 잉크 중앙배치: 한쪽에 치우쳐 그려도 stroke bbox 중심을 pad-space 중심으로
    // 옮긴다 (크기 유지, translate 만). ox/oy 는 0..1 공간의 보정값.
    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;
    for (final s in signature.strokes) {
      for (final p in s) {
        if (p[0] < minX) minX = p[0];
        if (p[0] > maxX) maxX = p[0];
        if (p[1] < minY) minY = p[1];
        if (p[1] > maxY) maxY = p[1];
      }
    }
    final ox = minX.isFinite ? 0.5 - (minX + maxX) / 2 : 0.0;
    final oy = minY.isFinite ? 0.5 - (minY + maxY) / 2 : 0.0;
    double mapX(double x) => dx + (x + ox) * drawW;
    double mapY(double y) => dy + (y + oy) * drawH;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final stroke in signature.strokes) {
      if (stroke.isEmpty) continue;
      final path = Path();
      final first = stroke.first;
      path.moveTo(mapX(first[0]), mapY(first[1]));
      if (stroke.length == 1) {
        // 점 하나 — 보이도록 아주 짧은 선.
        path.lineTo(mapX(first[0]) + 0.5, mapY(first[1]));
      } else {
        for (var i = 1; i < stroke.length; i++) {
          final p = stroke[i];
          path.lineTo(mapX(p[0]), mapY(p[1]));
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_StrokesPainter old) =>
      old.signature != signature ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}
