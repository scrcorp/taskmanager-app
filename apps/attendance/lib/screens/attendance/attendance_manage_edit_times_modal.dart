/// 관리자 모드 — **상태는 그대로 두고 시각만** 고치는 모달.
///
/// 기존에는 clock-in 시각 하나를 3분 당기려 해도 Undo Clock-in → 다시 Clock In
/// 으로 상태를 되돌렸다 주입해야 했다 (2026-08-09 제보). 그 과정에서 break 기록이
/// 정리되고 anomaly 가 지워지는 부수효과가 났다. 이 화면은 상태 전이를 하지 않는다.
///
/// 레이아웃: 고칠 칸을 칩으로 고르고 아래 휠 하나로 값을 맞춘다. 휠을 여러 개
/// 세로로 쌓으면 키오스크 세로 공간을 넘겨서, break 가 몇 개든 높이가 같은 이 형태로.
/// 바뀐 칩에는 점(•)을 찍어 "저장하면 같이 나간다"를 보이게 한다.
///
/// 순서/겹침 검증은 서버가 한다 (영업일 경계를 클라가 모른다) — 서버 메시지를
/// 모달 안 인라인 배너로 보여준다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:htm_core/htm_core.dart';

import '../../providers/attendance_manage_provider.dart';
import '../../services/attendance_device_service.dart';
import '../../utils/edit_times_logic.dart';
import '../../widgets/reason_picker.dart';
import '../../widgets/time_wheel.dart';
import '../../utils/api_error_display.dart' show extractApiError;

class AttendanceManageEditTimesModal extends ConsumerStatefulWidget {
  final AdminScheduleRow row;

  const AttendanceManageEditTimesModal({super.key, required this.row});

  /// 적용 성공 시 true.
  static Future<bool> show(BuildContext context, {required AdminScheduleRow row}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (_) => AttendanceManageEditTimesModal(row: row),
    );
    return result == true;
  }

  @override
  ConsumerState<AttendanceManageEditTimesModal> createState() =>
      _AttendanceManageEditTimesModalState();
}

class _AttendanceManageEditTimesModalState
    extends ConsumerState<AttendanceManageEditTimesModal> {
  late final List<TimeTarget> _targets;
  late final Map<String, int> _values; // target.key → 편집 중인 분
  int _selected = 0;
  String _reason = '';
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _targets = buildTimeTargets(widget.row);
    _values = {for (final t in _targets) t.key: t.originalMinutes};
  }

  TimeTarget? get _current =>
      _targets.isEmpty ? null : _targets[_selected.clamp(0, _targets.length - 1)];

  EditTimesPayload get _payload => buildEditTimesPayload(_targets, _values);

  Future<void> _save() async {
    if (_saving) return;
    final payload = _payload;
    if (!canSubmitEditTimes(payload, _reason)) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(attendanceDeviceServiceProvider).manageEditTimes(
            userId: widget.row.userId,
            reason: _reason.trim(),
            clockInHHmm: payload.clockInHHmm,
            clockOutHHmm: payload.clockOutHHmm,
            breaks: payload.breaks,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = extractApiError(e, 'Could not save the times.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final current = _current;
    final canSave = canSubmitEditTimes(_payload, _reason);

    return Dialog(
      backgroundColor: AppColors.white,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.userName.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textMuted,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Edit Times',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Correct a recorded time. The status stays exactly as it is.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
              ),
              if (current == null) ...[
                const SizedBox(height: 20),
                const Text(
                  'There is no recorded time to edit yet. Use Clock In first.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Close'),
                ),
              ] else ...[
                // 본문 전체가 스크롤 — break 가 여러 개면 칩이 여러 줄이 되고,
                // 키오스크보다 짧은 화면(에뮬레이터/구형 태블릿)에서 잘리면 안 된다.
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                const SizedBox(height: 14),
                const _SectionLabel('WHICH TIME'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < _targets.length; i++)
                      _TargetChip(
                        label: _targets[i].label,
                        value: _hhmm(_values[_targets[i].key]!),
                        changed: _values[_targets[i].key] != _targets[i].originalMinutes,
                        selected: i == _selected,
                        onTap: () => setState(() => _selected = i),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.bg.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      _SectionLabel(current.label.toUpperCase()),
                      TimeWheel(
                        // 실제로 찍힌 시각이라 1분 단위 — 스케줄의 5분 그리드와 다르다.
                        key: ValueKey(current.key),
                        stepMinutes: clockStepMinutes,
                        initialMinutes: _values[current.key]!,
                        onChanged: (v) => setState(() => _values[current.key] = v),
                      ),
                      Text(
                        changeHint(current.originalMinutes, _values[current.key]!) ??
                            'Unchanged',
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    const _SectionLabel('REASON'),
                    const Spacer(),
                    const Text(
                      'Required',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ReasonPicker(onChanged: (v) => setState(() => _reason = v)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: (_saving || !canSave) ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          disabledBackgroundColor:
                              AppColors.accent.withValues(alpha: 0.4),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Save Times',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _hhmm(int min) =>
      '${(min ~/ 60).toString().padLeft(2, '0')}:${(min % 60).toString().padLeft(2, '0')}';
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.textMuted,
          letterSpacing: 1.2,
        ),
      );
}

/// 고칠 칸 하나를 고르는 칩. 값이 바뀐 칩은 점(•)으로 표시된다.
class _TargetChip extends StatelessWidget {
  final String label;
  final String value;
  final bool changed;
  final bool selected;
  final VoidCallback onTap;

  const _TargetChip({
    required this.label,
    required this.value,
    required this.changed,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = changed ? AppColors.warning : AppColors.accent;
    return Material(
      color: selected ? accent.withValues(alpha: 0.15) : AppColors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? accent : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? accent : AppColors.text,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: changed ? AppColors.warning : AppColors.textSecondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (changed)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Text(
                    '•',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: AppColors.warning,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
