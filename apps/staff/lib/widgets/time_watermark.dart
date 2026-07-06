/// 사진이 "찍힌 시각"을 사진 바로 아래 캡션으로 표시하는 클라이언트 사이드 라벨.
///
/// 픽셀에 굽지 않는다(원본 이미지 불변). 표시 전용이다.
/// 표시 시각은 capture_time(찍힌 시점) 1순위, 없으면 received_at(서버 수신) 폴백 —
/// [photoWatermarkTime] 로 결정한다. 시각이 없어도(레거시·EXIF없음) 캡션 UI 는 그리고,
/// 시각 대신 "No time"(l10n)을 흐리게 표시한다(무음 실패 금지).
///
/// 시각은 모호하지 않게 타임존 라벨(KST/PDT 등)을 함께 표시한다([formatDateTimeWithZone]).
library;

import 'package:flutter/material.dart';
import 'package:htm_core/htm_core.dart';
import '../l10n/app_localizations.dart';
import '../utils/date_utils.dart';

/// 워터마크에 표시할 시각: 찍힌 시점(capture) 우선, 없으면 수신시각(received) 폴백.
DateTime? photoWatermarkTime(DateTime? captureTime, DateTime? receivedAt) =>
    captureTime ?? receivedAt;

/// 시계 아이콘 + "찍힌 시각(타임존 포함)" 라벨. 사진 아래 캡션으로 쓰는 라벨.
/// [color] 미지정 시 보조 텍스트 색(밝은 배경용), 풀스크린 뷰어 등에선 흰색 등을 넘긴다.
class TimeWatermark extends StatelessWidget {
  /// null 이면 시각 대신 "No time"(l10n)을 흐리게 표시한다(레거시·EXIF없음).
  final DateTime? time;
  final Color? color;

  /// 풀스크린 뷰어처럼 사진 위에 크게 띄울 때 true. 기본(false)은 인라인 캡션용 작은 크기.
  final bool large;

  const TimeWatermark({
    super.key,
    required this.time,
    this.color,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final base = color ?? AppColors.textSecondary;
    final hasTime = time != null;
    // 시각 없으면 흐린 톤 + "No time"(l10n) — UI 는 항상 그린다(무음 실패 금지).
    final c = hasTime ? base : base.withValues(alpha: 0.6);
    final label = hasTime
        ? formatDateTimeWithZone(time!)
        : AppL10n.of(context).watermarkNoTime;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.schedule, size: large ? 19 : 15, color: c),
        SizedBox(width: large ? 7 : 5),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: large ? 16 : 13,
              fontWeight: FontWeight.w600,
              color: c,
            ),
          ),
        ),
      ],
    );
  }
}

/// 사진 + 그 아래 "찍힌 시각" 캡션을 함께 그리는 래퍼.
///
/// [time] 이 null 이어도 캡션 UI 는 그리며, 시각 대신 "No time" 을 표시한다.
/// [borderRadius] 가 있으면 사진만 둥글게 클립하고, 캡션은 클립 밖(아래)에 둔다.
class WatermarkedPhoto extends StatelessWidget {
  final Widget child;
  final DateTime? time;
  final BorderRadius? borderRadius;

  const WatermarkedPhoto({
    super.key,
    required this.child,
    required this.time,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final photo = borderRadius != null
        ? ClipRRect(borderRadius: borderRadius!, child: child)
        : child;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        photo,
        const SizedBox(height: 5),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: TimeWatermark(time: time),
        ),
      ],
    );
  }
}
