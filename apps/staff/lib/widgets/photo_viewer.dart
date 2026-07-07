/// 사진 풀스크린 뷰어 — 핀치 줌 + 스와이프(여러 장) + 찍힌 시각 캡션.
///
/// 체크리스트 채팅 등에서 사진을 탭하면 이 뷰어를 띄운다.
/// [times] 는 [urls] 와 같은 순서로 정렬된 "찍힌 시각"(capture/received) 리스트.
library;

import 'package:flutter/material.dart';
import 'time_watermark.dart';

/// 사진 풀스크린 뷰어를 연다. [urls] 가 비어 있으면 아무것도 하지 않는다.
void openPhotoViewer(
  BuildContext context, {
  required List<String> urls,
  List<DateTime?> times = const [],
  int initialIndex = 0,
}) {
  if (urls.isEmpty) return;
  final start = initialIndex.clamp(0, urls.length - 1);
  Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) =>
          _PhotoViewerScreen(urls: urls, times: times, initialIndex: start),
    ),
  );
}

class _PhotoViewerScreen extends StatefulWidget {
  final List<String> urls;
  final List<DateTime?> times;
  final int initialIndex;
  const _PhotoViewerScreen({
    required this.urls,
    required this.times,
    required this.initialIndex,
  });

  @override
  State<_PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<_PhotoViewerScreen> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _current = widget.initialIndex;

  DateTime? _timeAt(int i) =>
      i >= 0 && i < widget.times.length ? widget.times[i] : null;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = _timeAt(_current);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: widget.urls.length > 1
            ? Text(
                '${_current + 1} / ${widget.urls.length}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                ),
              )
            : null,
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.urls.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (_, i) => InteractiveViewer(
              minScale: 1.0,
              maxScale: 4.0,
              child: Center(
                child: Image.network(
                  widget.urls[i],
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image,
                    color: Colors.white54,
                    size: 64,
                  ),
                ),
              ),
            ),
          ),
          // 찍힌 시각 캡션 (상단 중앙) — 시각 없어도 "No time" 으로 항상 표시(무음 실패 금지).
          Positioned(
            left: 0,
            right: 0,
            top: 16,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TimeWatermark(
                  time: current,
                  color: Colors.white,
                  large: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
