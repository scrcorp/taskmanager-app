/// 매장 태블릿 Attendance 키오스크 (PIN-first) — Phase 5 Stage H-2d.
///
/// 흐름:
///   1. PIN 입력 (PinNumpad, 4~6자리) → Verify
///   2. identify-by-pin → IdentityConfirmDialog
///   3. Yes → ActionSheet (today_status 기반 활성/비활성)
///   4. 액션 선택:
///      - clock_in / break_* → 바로 server 호출 → SuccessModal
///      - clock_out:
///          · scheduled_end 보다 한참 일찍 (>5분) → EarlyClockOutDialog
///          · TipEntryDialog (skip 가능)
///          · clock-out API + (tip 있으면) tip API → SuccessModal
///   5. SuccessModal (5초 자동 닫힘) → idle
///
/// state machine 은 [MainFlowState] + transition pure functions 가 담당.
/// 본 widget 은 IO (API 호출) + UI overlay 만 처리.
///
/// 헤더 store name 4초 안에 5번 탭 → Settings 진입 (Phase 6 manage 모드 게이트).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:htm_core/htm_core.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../models/attendance_action.dart';
import '../../models/early_clock_out_reason.dart';
import '../../models/identify_response.dart';
import '../../models/tip_models.dart';
import '../../providers/attendance_dashboard_provider.dart';
import '../../providers/attendance_device_provider.dart';
import '../../utils/main_flow_state.dart';
import '../../utils/main_flow_transitions.dart' as flow;
import '../../utils/store_time.dart';
import '../../widgets/action_sheet.dart';
import '../../widgets/early_clock_out_dialog.dart';
import '../../widgets/identity_confirm_dialog.dart';
import '../../widgets/language_switcher.dart';
import '../../widgets/pin_numpad.dart';
import '../../widgets/success_modal.dart';
import '../../widgets/tip_entry_dialog.dart';
import 'attendance_schedule_screen.dart';
import 'attendance_settings_screen.dart';

class AttendanceMainScreen extends ConsumerStatefulWidget {
  const AttendanceMainScreen({super.key});

  @override
  ConsumerState<AttendanceMainScreen> createState() => _AttendanceMainScreenState();
}

class _AttendanceMainScreenState extends ConsumerState<AttendanceMainScreen> {
  late Timer _clockTimer;
  DateTime _now = DateTime.now();

  MainFlowState _flow = MainFlowState.initial();

  /// clock_out 흐름에서 TipEntryDialog 에 보여줄 receiver 목록. tipEntry stage 진입 시 fetch.
  List<TipReceiver> _tipReceivers = const [];
  /// L5: manual add 검색 풀 — store 전체 active 직원. Tip dialog 진입 시 같이 fetch.
  List<TipReceiver> _storeEmployeesPool = const [];
  bool _loadingReceivers = false;

  /// 5-tap hidden unlock 게이지 (헤더 store name).
  int _hiddenTapCount = 0;
  Timer? _hiddenTapResetTimer;
  static const _hiddenTapTarget = 5;
  static const _hiddenTapWindow = Duration(seconds: 4);

  /// kiosk unlock 모달 표시 여부. 5초 자동 닫힘.
  bool _showKioskUnlockedDialog = false;
  Timer? _kioskDialogTimer;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final prev = _now;
      final next = DateTime.now();
      setState(() => _now = next);
      // 분 경계마다 device 정보 (work_date / tz) 재확인.
      if (prev.minute != next.minute) {
        // ignore: unawaited_futures
        ref.read(attendanceDeviceProvider.notifier).softRefreshDevice();
      }
    });
    // Kiosk lock — register 시 KioskIntent.setEnabled(true) 됐고,
    // resume/cold-start 마다 실제 lock 이 풀려 있으면 다시 start.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (await KioskIntent.isEnabled() && !await KioskLock.isLocked()) {
        await KioskLock.start();
      }
    });
    // 좌측 WORKING 사이드바용 dashboard polling (1분 간격 + initial fetch).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(attendanceDashboardProvider.notifier).startPolling();
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _hiddenTapResetTimer?.cancel();
    _kioskDialogTimer?.cancel();
    // dashboard polling 정지 — schedule/main 양쪽에서 켜는 구조라 어느 쪽 dispose 든 멈춰도 OK.
    ref.read(attendanceDashboardProvider.notifier).stopPolling();
    super.dispose();
  }

  // ─── flow transitions wrappers (IO 호출 포함) ─────────────────────────────

  Future<void> _onPinSubmit(String pin) async {
    setState(() => _flow = flow.startIdentifying(_flow, pin));
    try {
      final user = await ref.read(attendanceDeviceProvider.notifier).identifyUserByPin(pin);
      if (!mounted) return;
      setState(() => _flow = flow.identifySucceeded(_flow, user));
    } catch (e) {
      if (!mounted) return;
      setState(() => _flow = flow.identifyFailed(_flow, _errMessage(e, fallback: 'Invalid PIN')));
    }
  }

  void _onConfirmYes() {
    setState(() => _flow = flow.confirmYes(_flow));
  }

  void _onCloseIdentity() {
    setState(() => _flow = flow.closeIdentity(_flow));
  }

  Future<void> _onActionPicked(AttendanceAction action) async {
    final user = _flow.user!;
    final next = flow.pickAction(
      _flow,
      action,
      scheduledEnd: user.scheduledEnd,
      now: DateTime.now(),
    );
    setState(() => _flow = next);

    // 분기별 후처리
    if (next.stage == MainFlowStage.submitting) {
      await _performClockAction();
    } else if (next.stage == MainFlowStage.tipEntry) {
      await _loadTipReceivers();
    }
  }

  void _onActionCancel() {
    setState(() => _flow = flow.cancelAction(_flow));
  }

  Future<void> _onEarlyReasonSubmit(EarlyClockOutReason reason, String? detail) async {
    setState(() => _flow = flow.submitEarlyReason(_flow, reason, detail));
    await _loadTipReceivers();
  }

  void _onEarlyCancel() {
    setState(() => _flow = flow.cancelEarly(_flow));
  }

  Future<void> _onTipSubmit(TipPayload payload) async {
    setState(() => _flow = flow.submitTip(_flow, payload));
    await _performClockAction();
  }

  Future<void> _onTipSkip() async {
    setState(() => _flow = flow.skipTip(_flow));
    await _performClockAction();
  }

  void _onCloseSuccess() {
    setState(() => _flow = flow.closeSuccess(_flow));
  }

  void _onAcknowledgeError() {
    setState(() => _flow = flow.acknowledgeError(_flow));
  }

  // ─── IO ──────────────────────────────────────────────────────────────────

  Future<void> _loadTipReceivers() async {
    if (_flow.pickedAction != AttendanceAction.clockOut) return;
    setState(() => _loadingReceivers = true);
    final notifier = ref.read(attendanceDeviceProvider.notifier);
    try {
      // 자동 eligible + 매장 전체 직원 풀 병렬 fetch.
      final results = await Future.wait([
        notifier.getTipEligibleReceivers(
          userId: _flow.user!.userId,
          pin: _flow.enteredPin!,
        ),
        notifier.getStoreEmployees().catchError((_) => <TipReceiver>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _tipReceivers = results[0];
        _storeEmployeesPool = results[1];
        _loadingReceivers = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _tipReceivers = const [];
        _storeEmployeesPool = const [];
        _loadingReceivers = false;
      });
    }
  }

  Future<void> _performClockAction() async {
    final action = _flow.pickedAction!;
    final pin = _flow.enteredPin!;
    final user = _flow.user!;
    final reasonText = _composeReasonText(_flow.earlyReason, _flow.earlyDetail);

    final notifier = ref.read(attendanceDeviceProvider.notifier);
    final result = await notifier.performClockAction(
      action: action.apiKey,
      userId: user.userId,
      pin: pin,
      breakType: action.breakType,
      reason: reasonText,
      scheduleId: user.selectedScheduleId, // (Issue 8) 선택된 schedule
    );
    if (!mounted) return;

    if (!result.success) {
      setState(() => _flow = flow.submitFailed(_flow, result.message));
      return;
    }

    // Issue 3 트랙 A: 응답 dict 로 dashboard 의 해당 row 만 즉시 patch.
    // refresh() 호출 없음 — 폴링은 multi-device backstop 으로만 유지.
    final data = result.data;
    if (data != null) {
      try {
        final patched = TodayStaffRow.fromClockResponse(data);
        ref.read(attendanceDashboardProvider.notifier).patchStaffByUserId(patched);
      } catch (_) {
        // 응답 schema 변형/누락 시 무시 — 다음 polling tick 에 정상화
      }
    }

    // clock_out + tip payload 가 있으면 tip 도 추가 호출
    if (action == AttendanceAction.clockOut && _flow.tip != null) {
      final tipResult = await notifier.submitTipEntry(
        userId: user.userId,
        pin: pin,
        payload: _flow.tip!,
      );
      if (!mounted) return;
      if (!tipResult.success) {
        // clock-out 은 성공했으니 success 로 가되, tip 실패는 SnackBar 로만 알림.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tip not recorded: ${tipResult.message}')),
        );
      }
    }

    setState(() => _flow = flow.submitSucceeded(_flow));
  }

  String? _composeReasonText(EarlyClockOutReason? r, String? detail) {
    if (r == null) return null;
    if (r == EarlyClockOutReason.other) return detail;
    return r.apiKey; // 'feeling_unwell' 등
  }

  String _errMessage(Object e, {required String fallback}) {
    final s = e.toString();
    // DioException 의 메시지 추출은 service 가 이미 처리. 여기선 fallback.
    if (s.contains('Invalid PIN')) return 'PIN not recognized';
    return fallback;
  }

  // ─── 헤더 ────────────────────────────────────────────────────────────────

  Future<void> _onHiddenTap() async {
    _hiddenTapCount++;
    _hiddenTapResetTimer?.cancel();
    if (_hiddenTapCount >= _hiddenTapTarget) {
      _hiddenTapCount = 0;
      await _releaseKioskLock();
      return;
    }
    _hiddenTapResetTimer = Timer(_hiddenTapWindow, () {
      _hiddenTapCount = 0;
    });
  }

  /// 5-tap hidden gesture 결과 — kiosk lock 임시 해제.
  /// 5분 후 KioskIntent 가 자동 재잠금. 그동안 Settings/홈 키 사용 가능.
  /// 결과는 SnackBar 가 아닌 모달로 노출 (사용자 요청 — 키오스크 화면에서 토스트가 잘 안 보임).
  Future<void> _releaseKioskLock() async {
    if (await KioskLock.isLocked()) {
      await KioskLock.stop();
    }
    await KioskIntent.disableTemporarily();
    if (!mounted) return;
    _kioskDialogTimer?.cancel();
    setState(() => _showKioskUnlockedDialog = true);
    _kioskDialogTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      setState(() => _showKioskUnlockedDialog = false);
    });
  }

  void _dismissKioskUnlockedDialog() {
    _kioskDialogTimer?.cancel();
    setState(() => _showKioskUnlockedDialog = false);
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AttendanceSettingsScreen()),
    );
  }

  void _openSchedule() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AttendanceScheduleScreen()),
    );
  }

  // ─── build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final device = ref.watch(attendanceDeviceProvider).device;
    final storeName = device?.storeName ?? t.pfStoreFallback;
    // 표시는 매장 현지 시간 — device 위치와 무관.
    final storeNow = toStoreClock(_now, device?.storeTimezoneOffsetMinutes);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          // base layer
          SafeArea(
            child: Column(
              children: [
                _Header(
                  storeName: storeName,
                  now: storeNow,
                  onStoreTap: _onHiddenTap,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 좌측: WORKING 사이드바
                        SizedBox(
                          width: 260,
                          child: _WorkingListSidebar(now: _now),
                        ),
                        const SizedBox(width: 16),
                        // 가운데: PinNumpad (가용 영역 fill)
                        Expanded(
                          child: Center(
                            child: PinNumpad(
                              onSubmit: _onPinSubmit,
                              enabled: _flow.stage == MainFlowStage.idle,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // 우측: Schedule + Settings 가로 버튼 (compact, 위에 모음)
                        SizedBox(
                          width: 240,
                          child: Column(
                            children: [
                              _SidebarActionCard(
                                icon: Icons.calendar_today_outlined,
                                label: t.pfHeaderSchedule,
                                onTap: _openSchedule,
                              ),
                              const SizedBox(height: 12),
                              _SidebarActionCard(
                                icon: Icons.settings_outlined,
                                label: t.pfHeaderSettings,
                                onTap: _openSettings,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // overlay layer
          if (_flow.stage == MainFlowStage.identifying || _flow.stage == MainFlowStage.submitting)
            const _LoadingOverlay(),
          if (_flow.stage == MainFlowStage.confirming && _flow.user != null)
            _BarrierWrap(
              child: IdentityConfirmDialog(
                user: _flow.user!,
                onYes: _onConfirmYes,
                onClose: _onCloseIdentity,
                now: _now,
              ),
            ),
          if (_flow.stage == MainFlowStage.choosingAction && _flow.user != null)
            _BarrierWrap(
              child: ActionSheet(
                user: _flow.user!,
                onPick: _onActionPicked,
                onCancel: _onActionCancel,
                now: _now,
              ),
            ),
          if (_flow.stage == MainFlowStage.earlyReason && _flow.user != null)
            _BarrierWrap(
              child: EarlyClockOutDialog(
                userName: _flow.user!.userName,
                scheduledEnd: _formatTime(_flow.user!.scheduledEnd),
                remainingMinutes: _computeRemainingMinutes(),
                onSubmit: _onEarlyReasonSubmit,
                onCancel: _onEarlyCancel,
              ),
            ),
          if (_flow.stage == MainFlowStage.tipEntry && _flow.user != null)
            _BarrierWrap(
              child: _loadingReceivers
                  ? const _LoadingOverlay()
                  : TipEntryDialog(
                      userName: _flow.user!.userName,
                      receivers: _tipReceivers,
                      manualPool: _storeEmployeesPool,
                      onSubmit: _onTipSubmit,
                      onSkip: _onTipSkip,
                    ),
            ),
          if (_flow.stage == MainFlowStage.success && _flow.user != null && _flow.pickedAction != null)
            _BarrierWrap(
              child: SuccessModal(
                userName: _flow.user!.userName,
                action: _flow.pickedAction!,
                onClose: _onCloseSuccess,
              ),
            ),
          if (_flow.stage == MainFlowStage.error)
            _BarrierWrap(
              child: _ErrorDialog(
                message: _flow.errorMessage ?? t.pfErrorFallback,
                onClose: _onAcknowledgeError,
              ),
            ),
          if (_showKioskUnlockedDialog)
            _BarrierWrap(
              child: _InfoDialog(
                icon: Icons.lock_open_rounded,
                iconColor: AppColors.success,
                iconBg: AppColors.successBg,
                title: t.pfKioskUnlockedTitle,
                body: t.pfKioskUnlockedBody,
                onClose: _dismissKioskUnlockedDialog,
                autoCloseSeconds: 5,
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final offset = ref.read(attendanceDeviceProvider).device?.storeTimezoneOffsetMinutes;
    return DateFormat('HH:mm').format(toStoreClock(dt, offset));
  }

  int _computeRemainingMinutes() {
    final end = _flow.user?.scheduledEnd;
    if (end == null) return 0;
    final diff = end.difference(_now).inMinutes;
    return diff > 0 ? diff : 0;
  }
}

// ─── sub-widgets ──────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String storeName;
  final DateTime now;
  final VoidCallback onStoreTap;

  const _Header({
    required this.storeName,
    required this.now,
    required this.onStoreTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: [
          // 좌: store name + date (탭 5번 = kiosk unlock)
          SizedBox(
            width: 260,
            child: GestureDetector(
              onTap: onStoreTap,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    storeName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    DateFormat('EEE, MMM d').format(now),
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          // 가운데: 시계
          Expanded(
            child: Center(
              child: Text(
                DateFormat('HH:mm:ss').format(now),
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accent,
                  fontFeatures: [FontFeature.tabularFigures()],
                  height: 1.0,
                ),
              ),
            ),
          ),
          // 우: 언어 버튼만
          const SizedBox(
            width: 260,
            child: Align(
              alignment: Alignment.centerRight,
              child: LanguageSwitcher(size: 56),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SidebarActionCard({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 2),
          ),
          child: Row(
            children: [
              Icon(icon, size: 36, color: AppColors.accent),
              const SizedBox(width: 14),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarrierWrap extends StatelessWidget {
  final Widget child;
  const _BarrierWrap({required this.child});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.5),
      child: SafeArea(child: Center(child: child)),
    );
  }
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.4),
      child: const Center(
        child: SizedBox(
          width: 60,
          height: 60,
          child: CircularProgressIndicator(strokeWidth: 4, color: Colors.white),
        ),
      ),
    );
  }
}

class _ErrorDialog extends StatelessWidget {
  final String message;
  final VoidCallback onClose;
  const _ErrorDialog({required this.message, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(color: AppColors.dangerBg, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: const Icon(Icons.error_outline, size: 36, color: AppColors.danger),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: AppColors.text, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: onClose,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(AppL10n.of(context).pfErrorOk, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoDialog extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String body;
  final VoidCallback onClose;
  final int autoCloseSeconds;

  const _InfoDialog({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.body,
    required this.onClose,
    required this.autoCloseSeconds,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Icon(icon, size: 40, color: iconColor),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: onClose,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    AppL10n.of(context).pfSuccessOk,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                AppL10n.of(context).pfSuccessAutoClose.replaceAll('5', '$autoCloseSeconds'),
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkingListSidebar extends ConsumerWidget {
  final DateTime now;
  const _WorkingListSidebar({required this.now});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppL10n.of(context);
    final dashboard = ref.watch(attendanceDashboardProvider);
    final rows = dashboard.staff.where((r) {
      return r.status == 'working' || r.status == 'on_break';
    }).toList()
      ..sort((a, b) => a.userName.compareTo(b.userName));

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Text(
                  t.pfMainWorkingHeader,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.successBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${rows.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.success,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: rows.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        t.pfMainWorkingEmpty,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AppColors.border, indent: 16, endIndent: 16),
                    itemBuilder: (_, i) => _WorkingRow(row: rows[i], now: now),
                  ),
          ),
        ],
      ),
    );
  }
}

class _WorkingRow extends StatelessWidget {
  final TodayStaffRow row;
  final DateTime now;
  const _WorkingRow({required this.row, required this.now});

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final isBreak = row.status == 'on_break';
    final String subline;
    final Color subColor;
    if (isBreak && row.currentBreak != null) {
      final elapsed = now.difference(row.currentBreak!.startedAt).inMinutes;
      final typeKey = (row.currentBreak!.breakType == 'unpaid_meal' ||
              row.currentBreak!.breakType == 'unpaid_long')
          ? t.pfMainBreakTypeMeal
          : t.pfMainBreakTypeShort;
      subline = t.pfMainBreakDuration(_fmtDuration(elapsed), typeKey);
      subColor = AppColors.warning;
    } else {
      final mins = row.clockIn != null ? now.difference(row.clockIn!).inMinutes : 0;
      subline = t.pfMainWorkingDuration(_fmtDuration(mins));
      subColor = AppColors.success;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isBreak ? AppColors.warning : AppColors.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  row.userName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subline,
                  style: TextStyle(fontSize: 11, color: subColor, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// "Xh Ym" or "Nm" — UI 표시용.
  String _fmtDuration(int totalMinutes) {
    final m = totalMinutes.clamp(0, 1 << 30);
    if (m < 60) return '${m}m';
    return '${m ~/ 60}h ${m % 60}m';
  }
}
