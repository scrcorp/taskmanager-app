/// 매장 태블릿 Attendance 키오스크 대시보드 (3-column 레이아웃)
///
/// 좌측: Shift Actions (선택된 직원의 상태별 가능 액션만 활성)
///   - Clock In
///   - Clock Out
///   - Short Break (Paid, 10 min)
///   - Long Break (Unpaid, 30 min)
///   - End Break
/// 중앙: Currently On Shift + Schedule (today-staff API, 각 row 탭 선택)
/// 우측: Current Time (실시간) + Notice Board (notices API)
///
/// 기기 인증(device token) 기반 — JWT 세션 사용하지 않음.
/// 태블릿 전용 (768px 미만 분기 없음).
///
/// UX 흐름:
///   1. 사용자가 리스트에서 본인 row 탭 → _selectedUserId 설정
///   2. 사이드바에 해당 유저의 상태에 맞는 액션만 활성화
///   3. 액션 버튼 탭 → PIN 화면 (user_id + pin 서버 전송)
///   4. 성공 후 대시보드 복귀 시 선택 해제
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../providers/attendance_dashboard_provider.dart';
import '../../providers/attendance_device_provider.dart';
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

  /// break-start 에 첨부할 break_type ('paid_short' | 'unpaid_long')
  /// 그 외 action 은 null
  String? get breakType {
    switch (this) {
      case AttendanceAction.breakShortPaid:
        return 'paid_short';
      case AttendanceAction.breakLongUnpaid:
        return 'unpaid_long';
      case AttendanceAction.clockIn:
      case AttendanceAction.clockOut:
      case AttendanceAction.breakEnd:
        return null;
    }
  }

  /// UI 표기용 라벨
  String get label {
    switch (this) {
      case AttendanceAction.clockIn:
        return 'Clock In';
      case AttendanceAction.clockOut:
        return 'Clock Out';
      case AttendanceAction.breakShortPaid:
        return 'Short Break';
      case AttendanceAction.breakLongUnpaid:
        return 'Long Break';
      case AttendanceAction.breakEnd:
        return 'End Break';
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

  /// 현재 리스트에서 선택된 직원. null 이면 사이드바 액션 전체 비활성.
  String? _selectedUserId;

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
    super.dispose();
  }

  /// Row 탭 핸들러 — 같은 유저 재탭 시 선택 해제, 다른 유저 탭 시 전환.
  void _onRowTap(String userId) {
    setState(() {
      if (_selectedUserId == userId) {
        _selectedUserId = null;
      } else {
        _selectedUserId = userId;
      }
    });
  }

  /// 선택된 유저 찾기 (없으면 null).
  /// build 안에서 호출될 때 dashboard 상태 변화에 반응하도록 watch 사용.
  /// (핸들러에서 호출될 때도 안전 — 이미 build 사이클 외부라면 dependency 구독만 발생)
  TodayStaffRow? get _selectedRow {
    if (_selectedUserId == null) return null;
    final dashboard = ref.watch(attendanceDashboardProvider);
    for (final r in dashboard.staff) {
      if (r.userId == _selectedUserId) return r;
    }
    return null;
  }

  /// 유저 상태 기준으로 특정 액션이 활성화 가능한지 판단.
  /// 상태 매핑:
  ///   - not_yet / (late_waiting) → Clock In
  ///   - no_show                  → Clock In
  ///   - working / late           → Clock Out, Short Break, Long Break
  ///   - on_break                 → End Break, Clock Out
  ///   - clocked_out              → (모두 비활성)
  bool _isActionAllowed(AttendanceAction action, String status) {
    switch (status) {
      case 'not_yet':
      case 'no_show':
        return action == AttendanceAction.clockIn;
      case 'working':
      case 'late':
        return action == AttendanceAction.clockOut ||
            action == AttendanceAction.breakShortPaid ||
            action == AttendanceAction.breakLongUnpaid;
      case 'on_break':
        return action == AttendanceAction.breakEnd ||
            action == AttendanceAction.clockOut;
      case 'clocked_out':
      default:
        return false;
    }
  }

  Future<void> _openPin(AttendanceAction action) async {
    final row = _selectedRow;
    if (row == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AttendancePinScreen(
          action: action,
          userId: row.userId,
          userName: row.userName,
        ),
      ),
    );
    // 성공/실패 모두 대시보드 복귀 시 선택 해제
    if (mounted) {
      setState(() => _selectedUserId = null);
    }
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
    final device = ref.watch(attendanceDeviceProvider).device;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(
              storeName: device?.storeName ?? 'Store',
              deviceName: device?.deviceName ?? 'Device',
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
                        storeName: device?.storeName ?? 'Store',
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
    final dashboard = ref.watch(attendanceDashboardProvider);
    // work_date 를 "Wed, Apr 22 2026" 형태로 포매팅 (store tz 기준 서버가 계산한 날짜)
    String? workDateDisplay;
    if (workDate != null && workDate.isNotEmpty) {
      try {
        final d = DateTime.parse(workDate);
        workDateDisplay = DateFormat('EEE, MMM d, y').format(d);
      } catch (_) {
        workDateDisplay = workDate;
      }
    }
    return Row(
      children: [
        Expanded(
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
                const Text(
                  'WORK DATE',
                  style: TextStyle(
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
        IconButton(
          tooltip: 'Refresh',
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
          tooltip: 'Settings',
          onPressed: _openSettings,
          icon: const Icon(Icons.settings_outlined,
              color: AppColors.textSecondary),
        ),
      ],
    );
  }

  // ─── 좌: Shift Actions ────────────────────────────────────────────

  Widget _buildShiftActions({required String storeName}) {
    final selected = _selectedRow;
    final hasSelection = selected != null;
    final status = selected?.status ?? '';

    // 특정 액션의 활성 여부 결정. 선택 없으면 모두 비활성.
    bool allowed(AttendanceAction a) =>
        hasSelection && _isActionAllowed(a, status);

    // 안내 텍스트 — 선택 유무에 따라 전환
    final String helpText;
    if (!hasSelection) {
      helpText = 'Tap your name from the list first';
    } else if (status == 'clocked_out') {
      helpText = 'Your shift is already completed';
    } else {
      helpText = 'Choose an action below';
    }

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
                const Text(
                  'SELECTED',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  selected.userName.isEmpty ? 'Unknown' : selected.userName,
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
                  onTap: () => setState(() => _selectedUserId = null),
                  child: const Row(
                    children: [
                      Icon(Icons.close, size: 12, color: AppColors.textMuted),
                      SizedBox(width: 4),
                      Text(
                        'Clear selection',
                        style: TextStyle(
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
        const SizedBox(height: 16),
        const Text(
          'Shift Actions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          helpText,
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        const SizedBox(height: 20),
        _ShiftActionButton(
          icon: Icons.login_rounded,
          label: 'CLOCK IN',
          subtitle: 'Start Workday',
          color: AppColors.accent,
          enabled: allowed(AttendanceAction.clockIn),
          onTap: () => _openPin(AttendanceAction.clockIn),
        ),
        const SizedBox(height: 12),
        _ShiftActionButton(
          icon: Icons.logout_rounded,
          label: 'CLOCK OUT',
          subtitle: 'End Schedule',
          color: AppColors.textSecondary,
          enabled: allowed(AttendanceAction.clockOut),
          onTap: () => _openPin(AttendanceAction.clockOut),
        ),
        const SizedBox(height: 12),
        _ShiftActionButton(
          icon: Icons.coffee_rounded,
          label: 'SHORT BREAK',
          subtitle: 'Paid · 10 min',
          color: AppColors.warning,
          enabled: allowed(AttendanceAction.breakShortPaid),
          onTap: () => _openPin(AttendanceAction.breakShortPaid),
        ),
        const SizedBox(height: 12),
        _ShiftActionButton(
          icon: Icons.free_breakfast_rounded,
          label: 'LONG BREAK',
          subtitle: 'Unpaid · 30 min',
          color: AppColors.warning,
          isFilled: true,
          enabled: allowed(AttendanceAction.breakLongUnpaid),
          onTap: () => _openPin(AttendanceAction.breakLongUnpaid),
        ),
        const SizedBox(height: 12),
        _ShiftActionButton(
          icon: Icons.play_circle_outline_rounded,
          label: 'END BREAK',
          subtitle: 'Resume Work',
          color: AppColors.success,
          enabled: allowed(AttendanceAction.breakEnd),
          onTap: () => _openPin(AttendanceAction.breakEnd),
        ),
      ],
    );
  }

  // ─── 중: Currently On Shift ───────────────────────────────────────

  Widget _buildOnShiftSection() {
    final dashboard = ref.watch(attendanceDashboardProvider);
    // working, on_break, late 상태인 유저 표시
    final rows = dashboard.staff
        .where((r) =>
            r.status == 'working' ||
            r.status == 'on_break' ||
            r.status == 'late')
        .toList();

    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Clocked In',
                style: TextStyle(
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
                  '${rows.length} ACTIVE',
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
                ? const _Placeholder(text: 'No one is currently on shift')
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _OnShiftCard(
                      row: rows[i],
                      selected: rows[i].userId == _selectedUserId,
                      onTap: () => _onRowTap(rows[i].userId),
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
  // 3 그룹 → (a) upcoming_future (not_yet + scheduled_start 미래)
  //        → (b) late_waiting   (not_yet + scheduled_start 과거, 아직 안 옴)
  //        → (c) no_show
  // 각 그룹 내 정렬: scheduled_start 오름차순.
  // storeNow 는 _now 를 store tz offset 만큼 보정한 "벽시계" 시각.

  Widget _buildComingUpSection() {
    final dashboard = ref.watch(attendanceDashboardProvider);

    // 긴급도 오름차순: upcoming → soon (5분 이내) → late (지남) → noShow.
    // scheduled_start 는 store tz offset 포함 ISO → UTC epoch 비교.
    _ComingUpGroup classify(TodayStaffRow r) {
      if (r.status == 'no_show') return _ComingUpGroup.noShow;
      final start = r.scheduledStart;
      if (start == null) return _ComingUpGroup.upcoming;
      final startUtc = start.toUtc();
      final nowUtc = _now.toUtc();
      if (startUtc.isBefore(nowUtc)) return _ComingUpGroup.late_;
      final diffMin = startUtc.difference(nowUtc).inMinutes;
      if (diffMin <= _soonThresholdMinutes) return _ComingUpGroup.soon;
      return _ComingUpGroup.upcoming;
    }

    // not_yet + no_show 모두 포함
    final candidates = dashboard.staff
        .where((r) => r.status == 'not_yet' || r.status == 'no_show')
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
        label: '${upcoming.length} UPCOMING',
        bg: AppColors.bg,
        fg: AppColors.textMuted,
      ));
    }
    if (soon.isNotEmpty) {
      badges.add(_countBadge(
        label: '${soon.length} SOON',
        bg: _soonBg,
        fg: _soonColor,
      ));
    }
    if (late_.isNotEmpty) {
      badges.add(_countBadge(
        label: '${late_.length} LATE',
        bg: AppColors.warningBg,
        fg: AppColors.warning,
      ));
    }
    if (noShow.isNotEmpty) {
      badges.add(_countBadge(
        label: '${noShow.length} NO SHOW',
        bg: AppColors.dangerBg,
        fg: AppColors.danger,
      ));
    }
    // 하나도 없으면 기본 "0 UPCOMING" 회색 배지 유지 (empty state 와 조화)
    if (badges.isEmpty) {
      badges.add(_countBadge(
        label: '0 UPCOMING',
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
              const Text(
                'Not Clocked In',
                style: TextStyle(
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
                ? const _Placeholder(text: 'No upcoming shifts')
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _ComingUpRow(
                      row: rows[i].row,
                      group: rows[i].group,
                      selected: rows[i].row.userId == _selectedUserId,
                      onTap: () => _onRowTap(rows[i].row.userId),
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
              const Text(
                'Clocked Out',
                style: TextStyle(
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
                  '${rows.length} DONE',
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
                ? const _Placeholder(text: 'No completed shifts yet')
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _CompletedRow(
                      row: rows[i],
                      selected: rows[i].userId == _selectedUserId,
                      onTap: () => _onRowTap(rows[i].userId),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ─── 우: Current Time (store tz 기준) ─────────────────────────────

  Widget _buildCurrentTime() {
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
          const Text(
            'CURRENT TIME',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white54,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            DateFormat('hh:mm').format(storeNow),
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
          Text(
            DateFormat('a').format(storeNow),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            DateFormat('EEE, MMM d, yyyy').format(storeNow),
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
    final dashboard = ref.watch(attendanceDashboardProvider);
    final notices = dashboard.notices;
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Notice Board',
                style: TextStyle(
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
                ? const _Placeholder(text: 'No notices')
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
    final schedule = _formatScheduleRange(row);
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(12),
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isOnBreak ? AppColors.warningBg : AppColors.accentBg,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(
              isOnBreak ? Icons.pause_rounded : Icons.person_rounded,
              size: 20,
              color: isOnBreak ? AppColors.warning : AppColors.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.userName.isEmpty ? 'Unknown' : row.userName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isOnBreak) _buildBreakBadge(row.currentBreak),
                    if (isLate) _buildLateBadge(),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  schedule,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Clocked in at $clockIn',
                  style: const TextStyle(
                    fontSize: 11,
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

  Widget _buildBreakBadge(TodayStaffBreak? br) {
    final label = br?.breakType == 'unpaid_long'
        ? 'Long Unpaid'
        : br?.breakType == 'paid_short'
            ? 'Short Paid'
            : 'On Break';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'On Break · $label',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.warning,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildLateBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.dangerBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'Late',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.danger,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

String _formatScheduleRange(TodayStaffRow row) {
  final s = row.scheduledStartDisplay;
  final e = row.scheduledEndDisplay;
  if (s == null && e == null) return 'No schedule';
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
          label: 'SOON',
          bg: _soonBg,
          fg: _soonColor,
        );
        break;
      case _ComingUpGroup.late_:
        icon = Icons.hourglass_bottom_rounded;
        iconColor = AppColors.warning;
        timeColor = AppColors.warning;
        trailingBadge = _InlineStatusBadge(
          label: 'LATE',
          bg: AppColors.warningBg,
          fg: AppColors.warning,
        );
        break;
      case _ComingUpGroup.noShow:
        icon = Icons.cancel_rounded;
        iconColor = AppColors.danger;
        timeColor = AppColors.danger;
        trailingBadge = _InlineStatusBadge(
          label: 'NO SHOW',
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
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(10),
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
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 10),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      row.userName.isEmpty ? 'Unknown' : row.userName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (trailingBadge != null) ...[
                    const SizedBox(width: 8),
                    trailingBadge,
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              range,
              style: TextStyle(
                fontSize: 13,
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
    final inTime = row.clockInDisplay ?? '--:--';
    final outTime = row.clockOutDisplay ?? '--:--';
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
              row.userName.isEmpty ? 'Unknown' : row.userName,
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
    final timeAgo = _timeAgo(notice.createdAt.toLocal());
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
            notice.title.isEmpty ? 'Untitled' : notice.title,
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

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  }
}

// ─── Shift Action Button ────────────────────────────────────────────

class _ShiftActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final bool isFilled;
  final bool enabled;
  final VoidCallback onTap;

  const _ShiftActionButton({
    required this.icon,
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
              const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
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
              Icon(icon, size: 28, color: contentColor),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: contentColor,
                  letterSpacing: 0.5,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 10, color: subtitleColor),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
