/// Issue Report LinkPicker widget.
///
/// console 의 LinkPicker.tsx 와 동등. 단순화된 3섹션:
///   - Related schedules — schedule + 1:1 checklist instance 통합 표시. 최신순,
///     date 필터 + free-text 검색.
///   - Related role — Owner / GM / SV / Staff / All chip (relatedUserIds 매크로 add/remove).
///   - Related people — 매장 user 개별 + 이름/role 검색.
///
/// positionIds / workRoleIds 는 schema 호환 위해 LinkValues 에 유지하지만
/// UI 에서는 노출하지 않음 (deprecated).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:htm_core/htm_core.dart';

import '../../services/issue_report_service.dart';

class LinkValues {
  final List<String> scheduleIds;
  final List<String> checklistInstanceIds;
  final List<String> positionIds;
  final List<String> workRoleIds;
  final List<String> relatedUserIds;
  final List<String> relatedRoles;

  const LinkValues({
    this.scheduleIds = const [],
    this.checklistInstanceIds = const [],
    this.positionIds = const [],
    this.workRoleIds = const [],
    this.relatedUserIds = const [],
    this.relatedRoles = const [],
  });

  bool get isEmpty =>
      scheduleIds.isEmpty &&
      checklistInstanceIds.isEmpty &&
      positionIds.isEmpty &&
      workRoleIds.isEmpty &&
      relatedUserIds.isEmpty &&
      relatedRoles.isEmpty;

  Map<String, List<String>> toJson() => {
        'schedule_ids': scheduleIds,
        'checklist_instance_ids': checklistInstanceIds,
        'position_ids': positionIds,
        'work_role_ids': workRoleIds,
        'related_user_ids': relatedUserIds,
        'related_roles': relatedRoles,
      };

  LinkValues copyWith({
    List<String>? scheduleIds,
    List<String>? checklistInstanceIds,
    List<String>? positionIds,
    List<String>? workRoleIds,
    List<String>? relatedUserIds,
    List<String>? relatedRoles,
  }) =>
      LinkValues(
        scheduleIds: scheduleIds ?? this.scheduleIds,
        checklistInstanceIds:
            checklistInstanceIds ?? this.checklistInstanceIds,
        positionIds: positionIds ?? this.positionIds,
        workRoleIds: workRoleIds ?? this.workRoleIds,
        relatedUserIds: relatedUserIds ?? this.relatedUserIds,
        relatedRoles: relatedRoles ?? this.relatedRoles,
      );
}

// role chip 정의 — server role_name 으로 매칭. all 은 모든 user 매크로.
class _RoleChip {
  final String key;
  final String label;
  final bool Function(Map<String, dynamic> user) match;
  const _RoleChip({required this.key, required this.label, required this.match});
}

const _roleChips = <_RoleChip>[
  _RoleChip(key: 'owner', label: 'Owner', match: _matchOwner),
  _RoleChip(key: 'gm', label: 'GM', match: _matchGm),
  _RoleChip(key: 'sv', label: 'SV', match: _matchSv),
  _RoleChip(key: 'staff', label: 'Staff', match: _matchStaff),
  _RoleChip(key: 'all', label: 'All', match: _matchAll),
];

bool _matchOwner(Map<String, dynamic> u) => u['role_priority'] == 10;
bool _matchGm(Map<String, dynamic> u) => u['role_priority'] == 20;
bool _matchSv(Map<String, dynamic> u) => u['role_priority'] == 30;
bool _matchStaff(Map<String, dynamic> u) => u['role_priority'] == 40;
bool _matchAll(Map<String, dynamic> u) => true;

class IssueReportLinkPicker extends ConsumerStatefulWidget {
  final String? storeId;
  final LinkValues value;
  final ValueChanged<LinkValues> onChanged;

  const IssueReportLinkPicker({
    super.key,
    required this.storeId,
    required this.value,
    required this.onChanged,
  });

  @override
  ConsumerState<IssueReportLinkPicker> createState() =>
      _IssueReportLinkPickerState();
}

class _IssueReportLinkPickerState extends ConsumerState<IssueReportLinkPicker> {
  Map<String, dynamic>? _options;
  bool _loading = false;
  String? _loadedStoreId;

  String _schedQuery = '';
  String _schedDate = ''; // ISO yyyy-MM-dd
  String _peopleQuery = '';

  @override
  void didUpdateWidget(covariant IssueReportLinkPicker old) {
    super.didUpdateWidget(old);
    if (widget.storeId != old.storeId) {
      _options = null;
      _loadedStoreId = null;
      _maybeLoad();
    }
  }

  @override
  void initState() {
    super.initState();
    _maybeLoad();
  }

  Future<void> _maybeLoad() async {
    final sid = widget.storeId;
    if (sid == null || sid == _loadedStoreId) return;
    setState(() => _loading = true);
    try {
      final data = await ref.read(issueReportServiceProvider).getLinkOptions(sid);
      if (!mounted) return;
      setState(() {
        _options = data;
        _loadedStoreId = sid;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.storeId == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Text(
          'Select a store first to choose related items.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_options == null) {
      return const SizedBox.shrink();
    }
    final schedules =
        (_options!['schedules'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final checklists =
        (_options!['checklist_instances'] as List?)?.cast<Map<String, dynamic>>() ??
            [];
    final users =
        (_options!['users'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    // schedule → 매핑된 checklist instance lookup (1:1).
    final clByScheduleId = <String, Map<String, dynamic>>{};
    for (final c in checklists) {
      final sid = c['schedule_id'];
      if (sid is String) clByScheduleId[sid] = c;
    }

    // schedule 정렬 (work_date desc) + date / 검색 필터
    final sortedSchedules = [...schedules]
      ..sort((a, b) {
        final da = (a['work_date'] ?? '') as String;
        final db = (b['work_date'] ?? '') as String;
        return db.compareTo(da);
      });
    final filteredSchedules = sortedSchedules.where((s) {
      if (_schedDate.isNotEmpty && s['work_date'] != _schedDate) return false;
      if (_schedQuery.isEmpty) return true;
      final q = _schedQuery.toLowerCase();
      final fields = [
        s['work_date'],
        s['user_name'],
        s['work_role_name'],
        s['work_role_name_snapshot'],
        s['position_snapshot'],
      ];
      return fields.any((v) =>
          v is String && v.toLowerCase().contains(q));
    }).toList();

    // user 정렬 (role_priority asc, name asc)
    final sortedUsers = [...users]
      ..sort((a, b) {
        final pa = (a['role_priority'] as int?) ?? 999;
        final pb = (b['role_priority'] as int?) ?? 999;
        if (pa != pb) return pa.compareTo(pb);
        return ((a['full_name'] ?? a['username'] ?? '') as String)
            .compareTo((b['full_name'] ?? b['username'] ?? '') as String);
      });
    final filteredUsers = _peopleQuery.trim().isEmpty
        ? sortedUsers
        : sortedUsers.where((u) {
            final q = _peopleQuery.toLowerCase();
            final fields = [u['full_name'], u['username'], u['role_name']];
            return fields.any((v) =>
                v is String && v.toLowerCase().contains(q));
          }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Related schedules ──
        _sectionHeader(
          Icons.event_outlined,
          _schedDate.isNotEmpty
              ? 'Related schedules · $_schedDate'
              : 'Related schedules',
        ),
        const SizedBox(height: 6),
        _scheduleFilters(),
        const SizedBox(height: 6),
        _scheduleList(filteredSchedules, clByScheduleId),
        const SizedBox(height: 16),

        // ── Related role chips ──
        _sectionHeader(
          Icons.groups_outlined,
          'Related role · adds everyone with that role',
        ),
        const SizedBox(height: 6),
        _roleChipsRow(sortedUsers),
        const SizedBox(height: 16),

        // ── Related people ──
        _sectionHeader(Icons.people_alt_outlined, 'Related people'),
        const Padding(
          padding: EdgeInsets.only(top: 2, bottom: 6),
          child: Text(
            'People involved or witnesses. Does not grant access.',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ),
        _peopleSearch(),
        const SizedBox(height: 6),
        _peopleList(filteredUsers),
      ],
    );
  }

  Widget _sectionHeader(IconData icon, String title) => Row(
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      );

  Widget _scheduleFilters() => Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 34,
              child: TextField(
                onChanged: (v) => setState(() => _schedQuery = v),
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(
                  hintText: 'Search name / date / role',
                  hintStyle: TextStyle(fontSize: 12),
                  prefixIcon: Icon(Icons.search, size: 16),
                  prefixIconConstraints:
                      BoxConstraints(minWidth: 28, minHeight: 28),
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          OutlinedButton.icon(
            onPressed: _pickSchedDate,
            icon: const Icon(Icons.event, size: 14),
            label: Text(
              _schedDate.isEmpty ? 'Pick date' : _schedDate,
              style: const TextStyle(fontSize: 12),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(0, 34),
              visualDensity: VisualDensity.compact,
            ),
          ),
          if (_schedDate.isNotEmpty)
            IconButton(
              onPressed: () => setState(() => _schedDate = ''),
              icon: const Icon(Icons.clear, size: 16),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: 'Clear date',
            ),
        ],
      );

  Future<void> _pickSchedDate() async {
    final now = DateTime.now();
    final initial = _schedDate.isNotEmpty
        ? DateTime.tryParse(_schedDate) ?? now
        : now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null) return;
    final iso =
        '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    setState(() => _schedDate = iso);
  }

  Widget _scheduleList(
    List<Map<String, dynamic>> items,
    Map<String, Map<String, dynamic>> clByScheduleId,
  ) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          _schedDate.isNotEmpty
              ? 'No schedules on this date.'
              : _schedQuery.isNotEmpty
                  ? 'No schedules match your search.'
                  : 'No schedules available.',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: SingleChildScrollView(
        child: Column(
          children: items.map((s) {
            final id = s['id'] as String;
            final checked = widget.value.scheduleIds.contains(id);
            final cl = clByScheduleId[id];
            final progress = cl != null
                ? '${cl['completed_items'] ?? 0}/${cl['total_items'] ?? 0} checklist'
                : null;
            final timeRange =
                (s['start_time'] != null && s['end_time'] != null)
                    ? '${s['start_time']}–${s['end_time']}'
                    : null;
            final role = s['work_role_name'] ??
                s['work_role_name_snapshot'] ??
                s['position_snapshot'];
            final label = _joinDot([
              s['work_date'] as String?,
              role as String?,
              timeRange,
              s['user_name'] as String?,
              progress,
            ]);
            return InkWell(
              onTap: () => _toggleSchedule(id, cl),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: Checkbox(
                        value: checked,
                        onChanged: (_) => _toggleSchedule(id, cl),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.text),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _toggleSchedule(String sid, Map<String, dynamic>? checklist) {
    final selected = widget.value.scheduleIds.contains(sid);
    final nextScheduleIds = _toggle(widget.value.scheduleIds, sid);
    var nextChecklistIds = widget.value.checklistInstanceIds;
    if (checklist != null && checklist['id'] is String) {
      final cid = checklist['id'] as String;
      if (selected) {
        nextChecklistIds =
            nextChecklistIds.where((x) => x != cid).toList();
      } else if (!nextChecklistIds.contains(cid)) {
        nextChecklistIds = [...nextChecklistIds, cid];
      }
    }
    widget.onChanged(widget.value.copyWith(
      scheduleIds: nextScheduleIds,
      checklistInstanceIds: nextChecklistIds,
    ));
  }

  Widget _roleChipsRow(List<Map<String, dynamic>> sortedUsers) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _roleChips.map((chip) {
        final active = widget.value.relatedRoles.contains(chip.key);
        final count = sortedUsers.where(chip.match).length;
        return FilterChip(
          label: Text(
            count > 0 ? '${chip.label} ·$count' : chip.label,
            style: const TextStyle(fontSize: 12),
          ),
          selected: active,
          onSelected:
              count == 0 ? null : (_) => _toggleRoleChip(chip, sortedUsers),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
      }).toList(),
    );
  }

  void _toggleRoleChip(_RoleChip chip, List<Map<String, dynamic>> sortedUsers) {
    final has = widget.value.relatedRoles.contains(chip.key);
    final matchedIds = sortedUsers
        .where(chip.match)
        .map((u) => u['id'] as String)
        .toList();
    List<String> nextRoles;
    List<String> nextUserIds;
    if (has) {
      nextRoles =
          widget.value.relatedRoles.where((x) => x != chip.key).toList();
      bool stillCovered(String uid) {
        for (final r in nextRoles) {
          final other = _roleChips.firstWhere(
            (c) => c.key == r,
            orElse: () => const _RoleChip(
                key: '', label: '', match: _matchAll),
          );
          if (other.key.isEmpty) continue;
          final u = sortedUsers
              .firstWhere((x) => x['id'] == uid, orElse: () => {});
          if (u.isNotEmpty && other.match(u)) return true;
        }
        return false;
      }
      nextUserIds = widget.value.relatedUserIds
          .where((uid) => !matchedIds.contains(uid) || stillCovered(uid))
          .toList();
    } else {
      nextRoles = [...widget.value.relatedRoles, chip.key];
      nextUserIds = [...widget.value.relatedUserIds];
      for (final id in matchedIds) {
        if (!nextUserIds.contains(id)) nextUserIds.add(id);
      }
    }
    widget.onChanged(widget.value.copyWith(
      relatedRoles: nextRoles,
      relatedUserIds: nextUserIds,
    ));
  }

  Widget _peopleSearch() => SizedBox(
        height: 34,
        child: TextField(
          onChanged: (v) => setState(() => _peopleQuery = v),
          style: const TextStyle(fontSize: 12),
          decoration: const InputDecoration(
            hintText: 'Search name or role',
            hintStyle: TextStyle(fontSize: 12),
            prefixIcon: Icon(Icons.search, size: 16),
            prefixIconConstraints:
                BoxConstraints(minWidth: 28, minHeight: 28),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            border: OutlineInputBorder(),
          ),
        ),
      );

  Widget _peopleList(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Text(
          'No staff for this store.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: SingleChildScrollView(
        child: Column(
          children: items.map((u) {
            final id = u['id'] as String;
            final checked = widget.value.relatedUserIds.contains(id);
            final name = (u['full_name'] as String?) ??
                (u['username'] as String? ?? '');
            final role = u['role_name'];
            final label = _joinDot([name, role as String?]);
            return InkWell(
              onTap: () => widget.onChanged(widget.value.copyWith(
                relatedUserIds:
                    _toggle(widget.value.relatedUserIds, id),
              )),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: Checkbox(
                        value: checked,
                        onChanged: (_) => widget.onChanged(
                            widget.value.copyWith(
                          relatedUserIds:
                              _toggle(widget.value.relatedUserIds, id),
                        )),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.text),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  List<String> _toggle(List<String> current, String id) {
    final out = [...current];
    if (out.contains(id)) {
      out.remove(id);
    } else {
      out.add(id);
    }
    return out;
  }

  String _joinDot(List<String?> parts) =>
      parts.where((p) => p != null && p.trim().isNotEmpty).join(' · ');
}
