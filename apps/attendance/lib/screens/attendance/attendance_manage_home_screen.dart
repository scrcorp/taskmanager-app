/// 관리자 모드 홈 — 오늘 스케줄 그리드.
///
/// 큰 카드 그리드 (태블릿 2-column). 카드 탭 시 큰 액션 시트가 모달로 열리고
/// Edit / Change Status / Delete + 빠른 clock 액션을 큰 버튼으로 제공.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:htm_core/htm_core.dart';

import '../../providers/attendance_manage_provider.dart';
import '../../services/attendance_device_service.dart';
import 'attendance_manage_action_sheet.dart';
import 'attendance_manage_schedule_edit_screen.dart';

class AttendanceManageHomeScreen extends ConsumerStatefulWidget {
  const AttendanceManageHomeScreen({super.key});

  @override
  ConsumerState<AttendanceManageHomeScreen> createState() =>
      _AttendanceManageHomeScreenState();
}

class _AttendanceManageHomeScreenState
    extends ConsumerState<AttendanceManageHomeScreen> {
  bool _loading = true;
  List<AdminScheduleRow> _schedules = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
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
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AttendanceManageScheduleEditScreen(),
      ),
    );
    if (!mounted) return;
    await _refresh();
  }

  Future<void> _openCardActions(AdminScheduleRow row) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => AttendanceManageActionSheet(
        row: row,
        onChanged: _refresh,
      ),
    );
    if (!mounted) return;
    // 시트 안에서 직접 _refresh 호출하기도 하지만, 닫힐 때도 한번 더 동기화.
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(attendanceManageSessionProvider);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _exitAdminMode(silent: true);
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                _buildHeader(session.managerName ?? 'Manager'),
                const SizedBox(height: 16),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String managerName) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.warningBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.admin_panel_settings_rounded,
                  size: 18, color: AppColors.warning),
              SizedBox(width: 8),
              Text(
                'MANAGE MODE',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.warning,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Text(
          managerName,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
          ),
        ),
        const Spacer(),
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
          onTap: () => _exitAdminMode(),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text(
              "Today's Schedules",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accentBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_schedules.length}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accent,
                ),
              ),
            ),
            const Spacer(),
            _BigPrimaryButton(
              icon: Icons.add_rounded,
              label: 'Add Schedule',
              onTap: _openCreate,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 480,
              mainAxisExtent: 200,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: _schedules.length,
            itemBuilder: (_, i) =>
                _ScheduleCard(row: _schedules[i], onTap: () => _openCardActions(_schedules[i])),
          ),
        ),
      ],
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
              child: const Icon(Icons.event_available_rounded,
                  size: 48, color: AppColors.accent),
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
            _BigPrimaryButton(
              icon: Icons.add_rounded,
              label: 'Add Schedule',
              onTap: _openCreate,
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

// ─── Big schedule card ──────────────────────────────────────────

class _ScheduleCard extends StatelessWidget {
  final AdminScheduleRow row;
  final VoidCallback onTap;

  const _ScheduleCard({required this.row, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = row.attendanceStatus ?? '';
    final badge = _statusBadgeData(status);

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.accentBg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _initial(row.userName),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.userName,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (row.workRoleLabel != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            row.workRoleLabel!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: badge.bg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badge.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: badge.fg,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: _CardField(
                      label: 'SCHEDULED',
                      value:
                          '${row.startHHmm ?? '--:--'} – ${row.endHHmm ?? '--:--'}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CardField(
                      label: 'CLOCK IN',
                      value: row.clockInDisplay ?? '—',
                      valueColor: row.clockInDisplay != null
                          ? AppColors.success
                          : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CardField(
                      label: 'CLOCK OUT',
                      value: row.clockOutDisplay ?? '—',
                      valueColor: row.clockOutDisplay != null
                          ? AppColors.textSecondary
                          : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _initial(String name) {
    final t = name.trim();
    if (t.isEmpty) return '?';
    return t.characters.first.toUpperCase();
  }

  _StatusBadgeData? _statusBadgeData(String status) {
    if (status.isEmpty) return null;
    switch (status) {
      case 'working':
        return _StatusBadgeData('WORKING', AppColors.successBg, AppColors.success);
      case 'late':
        return _StatusBadgeData('LATE', AppColors.warningBg, AppColors.warning);
      case 'on_break':
        return _StatusBadgeData('ON BREAK', AppColors.warningBg, AppColors.warning);
      case 'clocked_out':
        return _StatusBadgeData('DONE', AppColors.bg, AppColors.textMuted);
      case 'no_show':
        return _StatusBadgeData('NO SHOW', AppColors.dangerBg, AppColors.danger);
      case 'soon':
        return _StatusBadgeData('SOON', AppColors.accentBg, AppColors.accent);
      case 'upcoming':
        return _StatusBadgeData('UPCOMING', AppColors.bg, AppColors.textMuted);
      default:
        return _StatusBadgeData(status.toUpperCase(), AppColors.bg, AppColors.textMuted);
    }
  }
}

class _StatusBadgeData {
  final String label;
  final Color bg;
  final Color fg;
  _StatusBadgeData(this.label, this.bg, this.fg);
}

class _CardField extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _CardField({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: AppColors.textMuted,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: valueColor ?? AppColors.text,
          ),
        ),
      ],
    );
  }
}

/// 어디서나 쓸 수 있는 axios/dio 에러 본문 추출.
String extractApiError(Object e, String fallback) {
  try {
    final resp = (e as dynamic).response;
    final data = resp?.data;
    if (data is Map && data['detail'] is String) return data['detail'] as String;
  } catch (_) {}
  return fallback;
}
