/// AttendanceScheduleScreen — 좌측 섹션 (자체 스크롤) + 우측 디테일 패널.
///
/// 전체 페이지 스크롤 X. 각 섹션 fixed-flex, 안에서 grid auto-fill + overflow scroll.
/// 블록 클릭 → 우측 디테일 갱신.
///
/// 데이터: attendance_dashboard_provider (Main 과 공유).

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:htm_core/htm_core.dart';
import 'package:intl/intl.dart';

import '../../providers/attendance_dashboard_provider.dart';
import '../../providers/attendance_device_provider.dart';
import '../../utils/staff_status_utils.dart';
import '../../utils/store_time.dart';
import '../../widgets/staff_block.dart';
import '../../widgets/staff_detail_panel.dart';

class AttendanceScheduleScreen extends ConsumerStatefulWidget {
  const AttendanceScheduleScreen({super.key});

  @override
  ConsumerState<AttendanceScheduleScreen> createState() => _AttendanceScheduleScreenState();
}

class _AttendanceScheduleScreenState extends ConsumerState<AttendanceScheduleScreen> {
  String? _selectedUserId;
  late Timer _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
    // dashboard polling 은 schedule 화면에 들어왔을 때만 활성.
    // 기존엔 main_screen 이 켰지만 새 PIN-first main 은 today-staff 안 씀.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(attendanceDashboardProvider.notifier).startPolling();
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    // 화면 떠날 때 polling 정지 — main 으로 돌아가면 더 이상 필요 없음.
    ref.read(attendanceDashboardProvider.notifier).stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(attendanceDashboardProvider);
    final device = ref.watch(attendanceDeviceProvider).device;
    final staff = dashboard.staff;

    // 섹션별 분류
    final onShift = staff.where((r) => classifySection(r.status) == StaffSection.onShift).toList();
    final notClockedIn =
        staff.where((r) => classifySection(r.status) == StaffSection.notClockedIn).toList();
    final completed =
        staff.where((r) => classifySection(r.status) == StaffSection.completed).toList();

    final selected = _selectedUserId == null
        ? null
        : staff.where((r) => r.userId == _selectedUserId).firstOrNull;

    // 헤더 시계/날짜는 매장 현지 시간.
    final storeNow = toStoreClock(_now, device?.storeTimezoneOffsetMinutes);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              storeName: device?.storeName ?? 'Store',
              now: storeNow,
              onClose: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 좌측 섹션 컬럼
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: _Section(
                              title: 'On Shift',
                              accent: AppColors.success,
                              staff: onShift,
                              selectedUserId: _selectedUserId,
                              onSelect: (id) => setState(() => _selectedUserId = id),
                              emptyText: 'Nobody is currently on shift.',
                              now: _now,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: _Section(
                              title: 'Not Clocked In',
                              accent: AppColors.warning,
                              staff: notClockedIn,
                              selectedUserId: _selectedUserId,
                              onSelect: (id) => setState(() => _selectedUserId = id),
                              emptyText: 'Everyone is clocked in.',
                              now: _now,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: _Section(
                              title: 'Completed Today',
                              accent: AppColors.textSecondary,
                              staff: completed,
                              selectedUserId: _selectedUserId,
                              onSelect: (id) => setState(() => _selectedUserId = id),
                              emptyText: 'No completed shifts yet.',
                              now: _now,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // 우측 디테일 패널 (360 고정)
                    SizedBox(
                      width: 360,
                      child: Container(
                        padding: const EdgeInsets.all(24),
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
                        child: StaffDetailPanel(row: selected, now: _now),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ──────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String storeName;
  final DateTime now;
  final VoidCallback onClose;
  const _Header({
    required this.storeName,
    required this.now,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Row(
        children: [
          // 좌: store name + date
          SizedBox(
            width: 280,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  storeName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('EEE, MMM d, y', locale).format(now),
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          // 가운데: 시계 (메인과 통일)
          Expanded(
            child: Center(
              child: Text(
                DateFormat('HH:mm:ss').format(now),
                style: const TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accent,
                  fontFeatures: [FontFeature.tabularFigures()],
                  height: 1.0,
                ),
              ),
            ),
          ),
          // 우: Back to PIN
          SizedBox(
            width: 280,
            child: Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: onClose,
                icon: const Icon(Icons.arrow_back_rounded, size: 20),
                label: const Text('Back to PIN'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.white,
                  foregroundColor: AppColors.accent,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  side: const BorderSide(color: AppColors.border, width: 1.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section ─────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final Color accent;
  final List<TodayStaffRow> staff;
  final String? selectedUserId;
  final ValueChanged<String> onSelect;
  final String emptyText;
  final DateTime now;

  const _Section({
    required this.title,
    required this.accent,
    required this.staff,
    required this.selectedUserId,
    required this.onSelect,
    required this.emptyText,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
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
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${staff.length}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: staff.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      emptyText,
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    physics: const AlwaysScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 180,
                      mainAxisExtent: 60,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: staff.length,
                    itemBuilder: (_, i) => StaffBlock(
                      row: staff[i],
                      selected: selectedUserId == staff[i].userId,
                      onTap: () => onSelect(staff[i].userId),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
