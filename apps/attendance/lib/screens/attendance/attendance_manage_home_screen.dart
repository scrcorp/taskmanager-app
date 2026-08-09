/// 관리자 모드 홈 — 오늘 스케줄 그리드.
///
/// 큰 카드 그리드 (태블릿 2-column). 카드 탭 시 큰 액션 시트가 모달로 열리고
/// Edit / Change Status / Delete + 빠른 clock 액션을 큰 버튼으로 제공.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:htm_core/htm_core.dart';

import '../../models/schedule_staff_view.dart';
import '../../providers/attendance_device_provider.dart';
import '../../providers/attendance_manage_provider.dart';
import '../../services/attendance_device_service.dart';
import '../../utils/manage_home_ctas.dart';
import '../../utils/manage_status_utils.dart';
import '../../utils/staff_status_utils.dart' show StaffSection;
import '../../widgets/battery_indicator.dart';
import '../../widgets/manage_action_picker.dart';
import '../../widgets/manage_schedule_edit_modal.dart';
import '../../widgets/schedule_staff_card.dart';
import '../../widgets/schedule_staff_detail_panel.dart';
import '../../widgets/store_clock.dart';
import 'attendance_manage_action_modal.dart';
import 'attendance_manage_staff_pins_screen.dart';
import 'attendance_manage_store_settings_screen.dart';

class AttendanceManageHomeScreen extends ConsumerStatefulWidget {
  const AttendanceManageHomeScreen({super.key});

  @override
  ConsumerState<AttendanceManageHomeScreen> createState() =>
      _AttendanceManageHomeScreenState();
}

class _AttendanceManageHomeScreenState
    extends ConsumerState<AttendanceManageHomeScreen> {
  static const _sessionSeconds = 5 * 60; // 5분 무반응 자동 종료

  bool _loading = true;
  List<AdminScheduleRow> _schedules = const [];
  String? _error;
  String? _selectedId;

  /// 스케줄 그리드/디테일 패널이 쓰는 now — 분 단위 표시라 분 경계에서만 rebuild.
  DateTime _now = DateTime.now();
  Timer? _clock;

  /// 헤더 매장 시계 + 세션 카운트다운은 매초 바뀌어야 하지만, 이 값들 때문에
  /// 화면 전체(스케줄 그리드 포함)를 매초 rebuild 할 필요는 없다.
  /// setState 대신 ValueNotifier 로 전달해 헤더 subtree 만 rebuild 시킨다.
  /// (배터리: 매초 setState 로 전체 화면 rebuild 하던 문제 fix, Task 1)
  final ValueNotifier<DateTime> _liveNow = ValueNotifier(DateTime.now());
  final ValueNotifier<int> _sessionLeftNotifier = ValueNotifier(
    _sessionSeconds,
  );
  int _sessionLeft = _sessionSeconds;
  bool _sessionExpired = false;

  @override
  void initState() {
    super.initState();
    // 1초 틱 — 헤더 매장 시계 + 세션 카운트다운 (5분 무반응 시 자동 종료)
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_sessionExpired) return;
      final prev = _now;
      final next = DateTime.now();
      _liveNow.value = next;
      if (prev.minute != next.minute || prev.hour != next.hour) {
        setState(() => _now = next);
      }
      final nextLeft = _sessionLeft - 1;
      if (nextLeft <= 0) {
        _sessionExpired = true;
        _sessionLeft = 0;
        _sessionLeftNotifier.value = 0;
        _onSessionExpired();
        return;
      }
      _sessionLeft = nextLeft;
      _sessionLeftNotifier.value = nextLeft;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _clock?.cancel();
    _liveNow.dispose();
    _sessionLeftNotifier.dispose();
    super.dispose();
  }

  void _resetSession() {
    if (_sessionExpired) return;
    if (_sessionLeft != _sessionSeconds) {
      _sessionLeft = _sessionSeconds;
      _sessionLeftNotifier.value = _sessionSeconds;
    }
  }

  Future<void> _onSessionExpired() async {
    _clock?.cancel();
    if (!mounted) return;
    await AppModal.show(
      context,
      title: 'Manage Mode ended',
      message:
          'No activity for 5 minutes, so Manage Mode closed automatically to keep the device secure.',
      type: ModalType.info,
    );
    await _exitAdminMode(silent: true);
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = ref.read(attendanceDeviceServiceProvider);
      final rows = await service.manageListSchedules();
      if (!mounted) return;
      setState(() {
        _schedules = rows.map(AdminScheduleRow.fromJson).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = extractApiError(e, 'Failed to load schedules.');
        _loading = false;
      });
      if (_error?.toLowerCase().contains('session') == true ||
          _error?.toLowerCase().contains('expired') == true) {
        await _exitAdminMode(silent: true);
      }
    }
  }

  /// exit 버튼/뒤로가기 시 확인 후 종료 (세션 자동 만료는 확인 없이 바로).
  Future<void> _confirmExit() async {
    if (_sessionExpired) return;
    final ok = await AppModal.show(
      context,
      title: 'Exit Manage Mode?',
      message: 'End the manage session and return to the PIN screen.',
      type: ModalType.confirm,
      confirmText: 'Exit',
    );
    if (ok == true) await _exitAdminMode(silent: true);
  }

  Future<void> _exitAdminMode({bool silent = false}) async {
    await ref.read(attendanceManageSessionProvider.notifier).close();
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    if (!silent) {
      AppModal.show(
        context,
        title: 'Exited Manage Mode',
        message: 'Admin session ended.',
        type: ModalType.info,
      );
    }
  }

  Future<void> _openCreate() async {
    final saved = await ManageScheduleEditModal.show(context);
    if (!mounted) return;
    if (saved) await _refresh();
  }

  Future<void> _openStaffPins() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            AttendanceManageStaffPinsScreen(onActivity: _resetSession),
      ),
    );
    if (!mounted) return;
    _resetSession();
  }

  Future<void> _openStoreSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            AttendanceManageStoreSettingsScreen(onActivity: _resetSession),
      ),
    );
    if (!mounted) return;
    _resetSession();
  }

  /// 현재 manage 세션 권한으로 노출할 CTA 목록 (헤더 / 빈 상태 공통 규칙).
  List<ManageHomeCta> _ctas({required bool header}) {
    final session = ref.watch(attendanceManageSessionProvider);
    return header
        ? manageHomeHeaderCtas(
            canReadPins: session.canReadPins,
            canManageStoreSettings: session.canManageStoreSettings,
          )
        : manageHomeEmptyStateCtas(
            canReadPins: session.canReadPins,
            canManageStoreSettings: session.canManageStoreSettings,
          );
  }

  Widget _ctaButton(ManageHomeCta cta) {
    switch (cta) {
      case ManageHomeCta.addSchedule:
        return _BigPrimaryButton(
          icon: Icons.add_rounded,
          label: 'Add Schedule',
          onTap: _openCreate,
        );
      case ManageHomeCta.staffPins:
        return _BigPrimaryButton(
          icon: Icons.pin_rounded,
          label: 'Staff PINs',
          onTap: _openStaffPins,
        );
      case ManageHomeCta.storeSettings:
        return _BigPrimaryButton(
          icon: Icons.tune_rounded,
          label: 'Store Settings',
          onTap: _openStoreSettings,
        );
    }
  }

  Future<void> _openCardActions(AdminScheduleRow row) async {
    // Action Picker(중앙 모달) → 액션 선택 → Action Modal(시간/사유) → 적용.
    final action = await ManageActionPicker.show(context, row: row, now: _now);
    if (action == null || !mounted) return;
    final applied = await AttendanceManageActionModal.show(
      context,
      action: action,
      row: row,
    );
    if (!mounted) return;
    if (applied) await _refresh();
  }

  Future<void> _openEditRow(AdminScheduleRow row) async {
    final saved = await ManageScheduleEditModal.show(context, existing: row);
    if (!mounted) return;
    if (saved) await _refresh();
  }

  Future<void> _confirmDelete(AdminScheduleRow row) async {
    final ok = await AppModal.show(
      context,
      title: 'Delete Schedule?',
      message:
          '${row.userName} · ${row.startHHmm ?? '?'} – ${row.endHHmm ?? '?'}',
      type: ModalType.confirm,
      confirmText: 'Delete',
    );
    if (ok != true) return;
    try {
      final service = ref.read(attendanceDeviceServiceProvider);
      await service.manageDeleteSchedule(row.scheduleId);
      if (!mounted) return;
      setState(() => _selectedId = null);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      AppModal.show(
        context,
        title: 'Delete Failed',
        message: extractApiError(e, 'Could not delete schedule.'),
        type: ModalType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(attendanceManageSessionProvider);
    final device = ref.watch(attendanceDeviceProvider).device;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _confirmExit();
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        // 화면 어디든 터치하면 세션 타이머 리셋 (실수로 열어둔 키오스크 보호)
        body: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _resetSession(),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  _buildHeader(
                    managerName: session.managerName ?? 'Manager',
                    storeName: device?.storeName ?? 'Store',
                    deviceName: device?.deviceName ?? '',
                    offsetMinutes: device?.storeTimezoneOffsetMinutes,
                    tzLabel: StoreClock.labelFromIana(device?.storeTimezone),
                  ),
                  const SizedBox(height: 16),
                  Expanded(child: _buildBody()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader({
    required String managerName,
    required String storeName,
    required String deviceName,
    required int? offsetMinutes,
    required String? tzLabel,
  }) {
    return Row(
      children: [
        // 좌: MANAGE MODE 배지 + store/device/manager
        SizedBox(
          width: 320,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warningBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'MANAGE MODE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.warning,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      storeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                    Text(
                      [
                        if (deviceName.isNotEmpty) deviceName,
                        managerName,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
        ),
        // 중앙: 매장 시계 (초 단위 — 이 subtree 만 매초 rebuild)
        Expanded(
          child: Center(
            child: ValueListenableBuilder<DateTime>(
              valueListenable: _liveNow,
              builder: (_, v, __) => StoreClock(
                now: v,
                offsetMinutes: offsetMinutes,
                tzLabel: tzLabel,
              ),
            ),
          ),
        ),
        // 우: 배터리 + 세션 타이머 + refresh + exit
        SizedBox(
          width: 320,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const BatteryIndicator(iconSize: 18, fontSize: 13),
              const SizedBox(width: 4),
              // 세션 카운트다운 (초 단위 — 이 subtree 만 매초 rebuild)
              ValueListenableBuilder<int>(
                valueListenable: _sessionLeftNotifier,
                builder: (_, sessionLeft, __) {
                  final sessionLow = sessionLeft <= 60;
                  final mm = (sessionLeft ~/ 60).toString();
                  final ss = (sessionLeft % 60).toString().padLeft(2, '0');
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: sessionLow ? AppColors.dangerBg : AppColors.bg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 16,
                          color: sessionLow
                              ? AppColors.danger
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$mm:$ss',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: sessionLow
                                ? AppColors.danger
                                : AppColors.textSecondary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              _HeaderIconButton(
                icon: Icons.refresh_rounded,
                tooltip: 'Refresh',
                onTap: _refresh,
              ),
              const SizedBox(width: 8),
              _HeaderIconButton(
                icon: Icons.logout_rounded,
                tooltip: 'Exit',
                color: AppColors.danger,
                onTap: _confirmExit,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
            const SizedBox(height: 12),
            FilledButton(onPressed: _refresh, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_schedules.isEmpty) {
      return _emptyState();
    }

    final selected = _selectedId == null
        ? null
        : _schedules.where((r) => r.scheduleId == _selectedId).firstOrNull;
    final clockedIn = _schedules
        .where((r) => sectionForManageState(r.state) == StaffSection.clockedIn)
        .toList();
    final notClockedIn = _schedules
        .where(
          (r) => sectionForManageState(r.state) == StaffSection.notClockedIn,
        )
        .toList();
    final completed = _schedules
        .where((r) => sectionForManageState(r.state) == StaffSection.completed)
        .toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 좌측: 헤더 줄 + 3 섹션 (각 내부 스크롤)
        Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  const Text(
                    "Today's Schedules",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                  const Spacer(),
                  // 노출 여부는 manage_home_ctas 가 단독으로 결정한다 — 빈 상태 행과
                  // 같은 규칙을 써야 한쪽에만 버튼이 빠지는 사고가 안 난다.
                  // (PIN=can_read_pins GM+, 매장설정=can_manage_store_settings stores:update)
                  for (final cta in _ctas(header: true)) ...[
                    _ctaButton(cta),
                    if (cta != ManageHomeCta.addSchedule)
                      const SizedBox(width: 8),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: _section(
                        'Working',
                        AppColors.success,
                        clockedIn,
                        'Nobody is working.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _section(
                        'Upcoming',
                        AppColors.warning,
                        notClockedIn,
                        'Everyone has clocked in.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _section(
                        'Done',
                        AppColors.textSecondary,
                        completed,
                        'Nobody has clocked out yet.',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // 우측: 디테일/액션 패널
        SizedBox(
          width: 360,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ScheduleStaffDetailPanel(
              view: selected?.toView(),
              now: _now,
              onActions: selected == null
                  ? null
                  : () => _openCardActions(selected),
              onEdit: selected == null ? null : () => _openEditRow(selected),
              onDelete: selected == null
                  ? null
                  : () => _confirmDelete(selected),
            ),
          ),
        ),
      ],
    );
  }

  Widget _section(
    String title,
    Color accent,
    List<AdminScheduleRow> rows,
    String empty,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${rows.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: rows.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      empty,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    physics: const AlwaysScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 300,
                          mainAxisExtent: 88,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                    itemCount: rows.length,
                    itemBuilder: (_, i) => ScheduleStaffCard(
                      view: rows[i].toView(),
                      selected: _selectedId == rows[i].scheduleId,
                      now: _now,
                      onTap: () =>
                          setState(() => _selectedId = rows[i].scheduleId),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.accentBg,
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(
                Icons.event_available_rounded,
                size: 48,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No schedules for today',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add a schedule to assign staff and start tracking attendance.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            // 빈 상태에도 헤더와 같은 CTA 를 둔다. "오늘 스케줄이 없는 신입이 첫 출근"
            // 이 바로 PIN 을 물어보는 대표 상황이고, 매장 설정 역시 빈 상태에서는
            // 헤더 행이 렌더되지 않아 여기 없으면 아예 닿지 못한다.
            // 버튼이 3개까지 늘어나므로 Row 가 아니라 Wrap (가로 오버플로 방지).
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final cta in _ctas(header: false)) _ctaButton(cta),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Big primary button (header + empty state CTA) ──────────────

class _BigPrimaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _BigPrimaryButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.accent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color? color;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            width: 52,
            height: 52,
            child: Icon(icon, color: color ?? AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

/// 어디서나 쓸 수 있는 axios/dio 에러 본문 추출.
String extractApiError(Object e, String fallback) {
  try {
    final resp = (e as dynamic).response;
    final data = resp?.data;
    if (data is Map && data['detail'] is String)
      return data['detail'] as String;
  } catch (_) {}
  return fallback;
}
