/// 매장 태블릿 Attendance 키오스크 대시보드 (3-column 레이아웃)
///
/// 좌측: Shift Actions (선택된 직원의 상태별 가능 액션만 활성)
///   - Clock In
///   - Clock Out
///   - 10min Break (Paid)
///   - Meal Break (Unpaid)
///   - End Break
/// 중앙: Currently On Shift + Schedule (today-staff API, 각 row 탭 선택)
/// 우측: Current Time (실시간) + Notice Board (notices API)
///
/// 기기 인증(device token) 기반 — JWT 세션 사용하지 않음.
/// 태블릿 전용 (768px 미만 분기 없음).
///
/// UX 흐름:
///   1. 사용자가 리스트에서 본인 row 탭 → _selectedKey 설정 (userId+scheduleId)
///   2. 사이드바에 해당 유저의 상태에 맞는 액션만 활성화
///   3. 액션 버튼 탭 → PIN 화면 (user_id + pin 서버 전송)
///   4. 성공 후 대시보드 복귀 시 선택 해제
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:htm_core/htm_core.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/attendance_dashboard_provider.dart';
import '../../providers/attendance_device_provider.dart';
import '../../widgets/language_switcher.dart';
import 'attendance_pin_screen.dart';
import 'attendance_settings_screen.dart';

/// Clock 액션 — PIN 화면에 전달
enum AttendanceAction {
  clockIn,
  clockOut,
  breakShortPaid,
  breakLongUnpaid,
  breakEnd,
}

extension AttendanceActionX on AttendanceAction {
  /// 서버에 전달할 action 문자열 (`performClockAction` 의 action 파라미터)
  String get apiKey {
    switch (this) {
      case AttendanceAction.clockIn:
        return 'clock-in';
      case AttendanceAction.clockOut:
        return 'clock-out';
      case AttendanceAction.breakShortPaid:
      case AttendanceAction.breakLongUnpaid:
        return 'break-start';
      case AttendanceAction.breakEnd:
        return 'break-end';
    }
  }

  /// break-start 에 첨부할 break_type ('paid_10min' | 'unpaid_meal')
  /// 그 외 action 은 null
  String? get breakType {
    switch (this) {
      case AttendanceAction.breakShortPaid:
        return 'paid_10min';
      case AttendanceAction.breakLongUnpaid:
        return 'unpaid_meal';
      case AttendanceAction.clockIn:
      case AttendanceAction.clockOut:
      case AttendanceAction.breakEnd:
        return null;
    }
  }

  /// UI 표기용 라벨 (영어 fallback). 가능하면 [localizedLabel] 사용.
  String get label {
    switch (this) {
      case AttendanceAction.clockIn:
        return 'Clock In';
      case AttendanceAction.clockOut:
        return 'Clock Out';
      case AttendanceAction.breakShortPaid:
        return '10min Break';
      case AttendanceAction.breakLongUnpaid:
        return 'Meal Break';
      case AttendanceAction.breakEnd:
        return 'End Break';
    }
  }

  /// UI 표기용 라벨 (i18n).
  String localizedLabel(AppL10n t) {
    switch (this) {
      case AttendanceAction.clockIn:
        return t.attMainActionClockIn;
      case AttendanceAction.clockOut:
        return t.attMainActionClockOut;
      case AttendanceAction.breakShortPaid:
        return t.attMainActionShortBreak;
      case AttendanceAction.breakLongUnpaid:
        return t.attMainActionLongBreak;
      case AttendanceAction.breakEnd:
        return t.attMainActionEndBreak;
    }
  }
}

class AttendanceMainScreen extends ConsumerStatefulWidget {
  const AttendanceMainScreen({super.key});

  @override
  ConsumerState<AttendanceMainScreen> createState() =>
      _AttendanceMainScreenState();
}

class _AttendanceMainScreenState extends ConsumerState<AttendanceMainScreen> {
  late Timer _clockTimer;
  DateTime _now = DateTime.now();

  /// 현재 리스트에서 선택된 row 의 composite key.
  /// split-shift 에서 같은 유저의 여러 shift 를 각각 구분하기 위해 (userId, scheduleId) pair.
  /// walk-in 등 scheduleId 가 null 인 경우는 userId 단독.
  /// null 이면 사이드바 액션 전체 비활성.
  String? _selectedKey;

  /// Hidden 5-tap unlock — 헤더의 store name을 4초 안에 5번 연속 탭하면
  /// 키오스크 락이 임시 해제됨. 관리자가 settings 진입을 위한 비밀 제스처.
  int _hiddenTapCount = 0;
  Timer? _hiddenTapResetTimer;
  static const _hiddenTapTarget = 5;
  static const _hiddenTapWindow = Duration(seconds: 4);

  /// Row 의 composite key 계산.
  static String _rowKey(TodayStaffRow r) =>
      r.scheduleId == null ? 'u:${r.userId}' : 'u:${r.userId}|s:${r.scheduleId}';

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    // 대시보드 데이터 폴링 시작 (build 이후)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(attendanceDashboardProvider.notifier).startPolling();
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _hiddenTapResetTimer?.cancel();
    super.dispose();
  }

  /// 헤더 store name 탭 핸들러 — 4초 안에 5번 연속이면 키오스크 락 임시 해제.
  Future<void> _onHiddenTap() async {
    _hiddenTapCount++;
    _hiddenTapResetTimer?.cancel();
    _hiddenTapResetTimer = Timer(_hiddenTapWindow, () {
      _hiddenTapCount = 0;
    });
    if (_hiddenTapCount < _hiddenTapTarget) return;
    _hiddenTapCount = 0;
    _hiddenTapResetTimer?.cancel();
    await KioskIntent.disableTemporarily();
    await KioskLock.stop();
    if (!mounted) return;
    final t = AppL10n.of(context);
    await AppModal.show(
      context,
      title: t.attMainKioskUnlockedTitle,
      message: t.attMainKioskUnlockedMessage,
      type: ModalType.info,
    );
  }

  /// Row 탭 핸들러 — 같은 row 재탭 시 선택 해제, 다른 row 탭 시 전환.
  /// split-shift 지원: 같은 userId 의 다른 scheduleId row 는 별개로 선택 가능.
  void _onRowTap(TodayStaffRow row) {
    final key = _rowKey(row);
    setState(() {
      if (_selectedKey == key) {
        _selectedKey = null;
      } else {
        _selectedKey = key;
      }
    });
  }

  /// 선택된 row 찾기 (없으면 null).
  /// build 안에서 호출될 때 dashboard 상태 변화에 반응하도록 watch 사용.
  /// (핸들러에서 호출될 때도 안전 — 이미 build 사이클 외부라면 dependency 구독만 발생)
  TodayStaffRow? get _selectedRow {
    if (_selectedKey == null) return null;
    final dashboard = ref.watch(attendanceDashboardProvider);
    for (final r in dashboard.staff) {
      if (_rowKey(r) == _selectedKey) return r;
    }
    return null;
  }

  /// 유저 상태 기준으로 특정 액션이 활성화 가능한지 판단.
  /// 상태 매핑:
  ///   - upcoming / soon / late / no_show → Clock In
  ///   - working                          → Clock Out, 10min Break, Meal Break
  ///   - on_break                         → End Break, Clock Out
  ///   - clocked_out / cancelled          → (모두 비활성)
  bool _isActionAllowed(AttendanceAction action, String status, {bool clockedIn = false}) {
    switch (status) {
      case 'upcoming':
      case 'soon':
      case 'no_show':
        return action == AttendanceAction.clockIn;
      case 'late':
        // 'late' 는 서버에서 두 가지 경우에 쓰임:
        //  - clock-in 아직 안 함 → Clock In 가능
        //  - clock-in 이미 했는데 지각 기록 → Clock Out / Break 가능
        if (!clockedIn) return action == AttendanceAction.clockIn;
        return action == AttendanceAction.clockOut ||
            action == AttendanceAction.breakShortPaid ||
            action == AttendanceAction.breakLongUnpaid;
      case 'working':
        return action == AttendanceAction.clockOut ||
            action == AttendanceAction.breakShortPaid ||
            action == AttendanceAction.breakLongUnpaid;
      case 'on_break':
        return action == AttendanceAction.breakEnd ||
            action == AttendanceAction.clockOut;
      case 'clocked_out':
      case 'cancelled':
      default:
        return false;
    }
  }

  /// schedule end 5분 이전 clock-out 이면 early 로 간주.
  /// admin Settings 의 attendance.early_leave_threshold_minutes 와 mismatch 가능 —
  /// 클라는 보수적 default 사용. 서버가 최종 검증.
  static const int _earlyClockOutThresholdMinutes = 5;

  Future<void> _openPin(AttendanceAction action) async {
    final row = _selectedRow;
    if (row == null) return;

    String? reason;
    if (action == AttendanceAction.clockOut) {
      final end = row.scheduledEnd;
      if (end != null) {
        final cutoff = end.subtract(const Duration(minutes: _earlyClockOutThresholdMinutes));
        if (DateTime.now().isBefore(cutoff)) {
          reason = await _promptEarlyClockOutReason(end);
          if (reason == null) {
            // 사용자가 취소 — clock-out 흐름 중단
            return;
          }
        }
      }
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AttendancePinScreen(
          action: action,
          userId: row.userId,
          userName: row.userName,
          reason: reason,
        ),
      ),
    );
    // 성공/실패 모두 대시보드 복귀 시 선택 해제
    if (mounted) {
      setState(() => _selectedKey = null);
    }
  }

  /// Early clock-out 시 사용자에게 confirm + 사유 입력. 사용자가 취소하면 null,
  /// 사유 입력 후 Continue 면 trim 된 사유 문자열 반환.
  Future<String?> _promptEarlyClockOutReason(DateTime scheduledEnd) async {
    final t = AppL10n.of(context);
    final controller = TextEditingController();
    final remaining = scheduledEnd.difference(DateTime.now());
    final h = remaining.inHours;
    final m = remaining.inMinutes % 60;
    final remainText = h > 0
        ? t.attMainDurationHM(h, m)
        : t.attMainDurationM(remaining.inMinutes);

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSt) {
            final hasReason = controller.text.trim().isNotEmpty;
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppColors.warning),
                  const SizedBox(width: 10),
                  Text(t.attMainEarlyClockOutTitle),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.attMainEarlyClockOutMessage(remainText),
                    style: const TextStyle(fontSize: 14, color: AppColors.text),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    t.attMainEarlyClockOutReasonLabel,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    onChanged: (_) => setSt(() {}),
                    autofocus: true,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 300,
                    decoration: InputDecoration(
                      hintText: t.attMainEarlyClockOutReasonHint,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: Text(t.actionCancel),
                ),
                ElevatedButton(
                  onPressed: hasReason
                      ? () => Navigator.of(ctx).pop(controller.text.trim())
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(t.actionContinue),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AttendanceSettingsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final device = ref.watch(attendanceDeviceProvider).device;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(
              storeName: device?.storeName ?? t.commonStore,
              deviceName: device?.deviceName ?? t.commonDevice,
              workDate: device?.workDate,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 좌: Shift Actions ──
                  SizedBox(
                    width: 240,
                    child: SingleChildScrollView(
                      child: _buildShiftActions(
                        storeName: device?.storeName ?? t.commonStore,
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  // ── 중: Currently On Shift + Coming Up + Completed ──
                  // 각 섹션은 최소 높이를 갖고, 내용이 많아지면 자연스럽게 늘어남.
                  // 전체 합이 뷰포트보다 크면 스크롤로 처리.
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildOnShiftSection(),
                          const SizedBox(height: 20),
                          _buildComingUpSection(),
                          const SizedBox(height: 20),
                          _buildCompletedSection(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  // ── 우: Current Time + Notice Board ──
                  SizedBox(
                    width: 260,
                    child: Column(
                      children: [
                        _buildCurrentTime(),
                        const SizedBox(height: 20),
                        Expanded(child: _buildNoticeBoard()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader({
    required String storeName,
    required String deviceName,
    String? workDate,
  }) {
    final t = AppL10n.of(context);
    final localeTag = Localizations.localeOf(context).toString();
    final dashboard = ref.watch(attendanceDashboardProvider);
    // work_date 를 "Wed, Apr 22 2026" 형태로 포매팅 (store tz 기준 서버가 계산한 날짜)
    String? workDateDisplay;
    if (workDate != null && workDate.isNotEmpty) {
      try {
        final d = DateTime.parse(workDate);
        workDateDisplay = DateFormat('EEE, MMM d, y', localeTag).format(d);
      } catch (_) {
        workDateDisplay = workDate;
      }
    }
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _onHiddenTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  storeName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  deviceName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (workDateDisplay != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.accentBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t.attMainWorkDateLabel,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  workDateDisplay,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
          ),
        const Spacer(),
        const LanguageSwitcher(),
        const SizedBox(width: 4),
        IconButton(
          tooltip: t.commonRefresh,
          onPressed: dashboard.loading
              ? null
              : () =>
                  ref.read(attendanceDashboardProvider.notifier).refresh(),
          icon: dashboard.loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.textSecondary,
                  ),
                )
              : const Icon(Icons.refresh_rounded,
                  color: AppColors.textSecondary),
        ),
        IconButton(
          tooltip: t.commonSettings,
          onPressed: _openSettings,
          icon: const Icon(Icons.settings_outlined,
              color: AppColors.textSecondary),
        ),
      ],
    );
  }

  // ─── 좌: Shift Actions ────────────────────────────────────────────

  Widget _buildShiftActions({required String storeName}) {
    final t = AppL10n.of(context);
    final selected = _selectedRow;
    final hasSelection = selected != null;
    final status = selected?.status ?? '';

    // 통일된 라벨 — 'ATTENDANCE' (펼치는 모달 안에서 status 별 적합 액션 활성).
    final IconData triggerIcon = hasSelection
        ? Icons.fact_check_rounded
        : Icons.touch_app_rounded;
    final String triggerLabel = t.attMainAttendanceLabel;
    final String triggerSubtitle = !hasSelection
        ? t.attMainSelectNameFirst
        : status == 'clocked_out' || status == 'cancelled'
            ? t.attMainShiftCompleted
            : t.attMainTapToChooseAction;
    final Color triggerColor =
        (!hasSelection || status == 'clocked_out' || status == 'cancelled')
            ? AppColors.textMuted
            : AppColors.accent;
    final triggerEnabled = hasSelection &&
        status != 'clocked_out' &&
        status != 'cancelled';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.accentBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.store_rounded,
                  size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  storeName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.push_pin, size: 14, color: AppColors.accent),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // 선택된 유저 표시 영역 (없으면 안내 문구만)
        if (hasSelection)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accent, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.attMainSelected,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  selected.userName.isEmpty ? t.commonUnknown : selected.userName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => setState(() => _selectedKey = null),
                  child: Row(
                    children: [
                      const Icon(Icons.close,
                          size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        t.attMainClearSelection,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          const SizedBox.shrink(),
        const SizedBox(height: 24),
        // 단일 trigger 버튼 — 누르면 modal로 액션 전체 펼침.
        _ShiftActionTrigger(
          icon: triggerIcon,
          label: triggerLabel,
          subtitle: triggerSubtitle,
          color: triggerColor,
          enabled: triggerEnabled,
          onTap: _openActionsSheet,
        ),
      ],
    );
  }

  /// 액션 펼침 모달 — 선택된 직원의 status 에 맞는 버튼만 활성.
  Future<void> _openActionsSheet() async {
    final t = AppL10n.of(context);
    final selected = _selectedRow;
    if (selected == null) return;
    final status = selected.status;
    final clockedIn = selected.clockIn != null;
    bool allowed(AttendanceAction a) => _isActionAllowed(a, status, clockedIn: clockedIn);

    final actionEntries = <(
      AttendanceAction,
      Widget Function(Color, double),
      String,
      String,
      Color,
      bool,
    )>[
      (
        AttendanceAction.clockIn,
        (c, s) => Icon(Icons.login_rounded, color: c, size: s),
        t.attMainActionClockIn,
        t.attMainActionClockInSubtitle,
        AppColors.accent,
        false,
      ),
      (
        AttendanceAction.clockOut,
        (c, s) => Icon(Icons.logout_rounded, color: c, size: s),
        t.attMainActionClockOut,
        t.attMainActionClockOutSubtitle,
        AppColors.textSecondary,
        false,
      ),
      (
        AttendanceAction.breakShortPaid,
        _build10minClockIcon,
        t.attMainActionShortBreak,
        t.attMainActionShortBreakSubtitle,
        AppColors.warning,
        false,
      ),
      (
        AttendanceAction.breakLongUnpaid,
        (c, s) => Icon(Icons.restaurant_rounded, color: c, size: s),
        t.attMainActionLongBreak,
        t.attMainActionLongBreakSubtitle,
        AppColors.warning,
        true,
      ),
      (
        AttendanceAction.breakEnd,
        (c, s) => Icon(Icons.play_circle_outline_rounded, color: c, size: s),
        t.attMainActionEndBreak,
        t.attMainActionEndBreakSubtitle,
        AppColors.success,
        false,
      ),
    ];

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: t.actionClose,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (ctx, _, __) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.attMainChooseAction,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.accent,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  selected.userName.isEmpty
                                      ? t.commonUnknown
                                      : selected.userName,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.text,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            icon: const Icon(Icons.close_rounded,
                                size: 28, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // 2-column grid — 5개 버튼.
                      Wrap(
                        spacing: 14,
                        runSpacing: 14,
                        children: [
                          for (final entry in actionEntries)
                            SizedBox(
                              width: 200,
                              child: _ShiftActionButton(
                                iconBuilder: entry.$2,
                                label: entry.$3,
                                subtitle: entry.$4,
                                color: entry.$5,
                                isFilled: entry.$6,
                                enabled: allowed(entry.$1),
                                onTap: () {
                                  Navigator.of(ctx).pop();
                                  _openPin(entry.$1);
                                },
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── 중: Currently On Shift ───────────────────────────────────────

  Widget _buildOnShiftSection() {
    final t = AppL10n.of(context);
    final dashboard = ref.watch(attendanceDashboardProvider);
    // 출근 후 working / on_break, 또는 지각이지만 clock-in 한 케이스만 포함.
    // (late + clockIn null 인 케이스는 Not Clocked In 섹션에서 처리)
    final rows = dashboard.staff
        .where((r) =>
            r.status == 'working' ||
            r.status == 'on_break' ||
            (r.status == 'late' && r.clockIn != null))
        .toList();

    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                t.attMainClockedIn,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.successBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  t.attMainActiveBadge(rows.length),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 120),
            child: rows.isEmpty
                ? _Placeholder(text: t.attMainNoOneOnShift)
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _OnShiftCard(
                      row: rows[i],
                      selected: _rowKey(rows[i]) == _selectedKey,
                      onTap: () => _onRowTap(rows[i]),
                    ),
                  ),
          ),
          if (dashboard.error != null) ...[
            const SizedBox(height: 8),
            Text(
              dashboard.error!,
              style:
                  const TextStyle(fontSize: 11, color: AppColors.danger),
            ),
          ],
        ],
      ),
    );
  }

  // ─── 중: Coming Up Next ───────────────────────────────────────────
  //
  // 4 그룹 (server 가 status 로 내려줌) → upcoming → soon → late → no_show
  // 각 그룹 내 정렬: scheduled_start 오름차순.
  // storeNow 는 _now 를 store tz offset 만큼 보정한 "벽시계" 시각.

  Widget _buildComingUpSection() {
    final t = AppL10n.of(context);
    final dashboard = ref.watch(attendanceDashboardProvider);

    // Eager 모델 전환 후: 서버가 effective status (upcoming/soon/late/no_show)를
    // 이미 계산해서 내려준다. 클라이언트는 status 로만 분기한다.
    _ComingUpGroup classify(TodayStaffRow r) {
      switch (r.status) {
        case 'no_show':
          return _ComingUpGroup.noShow;
        case 'late':
          return _ComingUpGroup.late_;
        case 'soon':
          return _ComingUpGroup.soon;
        default:
          return _ComingUpGroup.upcoming;
      }
    }

    // 아직 출근 안 한 상태들 — 서버가 보내주는 값 기준.
    // 'late' 는 2가지 경우:
    //   (a) clock_in 전인데 시간 지남 → Not Clocked In 섹션에 표시 (선택 후 Clock In 가능)
    //   (b) clock_in 후에도 지각으로 기록됨 → 이미 On Shift 섹션에서 표시됨
    // 이 섹션에서는 (a) 만 후보로 포함 (clockIn == null).
    final candidates = dashboard.staff
        .where((r) => const {'upcoming', 'soon', 'late', 'no_show'}.contains(r.status))
        .where((r) => r.clockIn == null)
        .toList();

    final upcoming = <TodayStaffRow>[];
    final soon = <TodayStaffRow>[];
    final late_ = <TodayStaffRow>[];
    final noShow = <TodayStaffRow>[];
    for (final r in candidates) {
      switch (classify(r)) {
        case _ComingUpGroup.upcoming:
          upcoming.add(r);
          break;
        case _ComingUpGroup.soon:
          soon.add(r);
          break;
        case _ComingUpGroup.late_:
          late_.add(r);
          break;
        case _ComingUpGroup.noShow:
          noShow.add(r);
          break;
      }
    }

    int cmpStart(TodayStaffRow a, TodayStaffRow b) {
      final aStart = a.scheduledStart;
      final bStart = b.scheduledStart;
      if (aStart == null && bStart == null) return 0;
      if (aStart == null) return 1;
      if (bStart == null) return -1;
      return aStart.compareTo(bStart);
    }

    upcoming.sort(cmpStart);
    soon.sort(cmpStart);
    late_.sort(cmpStart);
    noShow.sort(cmpStart);

    // 표시 순: upcoming → soon → late → noShow
    final rows = <_ComingUpEntry>[
      for (final r in upcoming) _ComingUpEntry(r, _ComingUpGroup.upcoming),
      for (final r in soon) _ComingUpEntry(r, _ComingUpGroup.soon),
      for (final r in late_) _ComingUpEntry(r, _ComingUpGroup.late_),
      for (final r in noShow) _ComingUpEntry(r, _ComingUpGroup.noShow),
    ];

    // 배지 — 있는 그룹만 렌더. 색 단계: muted / yellow / orange / red.
    final badges = <Widget>[];
    if (upcoming.isNotEmpty) {
      badges.add(_countBadge(
        label: t.attMainBadgeUpcoming(upcoming.length),
        bg: AppColors.bg,
        fg: AppColors.textMuted,
      ));
    }
    if (soon.isNotEmpty) {
      badges.add(_countBadge(
        label: t.attMainBadgeSoon(soon.length),
        bg: _soonBg,
        fg: _soonColor,
      ));
    }
    if (late_.isNotEmpty) {
      badges.add(_countBadge(
        label: t.attMainBadgeLate(late_.length),
        bg: AppColors.warningBg,
        fg: AppColors.warning,
      ));
    }
    if (noShow.isNotEmpty) {
      badges.add(_countBadge(
        label: t.attMainBadgeNoShow(noShow.length),
        bg: AppColors.dangerBg,
        fg: AppColors.danger,
      ));
    }
    // 하나도 없으면 기본 "0 UPCOMING" 회색 배지 유지 (empty state 와 조화)
    if (badges.isEmpty) {
      badges.add(_countBadge(
        label: t.attMainBadgeUpcoming(0),
        bg: AppColors.bg,
        fg: AppColors.textMuted,
      ));
    }

    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                t.attMainNotClockedIn,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const Spacer(),
              // 다중 배지를 wrap 으로 — 작은 공간에서도 줄바꿈.
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: badges,
              ),
            ],
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 80),
            child: rows.isEmpty
                ? _Placeholder(text: t.attMainNoUpcoming)
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _ComingUpRow(
                      row: rows[i].row,
                      group: rows[i].group,
                      selected: _rowKey(rows[i].row) == _selectedKey,
                      onTap: () => _onRowTap(rows[i].row),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// 작은 상태 배지 — Coming Up 헤더에서 여러 개 나열에 사용.
  Widget _countBadge({
    required String label,
    required Color bg,
    required Color fg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  // ─── 중: Completed Today (clocked_out) ───────────────────────────

  Widget _buildCompletedSection() {
    final t = AppL10n.of(context);
    final dashboard = ref.watch(attendanceDashboardProvider);
    final rows = dashboard.staff
        .where((r) => r.status == 'clocked_out')
        .toList()
      ..sort((a, b) {
        final aOut = a.clockOut;
        final bOut = b.clockOut;
        if (aOut == null && bOut == null) return 0;
        if (aOut == null) return 1;
        if (bOut == null) return -1;
        return bOut.compareTo(aOut); // 최근 퇴근 순
      });

    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                t.attMainClockedOut,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  t.attMainDoneBadge(rows.length),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 80),
            child: rows.isEmpty
                ? _Placeholder(text: t.attMainNoCompletedShifts)
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _CompletedRow(
                      row: rows[i],
                      selected: _rowKey(rows[i]) == _selectedKey,
                      onTap: () => _onRowTap(rows[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ─── 우: Current Time (store tz 기준) ─────────────────────────────

  Widget _buildCurrentTime() {
    final t = AppL10n.of(context);
    final localeTag = Localizations.localeOf(context).toString();
    final device = ref.watch(attendanceDeviceProvider).device;
    // 브라우저 로컬 무관, store 타임존 기준 벽시계 시각 계산
    final offsetMin = device?.storeTimezoneOffsetMinutes ?? 0;
    final storeNow =
        _now.toUtc().add(Duration(minutes: offsetMin));
    // storeNow 는 UTC 객체지만 필드값은 store 벽시계와 동일 (naive 로 사용)
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            t.attMainCurrentTimeLabel,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white54,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            DateFormat('hh:mm', localeTag).format(storeNow),
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
          Text(
            DateFormat('a', localeTag).format(storeNow),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            DateFormat('EEE, MMM d, yyyy', localeTag).format(storeNow),
            style: const TextStyle(fontSize: 12, color: Colors.white54),
          ),
          if (device?.storeTimezone != null) ...[
            const SizedBox(height: 4),
            Text(
              device!.storeTimezone!,
              style: const TextStyle(fontSize: 10, color: Colors.white38),
            ),
          ],
        ],
      ),
    );
  }

  // ─── 우: Notice Board ─────────────────────────────────────────────

  Widget _buildNoticeBoard() {
    final t = AppL10n.of(context);
    final dashboard = ref.watch(attendanceDashboardProvider);
    final notices = dashboard.notices;
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                t.attMainNoticeBoard,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${notices.length}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: notices.isEmpty
                ? _Placeholder(text: t.attMainNoNotices)
                : ListView.separated(
                    itemCount: notices.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _NoticeRow(notice: notices[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Reusable: Panel Card ────────────────────────────────────────────

class _PanelCard extends StatelessWidget {
  final Widget child;
  const _PanelCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─── Reusable: Placeholder ───────────────────────────────────────────

class _Placeholder extends StatelessWidget {
  final String text;
  const _Placeholder({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
      ),
    );
  }
}

// ─── On-Shift Row Card ──────────────────────────────────────────────

class _OnShiftCard extends StatelessWidget {
  final TodayStaffRow row;
  final bool selected;
  final VoidCallback onTap;
  const _OnShiftCard({
    required this.row,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final schedule = _formatScheduleRange(row, t);
    final clockIn = row.clockInDisplay ?? '--:--';

    final isOnBreak = row.status == 'on_break';
    final isLate = row.status == 'late';

    // 선택 시 accent 색 보더 + shadow 로 강조.
    final Color borderColor;
    double borderWidth = 1.0;
    if (selected) {
      borderColor = AppColors.accent;
      borderWidth = 2.0;
    } else if (isOnBreak) {
      borderColor = AppColors.warning.withValues(alpha: 0.4);
    } else {
      borderColor = AppColors.border;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: isOnBreak ? AppColors.warningBg : AppColors.accentBg,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(
              isOnBreak ? Icons.pause_rounded : Icons.person_rounded,
              size: 32,
              color: isOnBreak ? AppColors.warning : AppColors.accent,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.userName.isEmpty ? t.commonUnknown : row.userName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isOnBreak) _buildBreakBadge(t, row.currentBreak),
                    if (isLate) _buildLateBadge(t),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  schedule,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  t.attMainClockedInAt(clockIn),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildBreakBadge(AppL10n t, TodayStaffBreak? br) {
    // dual-read: 신규(paid_10min/unpaid_meal) + 레거시(paid_short/unpaid_long) 모두 인식.
    final bt = br?.breakType;
    final label = (bt == 'unpaid_meal' || bt == 'unpaid_long')
        ? t.attMainBreakLong
        : (bt == 'paid_10min' || bt == 'paid_short')
            ? t.attMainBreakShort
            : t.attMainBreakOnBreak;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        t.attMainOnBreakWith(label),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.warning,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildLateBadge(AppL10n t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.dangerBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        t.attMainLateBadge,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.danger,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

String _formatScheduleRange(TodayStaffRow row, AppL10n t) {
  final s = row.scheduledStartDisplay;
  final e = row.scheduledEndDisplay;
  if (s == null && e == null) return t.attMainNoSchedule;
  return '${s ?? '--:--'} – ${e ?? '--:--'}';
}

// ─── Coming-Up Row ──────────────────────────────────────────────────

/// "Not Clocked In" 섹션 그룹핑 — 정렬/배지/스타일 분기 키.
/// 긴급도 순: upcoming (회색) → soon (노랑, 5분 이내) → late (주황) → noShow (빨강).
enum _ComingUpGroup {
  /// 예정 시각이 SOON threshold 이상 남음 (정상 대기).
  upcoming,

  /// 예정 시각이 SOON threshold 이내로 임박 (곧 시작).
  soon,

  /// 예정 시각이 이미 지났는데 clock-in 없음.
  late_,

  /// 서버가 no_show 로 마킹.
  noShow,
}

/// SOON 그룹 기준 — 예정 시각 N분 이내면 임박 처리.
/// 추후 store setting 으로 뽑을 여지.
const int _soonThresholdMinutes = 5;

/// SOON 그룹 전용 노랑 (amber) — 테마에 따로 없어서 로컬 상수.
const Color _soonColor = Color(0xFFD97706);     // amber-600
const Color _soonBg = Color(0xFFFEF3C7);         // amber-100

/// 정렬된 Coming-Up 행 + 소속 그룹 pair.
class _ComingUpEntry {
  final TodayStaffRow row;
  final _ComingUpGroup group;
  const _ComingUpEntry(this.row, this.group);
}

class _ComingUpRow extends StatelessWidget {
  final TodayStaffRow row;
  final _ComingUpGroup group;
  final bool selected;
  final VoidCallback onTap;
  const _ComingUpRow({
    required this.row,
    required this.group,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final start = row.scheduledStartDisplay ?? '--:--';
    final end = row.scheduledEndDisplay;
    final range = end != null && end.isNotEmpty ? '$start – $end' : start;

    // 그룹별 스타일 결정.
    IconData icon;
    Color iconColor;
    Color timeColor;
    Widget? trailingBadge;
    switch (group) {
      case _ComingUpGroup.upcoming:
        icon = Icons.schedule_rounded;
        iconColor = AppColors.textMuted;
        timeColor = AppColors.accent;
        break;
      case _ComingUpGroup.soon:
        icon = Icons.notifications_active_rounded;
        iconColor = _soonColor;
        timeColor = _soonColor;
        trailingBadge = _InlineStatusBadge(
          label: t.attMainBadgeSoonShort,
          bg: _soonBg,
          fg: _soonColor,
        );
        break;
      case _ComingUpGroup.late_:
        icon = Icons.hourglass_bottom_rounded;
        iconColor = AppColors.warning;
        timeColor = AppColors.warning;
        trailingBadge = _InlineStatusBadge(
          label: t.attMainBadgeLateShort,
          bg: AppColors.warningBg,
          fg: AppColors.warning,
        );
        break;
      case _ComingUpGroup.noShow:
        icon = Icons.cancel_rounded;
        iconColor = AppColors.danger;
        timeColor = AppColors.danger;
        trailingBadge = _InlineStatusBadge(
          label: t.attMainBadgeNoShowShort,
          bg: AppColors.dangerBg,
          fg: AppColors.danger,
        );
        break;
    }

    // 선택 시 accent 보더 + shadow 강조. 선택 아닌 경우 그룹별 얇은 보더.
    final Border? border;
    if (selected) {
      border = Border.all(color: AppColors.accent, width: 2.0);
    } else if (group == _ComingUpGroup.upcoming) {
      border = null;
    } else {
      // 그룹별 보더 색 (30% alpha)
      final baseColor = switch (group) {
        _ComingUpGroup.soon => _soonColor,
        _ComingUpGroup.late_ => AppColors.warning,
        _ComingUpGroup.noShow => AppColors.danger,
        _ComingUpGroup.upcoming => AppColors.textMuted,
      };
      border = Border.all(color: baseColor.withValues(alpha: 0.3));
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 22),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(14),
          border: border,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 28, color: iconColor),
            const SizedBox(width: 18),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      row.userName.isEmpty ? t.commonUnknown : row.userName,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (trailingBadge != null) ...[
                    const SizedBox(width: 12),
                    trailingBadge,
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              range,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: timeColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Coming-Up 행 내 인라인 배지 (LATE · WAITING / NO SHOW).
class _InlineStatusBadge extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const _InlineStatusBadge({
    required this.label,
    required this.bg,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: fg,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ─── Completed Row (퇴근한 직원) ────────────────────────────────────

class _CompletedRow extends StatelessWidget {
  final TodayStaffRow row;
  final bool selected;
  final VoidCallback onTap;
  const _CompletedRow({
    required this.row,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final inTime = row.clockInDisplay ?? '--:--';
    final outTime = row.clockOutDisplay ?? '--:--';
    // 완료된 shift는 더 이상 액션 대상 아니라 컴팩트하게 유지.
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(10),
          border: selected
              ? Border.all(color: AppColors.accent, width: 2.0)
              : null,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded,
              size: 16, color: Color(0xFF2FB886)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              row.userName.isEmpty ? t.commonUnknown : row.userName,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '$inTime – $outTime',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
      ),
    );
  }
}

// ─── Notice Row ─────────────────────────────────────────────────────

class _NoticeRow extends StatelessWidget {
  final AttendanceNotice notice;
  const _NoticeRow({required this.notice});

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final localeTag = Localizations.localeOf(context).toString();
    final timeAgo = _timeAgo(t, localeTag, notice.createdAt.toLocal());
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            notice.title.isEmpty ? t.commonUntitled : notice.title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            timeAgo,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(AppL10n t, String localeTag, DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return t.attMainTimeAgoJustNow;
    if (diff.inMinutes < 60) return t.attMainTimeAgoMinutes(diff.inMinutes);
    if (diff.inHours < 24) return t.attMainTimeAgoHours(diff.inHours);
    if (diff.inDays < 7) return t.attMainTimeAgoDays(diff.inDays);
    return DateFormat('MMM d', localeTag).format(dt);
  }
}

// ─── 10min Break 전용 합성 아이콘 ──────────────────────────────────
//
// Material Icons.timer_10 은 실제 렌더 시 "10s" 로 보여 10초 휴식으로 오해됨.
// 시계 외곽선 안에 "10" 텍스트를 직접 합성한다.
Widget _build10minClockIcon(Color color, double size) {
  return SizedBox(
    width: size,
    height: size,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Icon(Icons.access_time_rounded, color: color, size: size),
        Padding(
          padding: EdgeInsets.only(top: size * 0.08),
          child: Text(
            '10',
            style: TextStyle(
              fontSize: size * 0.32,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1.0,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ],
    ),
  );
}

// ─── Shift Action Button ────────────────────────────────────────────

/// 사이드바의 단일 trigger 버튼 — 누르면 _openActionsSheet 모달 호출.
/// 가로로 큼직, 우측에 chevron 으로 "여기서 펼쳐진다"는 affordance 표시.
class _ShiftActionTrigger extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  const _ShiftActionTrigger({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = enabled ? color : AppColors.textMuted;
    final bgColor = enabled ? AppColors.white : AppColors.bg;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.6,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: enabled ? color : AppColors.border, width: 2),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.18),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : const [],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: enabled ? color.withValues(alpha: 0.12) : AppColors.border,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 24, color: fg),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: fg,
                        letterSpacing: 0.6,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 24,
                color: enabled ? color : AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShiftActionButton extends StatelessWidget {
  /// 색/크기를 받아 아이콘 위젯을 만드는 빌더. 단순 Icon 대신 Stack 등 합성 아이콘
  /// (예: 시계+"10")도 사용할 수 있게 빌더 인터페이스로 받는다.
  final Widget Function(Color color, double size) iconBuilder;
  final String label;
  final String subtitle;
  final Color color;
  final bool isFilled;
  final bool enabled;
  final VoidCallback onTap;

  const _ShiftActionButton({
    required this.iconBuilder,
    required this.label,
    required this.subtitle,
    required this.color,
    this.isFilled = false,
    this.enabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 비활성 시 라벨/아이콘/보더/배경 모두 muted.
    final effectiveColor = enabled ? color : AppColors.textMuted;
    final Color bgColor;
    final Color contentColor;
    final Color borderColor;
    if (!enabled) {
      bgColor = AppColors.bg;
      contentColor = AppColors.textMuted;
      borderColor = AppColors.border;
    } else if (isFilled) {
      bgColor = effectiveColor;
      contentColor = Colors.white;
      borderColor = effectiveColor;
    } else {
      bgColor = AppColors.white;
      contentColor = effectiveColor;
      borderColor = AppColors.border;
    }
    final subtitleColor = !enabled
        ? AppColors.textMuted.withValues(alpha: 0.7)
        : (isFilled ? Colors.white70 : AppColors.textMuted);

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: Container(
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(vertical: 26, horizontal: 18),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : const [],
          ),
          child: Column(
            children: [
              iconBuilder(contentColor, 38),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: contentColor,
                  letterSpacing: 0.5,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: subtitleColor),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
