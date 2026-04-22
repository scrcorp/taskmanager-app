/// 출퇴근 키오스크 대시보드 — 패드용 메인 화면
///
/// 구성 (3-column 레이아웃):
/// 좌측: Shift Actions (Clock In, Clock Out, Take a Break)
/// 중앙: Currently On Shift + Coming Up Next
/// 우측: Current Time + Notice Board
///
/// 매장 패드에서만 활성화되는 키오스크 모드 화면.
/// 1분마다 시계 갱신, initState에서 근무자 목록 로드.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../providers/clock_provider.dart';
import '../../providers/announcement_provider.dart';

/// Clock 액션 종류 (PIN 화면에 전달)
enum ClockAction { clockIn, clockOut, takeBreak }

class ClockScreen extends ConsumerStatefulWidget {
  const ClockScreen({super.key});

  @override
  ConsumerState<ClockScreen> createState() => _ClockScreenState();
}

class _ClockScreenState extends ConsumerState<ClockScreen> {
  late Timer _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });
    Future.microtask(() {
      final width = MediaQuery.of(context).size.width;
      if (width >= 768) {
        ref.read(clockProvider.notifier).loadDashboard();
        ref.read(announcementProvider.notifier).loadAnnouncements();
      } else {
        ref.read(clockProvider.notifier).loadMobileData();
      }
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  void _navigateToPin(ClockAction action) {
    context.push('/clock/pin', extra: action);
  }

  @override
  Widget build(BuildContext context) {
    final clockState = ref.watch(clockProvider);
    final announcements = ref.watch(announcementProvider);
    final width = MediaQuery.of(context).size.width;

    // 패드 레이아웃 (768px 이상) vs 모바일 레이아웃
    if (width >= 768) {
      return _buildTabletLayout(clockState, announcements);
    }
    return _buildMobileLayout(clockState, announcements);
  }

  /// 패드(태블릿) 3-column 레이아웃
  Widget _buildTabletLayout(ClockState clockState, AnnouncementState announcements) {
    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: () => ref.read(clockProvider.notifier).loadDashboard(),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 좌측: Shift Actions ──
              SizedBox(
                width: 200,
                child: _buildShiftActions(),
              ),
              const SizedBox(width: 24),
              // ── 중앙: On Shift + Coming Up ──
              Expanded(
                child: Column(
                  children: [
                    _buildOnShiftSection(clockState),
                    const SizedBox(height: 20),
                    _buildComingUpSection(clockState),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // ── 우측: Time + Notice ──
              SizedBox(
                width: 220,
                child: Column(
                  children: [
                    _buildCurrentTime(),
                    const SizedBox(height: 20),
                    _buildNoticeBoard(announcements),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 모바일 레이아웃 — 직원 개인폰용 (Attendance + Today's Team)
  Widget _buildMobileLayout(ClockState clockState, AnnouncementState announcements) {
    final attendance = clockState.attendance;
    final team = clockState.todayTeam;

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: () => ref.read(clockProvider.notifier).loadMobileData(),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Attendance 요약 ──
          Container(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.accentBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.calendar_month_rounded, size: 18, color: AppColors.accent),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'My Attendance',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text),
                        ),
                        Text(
                          attendance?.month ?? DateFormat('MMMM yyyy').format(_now),
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (clockState.isLoading)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ))
                else
                  Row(
                    children: [
                      _AttendanceStat(
                        label: 'Days Worked',
                        value: '${attendance?.daysWorked ?? 0}',
                        sub: '/ ${attendance?.totalScheduled ?? 0}',
                        color: AppColors.accent,
                      ),
                      _attendanceDivider(),
                      _AttendanceStat(
                        label: 'Late',
                        value: '${attendance?.lateCount ?? 0}',
                        color: attendance != null && attendance.lateCount > 0
                            ? AppColors.warning
                            : AppColors.success,
                      ),
                      _attendanceDivider(),
                      _AttendanceStat(
                        label: 'Early Leave',
                        value: '${attendance?.earlyLeaveCount ?? 0}',
                        color: attendance != null && attendance.earlyLeaveCount > 0
                            ? AppColors.warning
                            : AppColors.success,
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Today's Team ──
          Container(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.successBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.people_rounded, size: 18, color: AppColors.success),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "Today's Team",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.successBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${team.length} on duty',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.success),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (clockState.isLoading)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ))
                else if (team.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text('No teammates scheduled today', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                    ),
                  )
                else
                  ...team.map((member) => _TeamMemberTile(member: member)),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _attendanceDivider() {
    return Container(
      width: 1,
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: AppColors.border,
    );
  }

  // ─── Shift Actions (패드 - 세로 배치) ─────────────────────────────

  Widget _buildShiftActions() {
    final storeName = ref.watch(clockProvider).storeName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 고정 매장명 ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.accentBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.store_rounded, size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  storeName,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.accent),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.push_pin, size: 14, color: AppColors.accent),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Shift Actions',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text),
        ),
        const SizedBox(height: 4),
        const Text(
          'Tap to update your status',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        const SizedBox(height: 20),
        _ShiftActionButton(
          icon: Icons.login_rounded,
          label: 'CLOCK IN',
          subtitle: 'Start Workday',
          color: AppColors.accent,
          onTap: () => _navigateToPin(ClockAction.clockIn),
        ),
        const SizedBox(height: 12),
        _ShiftActionButton(
          icon: Icons.logout_rounded,
          label: 'CLOCK OUT',
          subtitle: 'End Schedule',
          color: AppColors.textSecondary,
          onTap: () => _navigateToPin(ClockAction.clockOut),
        ),
        const SizedBox(height: 12),
        _ShiftActionButton(
          icon: Icons.free_breakfast_rounded,
          label: 'Take a Break',
          subtitle: '',
          color: AppColors.warning,
          isFilled: true,
          onTap: () => _navigateToPin(ClockAction.takeBreak),
        ),
      ],
    );
  }

  // ─── Currently On Shift ────────────────────────────────────────────

  Widget _buildOnShiftSection(ClockState clockState) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Currently On Shift',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.successBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${clockState.onShift.length} ACTIVE',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.success),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (clockState.isLoading)
            const Center(child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(strokeWidth: 2),
            ))
          else if (clockState.onShift.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('No one currently on shift', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
              ),
            )
          else
            ...clockState.onShift.map((emp) => _OnShiftTile(employee: emp)),
        ],
      ),
    );
  }

  // ─── Coming Up Next ───────────────────────────────────────────────

  Widget _buildComingUpSection(ClockState clockState) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Coming Up Next',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'NEXT 5 HOURS',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (clockState.isLoading)
            const Center(child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(strokeWidth: 2),
            ))
          else if (clockState.comingUp.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('No upcoming shifts', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
              ),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: clockState.comingUp.map((emp) => _ComingUpCard(employee: emp)).toList(),
            ),
        ],
      ),
    );
  }

  // ─── Current Time ──────────────────────────────────────────────────

  Widget _buildCurrentTime() {
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
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white54, letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          Text(
            DateFormat('hh:mm').format(_now),
            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -1),
          ),
          Text(
            DateFormat('a').format(_now),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            DateFormat('EEE, MMM d, yyyy').format(_now),
            style: const TextStyle(fontSize: 12, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  // ─── Notice Board ──────────────────────────────────────────────────

  Widget _buildNoticeBoard(AnnouncementState announcements) {
    final notices = announcements.announcements;
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Notice Board',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text),
          ),
          const SizedBox(height: 12),
          if (notices.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No notices', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
            )
          else
            ...notices.take(3).map((notice) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => context.push('/notices/${notice.id}'),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notice.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text, height: 1.3),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notice.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ),
            )),
        ],
      ),
    );
  }
}

// ─── Shift Action Button (패드 세로형) ──────────────────────────────────

class _ShiftActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final bool isFilled;
  final VoidCallback onTap;

  const _ShiftActionButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    this.isFilled = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: isFilled ? color : AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: isFilled ? null : Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: isFilled ? Colors.white : color),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isFilled ? Colors.white : color,
                letterSpacing: 0.5,
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: isFilled ? Colors.white70 : AppColors.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── On Shift Employee Tile ─────────────────────────────────────────────

class _OnShiftTile extends StatelessWidget {
  final OnShiftEmployee employee;
  const _OnShiftTile({required this.employee});

  @override
  Widget build(BuildContext context) {
    final isBreak = employee.status == 'break';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.accentBg,
            child: Text(
              _initials(employee.name),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accent),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee.name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text),
                ),
                Text(
                  employee.role,
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          if (isBreak)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.warningBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Break',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.warning),
              ),
            )
          else
            Text(
              'Since ${employee.since}',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }
}

// ─── Coming Up Card ──────────────────────────────────────────────────────

class _ComingUpCard extends StatelessWidget {
  final ComingUpEmployee employee;
  const _ComingUpCard({required this.employee});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.accentBg,
            child: Text(
              _initials(employee.name),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.accent),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            employee.name,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            employee.role,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.accentBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${employee.startTime} - ${employee.endTime}',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }
}

// ─── Attendance Stat (모바일) ────────────────────────────────────────────

class _AttendanceStat extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final Color color;

  const _AttendanceStat({
    required this.label,
    required this.value,
    this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.5),
              ),
              if (sub != null) ...[
                const SizedBox(width: 2),
                Text(sub!, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ─── Team Member Tile (모바일) ───────────────────────────────────────────

class _TeamMemberTile extends StatelessWidget {
  final TeamMember member;
  const _TeamMemberTile({required this.member});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.accentBg,
            child: Text(
              _initials(member.name),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accent),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text),
                ),
                Text(
                  member.role,
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          if (member.shift.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.accentBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                member.shift,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.accent),
              ),
            ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }
}
