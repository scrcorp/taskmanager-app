/// 근무 가용성(Work Availability) 화면
///
/// 갈래:
///  1) 이미 설정됨(isSet)          → 조회 전용 뷰 + "매니저에게 문의" 배너
///  2) 미설정                      → 전부 Off 인 주간 미리보기 +
///       - can_edit(당분간 최초 1회): "Set up" 버튼 → 누르면 편집 모드로 전환
///         (진입 즉시 편집 아님)
///       - !can_edit: "매니저가 설정" 안내 배너
/// 요일은 항상 일요일 시작(Sun→Sat). 하루 상태 3종:
/// Off(해치/회색) / "HH:MM–HH:MM"(sky) / Full day(purple).
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:htm_core/htm_core.dart';

import '../../l10n/app_localizations.dart';
import '../../models/availability.dart';
import '../../providers/availability_provider.dart';
import '../../services/availability_service.dart';
import '../../utils/toast_manager.dart';
import '../../widgets/app_header.dart';

/// range 상태 색상 (sky)
const _skyColor = Color(0xFF0EA5E9);
const _skyBg = Color(0x1F0EA5E9); // ~12% opacity
/// full 상태 색상 (purple)
const _purpleColor = Color(0xFF7C3AED);
const _purpleBg = Color(0x1F7C3AED); // ~12% opacity

/// "HH:MM" 두 개의 시간 문자열로 근무 길이를 계산해 "(Nh)" / "(Nh Mm)" 로 포맷.
/// 자정을 넘기는 야간 근무를 허용하려고 (end - start) 에 1440분(24h)을 더해
/// 모듈로를 취한다. start == end 면 0분.
String _fmtDuration(String start, String end) {
  int toMin(String hhmm) {
    final parts = hhmm.split(':');
    final h = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
    return h * 60 + m;
  }

  final minutes = ((toMin(end) - toMin(start)) + 1440) % 1440;
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '(${h}h)' : '(${h}h ${m}m)';
}

/// 서버가 내려준 사람이 읽을 수 있는 에러 메시지("detail")를 추출한다.
/// DioException 이고 응답 body 에 문자열 detail 이 있으면 그걸 반환, 아니면 null.
String? _serverDetail(Object e) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map) {
      final detail = data['detail'];
      // 문자열 detail (HTTPException) 은 그대로 노출.
      if (detail is String) return detail;
      // FastAPI/pydantic 422 는 detail 이 [{loc,msg,type}, ...] 리스트 → 첫 msg.
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first['msg'] is String) {
          return first['msg'] as String;
        }
      }
    }
  }
  return null;
}

class WorkAvailabilityScreen extends ConsumerStatefulWidget {
  const WorkAvailabilityScreen({super.key});

  @override
  ConsumerState<WorkAvailabilityScreen> createState() =>
      _WorkAvailabilityScreenState();
}

class _WorkAvailabilityScreenState
    extends ConsumerState<WorkAvailabilityScreen> {
  /// 최초 1회 설정 진입 여부 — 미설정 화면의 "Set up" 버튼을 눌러야 편집 모드로 전환.
  /// (진입 즉시 편집 화면을 띄우지 않는다.)
  bool _editing = false;

  /// 요일 인덱스(0=Sun..6=Sat) → 로컬라이즈된 요일명
  String _weekdayLabel(AppL10n t, int day) {
    switch (day) {
      case 0:
        return t.weekdaySunday;
      case 1:
        return t.weekdayMonday;
      case 2:
        return t.weekdayTuesday;
      case 3:
        return t.weekdayWednesday;
      case 4:
        return t.weekdayThursday;
      case 5:
        return t.weekdayFriday;
      default:
        return t.weekdaySaturday;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final async = ref.watch(myAvailabilityProvider);

    return PopScope(
      canPop: !_editing,
      // 편집 중 시스템/제스처 뒤로가기도 화면을 닫지 않고 미리보기로 복귀(헤더 뒤로가기와 일치).
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _editing) setState(() => _editing = false);
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Column(
          children: [
            AppHeader(
              title: t.workAvailabilityTitle,
              isDetail: true,
              // 편집 중 뒤로가기는 화면을 닫지 않고 미리보기로 복귀.
              onBack: _editing
                  ? () => setState(() => _editing = false)
                  : () => context.pop(),
            ),
            Expanded(
              child: async.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                ),
                error: (_, __) => _ErrorView(
                  onRetry: () => ref.invalidate(myAvailabilityProvider),
                ),
                data: (availability) {
                  // 1) 이미 설정됨 → 조회 전용.
                  if (availability.isSet) {
                    return RefreshIndicator(
                      color: AppColors.accent,
                      onRefresh: () async =>
                          ref.invalidate(myAvailabilityProvider),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        children: [
                          Text(
                            t.workAvailabilityIntro,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _DayCard(
                            days: availability.days,
                            weekdayLabel: (d) => _weekdayLabel(t, d),
                            offLabel: t.workAvailabilityOff,
                            fullLabel: t.workAvailabilityFullDay,
                          ),
                          const SizedBox(height: 16),
                          _NoticeBanner(
                            title: t.workAvailabilityNoticeTitle,
                            body: t.workAvailabilityNoticeBody,
                          ),
                        ],
                      ),
                    );
                  }
                  // 2) 미설정 + Set up 버튼 눌러 편집 진입(당분간 최초 1회) → 편집 화면.
                  if (_editing && availability.canEdit) {
                    return _EditableAvailability(
                      initial: availability.days,
                      weekdayLabel: (d) => _weekdayLabel(t, d),
                      onSaved: () {
                        if (mounted) setState(() => _editing = false);
                      },
                    );
                  }
                  // 3) 미설정(=전부 Off) 미리보기 + (편집가능 시) Set up 버튼 / (아니면) 매니저 문의.
                  return RefreshIndicator(
                    color: AppColors.accent,
                    onRefresh: () async =>
                        ref.invalidate(myAvailabilityProvider),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      children: [
                        Text(
                          t.workAvailabilityNotSetIntro,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _DayCard(
                          days: availability.days,
                          weekdayLabel: (d) => _weekdayLabel(t, d),
                          offLabel: t.workAvailabilityOff,
                          fullLabel: t.workAvailabilityFullDay,
                        ),
                        const SizedBox(height: 20),
                        if (availability.canEdit) ...[
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => setState(() => _editing = true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                t.workAvailabilitySetUp,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          // 최초 1회만 본인 설정 가능(설정 후 수정 불가) — 명시.
                          Text(
                            t.workAvailabilitySetUpNote,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ] else
                          _NoticeBanner(
                            title: t.workAvailabilityEmptyTitle,
                            body: t.workAvailabilityEmptyBody,
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 요일별 가용성 카드 (7행)
class _DayCard extends StatelessWidget {
  final List<AvailabilityDay> days;
  final String Function(int day) weekdayLabel;
  final String offLabel;
  final String fullLabel;

  const _DayCard({
    required this.days,
    required this.weekdayLabel,
    required this.offLabel,
    required this.fullLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var day = 0; day < 7; day++) ...[
            if (day > 0) const Divider(height: 1, color: AppColors.border),
            _DayRow(
              label: weekdayLabel(day),
              // 주말(일/토)은 요일명을 muted 처리 (mockup 규칙)
              muted: day == 0 || day == 6,
              day: days[day],
              offLabel: offLabel,
              fullLabel: fullLabel,
            ),
          ],
        ],
      ),
    );
  }
}

/// 한 요일 행 — 요일명 + 상태 pill
class _DayRow extends StatelessWidget {
  final String label;
  final bool muted;
  final AvailabilityDay day;
  final String offLabel;
  final String fullLabel;

  const _DayRow({
    required this.label,
    required this.muted,
    required this.day,
    required this.offLabel,
    required this.fullLabel,
  });

  @override
  Widget build(BuildContext context) {
    final showDuration =
        day.state == AvailabilityState.range &&
        day.startTime != null &&
        day.endTime != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: muted ? AppColors.textMuted : AppColors.text,
              ),
            ),
          ),
          if (showDuration) ...[
            Text(
              _fmtDuration(day.startTime!, day.endTime!),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 8),
          ],
          _statePill(),
        ],
      ),
    );
  }

  Widget _statePill() {
    switch (day.state) {
      case AvailabilityState.off:
        return _Pill(
          text: offLabel,
          color: AppColors.textMuted,
          bg: const Color(0xFFF1F5F9),
        );
      case AvailabilityState.full:
        return _Pill(text: fullLabel, color: _purpleColor, bg: _purpleBg);
      case AvailabilityState.range:
        final start = day.startTime ?? '';
        final end = day.endTime ?? '';
        return _Pill(text: '$start–$end', color: _skyColor, bg: _skyBg);
    }
  }
}

/// 상태 pill (둥근 배경 라벨)
class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  final Color bg;

  const _Pill({required this.text, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: color,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// "잘못됐으면 매니저/슈퍼바이저 문의" 안내 배너
class _NoticeBanner extends StatelessWidget {
  final String title;
  final String body;

  const _NoticeBanner({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.33)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 20, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 로드 실패 뷰
class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              t.workAvailabilityLoadFailed,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: Text(t.actionRetry)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// 편집 화면 (미설정 && can_edit) — 직원이 직접 주간 가용성을 설정.
// ─────────────────────────────────────────────────────────────────────────

/// off 세그먼트 선택 색 (slate)
const _slateColor = Color(0xFF94A3B8);

/// 직원 셀프 편집 화면 — 요일별 Off/Time/Full 세그먼트 + 시간대 + 저장 버튼.
class _EditableAvailability extends ConsumerStatefulWidget {
  final List<AvailabilityDay> initial;
  final String Function(int day) weekdayLabel;

  /// 저장 성공 후 부모에 알림 — 부모가 _editing 을 해제해 조회 전용으로 복귀시킨다.
  final VoidCallback onSaved;

  const _EditableAvailability({
    required this.initial,
    required this.weekdayLabel,
    required this.onSaved,
  });

  @override
  ConsumerState<_EditableAvailability> createState() =>
      _EditableAvailabilityState();
}

class _EditableAvailabilityState extends ConsumerState<_EditableAvailability> {
  late List<AvailabilityDay> _days;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _days = [
      for (var i = 0; i < 7; i++)
        AvailabilityDay(
          dayOfWeek: i,
          state: widget.initial[i].state,
          startTime: widget.initial[i].startTime,
          endTime: widget.initial[i].endTime,
        ),
    ];
  }

  /// 요일 상태 변경. range 로 바꾸면 기존 시간(없으면 09:00–17:00)을 유지.
  void _setDayState(int day, AvailabilityState state) {
    setState(() {
      final cur = _days[day];
      _days[day] = state == AvailabilityState.range
          ? AvailabilityDay(
              dayOfWeek: day,
              state: state,
              startTime: cur.startTime ?? '09:00',
              endTime: cur.endTime ?? '17:00',
            )
          : AvailabilityDay(dayOfWeek: day, state: state);
    });
  }

  void _setTime(int day, {String? start, String? end}) {
    setState(() {
      final cur = _days[day];
      _days[day] = AvailabilityDay(
        dayOfWeek: day,
        state: AvailabilityState.range,
        startTime: start ?? cur.startTime ?? '09:00',
        endTime: end ?? cur.endTime ?? '17:00',
      );
    });
  }

  int get _activeCount =>
      _days.where((d) => d.state != AvailabilityState.off).length;

  Future<void> _save() async {
    if (_activeCount == 0 || _saving) return;
    final t = AppL10n.of(context);

    // 저장 전 검증: range 요일은 시작/종료가 모두 있고 서로 달라야 한다.
    // (야간 근무 허용 — start < end 를 강제하지 않는다.)
    for (final d in _days) {
      if (d.state != AvailabilityState.range) continue;
      final start = d.startTime;
      final end = d.endTime;
      if (start == null || end == null || start == end) {
        ToastManager().error(
          context,
          t.workAvailabilitySameTimeError(widget.weekdayLabel(d.dayOfWeek)),
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      await ref.read(availabilityServiceProvider).updateMyAvailability(_days);
      if (!mounted) return;
      // 저장 성공 → 프로바이더 무효화. 재조회되며 조회 전용 뷰로 전환된다.
      ref.invalidate(myAvailabilityProvider);
      ToastManager().success(context, t.workAvailabilitySaved);
      // 부모의 편집 플래그 해제 → 저장 직후 뒤로가기 1탭 먹통 방지.
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      // 서버가 사람이 읽을 수 있는 detail 을 주면 그대로 노출(원인+다음 행동),
      // 없으면 일반 메시지로 폴백.
      ToastManager().error(
        context,
        _serverDetail(e) ?? t.workAvailabilitySaveFailed,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final canSave = _activeCount > 0 && !_saving;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            children: [
              Text(
                t.workAvailabilityEditIntro,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var day = 0; day < 7; day++) ...[
                      if (day > 0)
                        const Divider(height: 1, color: AppColors.border),
                      _EditableDayRow(
                        label: widget.weekdayLabel(day),
                        muted: day == 0 || day == 6,
                        day: _days[day],
                        onState: (s) => _setDayState(day, s),
                        onPickStart: () => _pickTime(day, isStart: true),
                        onPickEnd: () => _pickTime(day, isStart: false),
                        offLabel: t.workAvailabilityStateOff,
                        timeLabel: t.workAvailabilityStateTime,
                        fullLabel: t.workAvailabilityStateFull,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                t.workAvailabilityEditFootnote,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        // 하단 고정 저장 버튼
        Container(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            12 + MediaQuery.of(context).padding.bottom,
          ),
          decoration: const BoxDecoration(
            color: AppColors.white,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: SizedBox(
            height: 52,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canSave ? _save : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                disabledBackgroundColor: AppColors.accent.withValues(
                  alpha: 0.45,
                ),
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      t.workAvailabilitySave,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  /// 5분 단위 시간 선택 바텀시트. 선택 시 해당 요일 시간에 반영.
  Future<void> _pickTime(int day, {required bool isStart}) async {
    final cur = _days[day];
    final initial = isStart ? cur.startTime : cur.endTime;
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _TimeSlotSheet(
        title: isStart
            ? AppL10n.of(ctx).workAvailabilityStartTime
            : AppL10n.of(ctx).workAvailabilityEndTime,
        selected: initial,
      ),
    );
    if (picked == null) return;
    if (isStart) {
      _setTime(day, start: picked);
    } else {
      _setTime(day, end: picked);
    }
  }
}

/// 편집 화면의 한 요일 행 — 요일명 + Off/Time/Full 세그먼트 + (Time 시) 시간대.
class _EditableDayRow extends StatelessWidget {
  final String label;
  final bool muted;
  final AvailabilityDay day;
  final ValueChanged<AvailabilityState> onState;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final String offLabel;
  final String timeLabel;
  final String fullLabel;

  const _EditableDayRow({
    required this.label,
    required this.muted,
    required this.day,
    required this.onState,
    required this.onPickStart,
    required this.onPickEnd,
    required this.offLabel,
    required this.timeLabel,
    required this.fullLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              SizedBox(
                width: 38,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: muted ? AppColors.textMuted : AppColors.text,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Segmented(
                  state: day.state,
                  onState: onState,
                  offLabel: offLabel,
                  timeLabel: timeLabel,
                  fullLabel: fullLabel,
                ),
              ),
            ],
          ),
        ),
        if (day.state == AvailabilityState.range)
          Builder(
            builder: (context) {
              final start = day.startTime ?? '09:00';
              final end = day.endTime ?? '17:00';
              return Padding(
                padding: const EdgeInsets.fromLTRB(58, 0, 12, 12),
                child: Row(
                  children: [
                    _TimeField(value: start, onTap: onPickStart),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '–',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                    _TimeField(value: end, onTap: onPickEnd),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _fmtDuration(start, end),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

/// Off / Time / Full 3분할 세그먼트 컨트롤.
class _Segmented extends StatelessWidget {
  final AvailabilityState state;
  final ValueChanged<AvailabilityState> onState;
  final String offLabel;
  final String timeLabel;
  final String fullLabel;

  const _Segmented({
    required this.state,
    required this.onState,
    required this.offLabel,
    required this.timeLabel,
    required this.fullLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _segment(
            offLabel,
            AvailabilityState.off,
            _slateColor,
            AppColors.text,
          ),
          const SizedBox(width: 4),
          _segment(timeLabel, AvailabilityState.range, _skyColor, Colors.white),
          const SizedBox(width: 4),
          _segment(
            fullLabel,
            AvailabilityState.full,
            _purpleColor,
            Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _segment(
    String label,
    AvailabilityState value,
    Color onBg,
    Color onFg,
  ) {
    final selected = state == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => onState(value),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? onBg : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? onFg : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

/// 시간 표시/선택 필드 (탭하면 5분 단위 바텀시트).
class _TimeField extends StatelessWidget {
  final String value;
  final VoidCallback onTap;

  const _TimeField({required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.schedule, size: 14, color: _skyColor),
            const SizedBox(width: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 5분 단위 시/분 분리 선택 바텀시트 — 시 휠 + 분 휠. 스크롤로 선택 후 Done.
/// (한 리스트에 288개 나열하지 않고 시(24)·분(12) 짧은 휠 두 개로 분리.)
class _TimeSlotSheet extends StatefulWidget {
  final String title;
  final String? selected;

  const _TimeSlotSheet({required this.title, this.selected});

  @override
  State<_TimeSlotSheet> createState() => _TimeSlotSheetState();
}

class _TimeSlotSheetState extends State<_TimeSlotSheet> {
  static const int _minStep = 5;
  static final List<int> _minutes = [for (var m = 0; m < 60; m += _minStep) m];

  late int _hour;
  late int _minIdx; // _minutes 인덱스
  late final FixedExtentScrollController _hourCtrl;
  late final FixedExtentScrollController _minCtrl;

  @override
  void initState() {
    super.initState();
    final parts = (widget.selected ?? '09:00').split(':');
    _hour = (int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 9).clamp(0, 23);
    final m = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
    // 5분 그리드에 스냅.
    _minIdx = (m ~/ _minStep).clamp(0, _minutes.length - 1);
    _hourCtrl = FixedExtentScrollController(initialItem: _hour);
    _minCtrl = FixedExtentScrollController(initialItem: _minIdx);
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minCtrl.dispose();
    super.dispose();
  }

  String get _value =>
      '${_hour.toString().padLeft(2, '0')}:${_minutes[_minIdx].toString().padLeft(2, '0')}';

  Widget _wheel({
    required FixedExtentScrollController controller,
    required int count,
    required String Function(int index) label,
    required ValueChanged<int> onChanged,
  }) {
    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: 40,
      perspective: 0.004,
      diameterRatio: 1.4,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: onChanged,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: count,
        builder: (ctx, i) => Center(
          child: Text(
            label(i),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 8, bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.border),
          SizedBox(
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 가운데 선택 하이라이트 밴드
                Container(
                  height: 40,
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  decoration: BoxDecoration(
                    color: AppColors.accentBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: _wheel(
                        controller: _hourCtrl,
                        count: 24,
                        label: (i) => i.toString().padLeft(2, '0'),
                        onChanged: (i) => setState(() => _hour = i),
                      ),
                    ),
                    const Text(
                      ':',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                      ),
                    ),
                    Expanded(
                      child: _wheel(
                        controller: _minCtrl,
                        count: _minutes.length,
                        label: (i) => _minutes[i].toString().padLeft(2, '0'),
                        onChanged: (i) => setState(() => _minIdx = i),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, _value),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  t.actionDone,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
