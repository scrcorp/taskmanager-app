/// Issue report 알림 수신자 추가 시트.
///
/// 자동 수신자(그 매장에 배정된 GM 이상 전원, 해제 불가)는
/// `GET /app/my/reports/issue-recipients` 가 준다. 이 시트는 거기에 **없는 사람을
/// 콕 집어 추가**하는 용도이며, 선택된 사람은 payload.extra_viewers.user_ids 로 나간다
/// (조회권 + 이메일 알림).
///
/// 사람 목록은 이미 있는 매장 옵션 API(`/app/my/stores/{id}/link-options` 의 users)를
/// 재사용한다 — LinkPicker 와 같은 출처.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:htm_core/htm_core.dart';

import '../../l10n/app_localizations.dart';
import '../../services/issue_report_service.dart';
import '../../utils/api_error_display.dart';

/// 수신자로 추가된 사람 (extra_viewers.user_ids 로 전송).
class IssuePerson {
  final String id;
  final String name;
  final String roleLabel;
  final int rolePriority;

  const IssuePerson({
    required this.id,
    required this.name,
    required this.roleLabel,
    this.rolePriority = 0,
  });

  factory IssuePerson.fromLinkOption(Map<String, dynamic> u) => IssuePerson(
        id: (u['id'] as String?) ?? '',
        name: (u['full_name'] as String?) ??
            (u['username'] as String?) ??
            '',
        roleLabel: (u['role_name'] as String?) ?? '',
        rolePriority: (u['role_priority'] as int?) ?? 0,
      );
}

/// 이미 목록에 있는 [excludeIds] 를 제외한 매장 인원을 골라 돌려준다.
/// 취소하면 null.
Future<List<IssuePerson>?> showIssueRecipientPicker({
  required BuildContext context,
  required WidgetRef ref,
  required String storeId,
  required Set<String> excludeIds,
}) {
  return showModalBottomSheet<List<IssuePerson>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _RecipientPickerSheet(
      storeId: storeId,
      excludeIds: excludeIds,
    ),
  );
}

class _RecipientPickerSheet extends ConsumerStatefulWidget {
  final String storeId;
  final Set<String> excludeIds;

  const _RecipientPickerSheet({
    required this.storeId,
    required this.excludeIds,
  });

  @override
  ConsumerState<_RecipientPickerSheet> createState() =>
      _RecipientPickerSheetState();
}

class _RecipientPickerSheetState extends ConsumerState<_RecipientPickerSheet> {
  List<IssuePerson> _people = [];
  final Set<String> _selected = {};
  String _query = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ref
          .read(issueReportServiceProvider)
          .getLinkOptions(widget.storeId);
      final users = ((data['users'] as List?) ?? const [])
          .whereType<Map>()
          .map((u) => IssuePerson.fromLinkOption(u.cast<String, dynamic>()))
          .where((p) => p.id.isNotEmpty && !widget.excludeIds.contains(p.id))
          .toList()
        ..sort((a, b) {
          final byRole = a.rolePriority.compareTo(b.rolePriority);
          return byRole != 0 ? byRole : a.name.compareTo(b.name);
        });
      if (!mounted) return;
      setState(() {
        _people = users;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final t = AppL10n.of(context);
      setState(() {
        _loading = false;
        _error = apiErrorTextOf(
          t,
          e,
          fallback: t.issueRecipientsPickerLoadFailed,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final q = _query.trim().toLowerCase();
    final visible = q.isEmpty
        ? _people
        : _people
            .where((p) =>
                p.name.toLowerCase().contains(q) ||
                p.roleLabel.toLowerCase().contains(q))
            .toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.issueRecipientsPickerTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(t.actionCancel),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: t.issueRecipientsSearchHint,
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 18),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.danger,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: _load,
                                  child: Text(t.actionRetry),
                                ),
                              ],
                            ),
                          )
                        : visible.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Text(
                                    t.issueRecipientsNoOneToAdd,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount: visible.length,
                                itemBuilder: (_, i) {
                                  final p = visible[i];
                                  return CheckboxListTile(
                                    dense: true,
                                    value: _selected.contains(p.id),
                                    title: Text(
                                      p.name,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    subtitle: p.roleLabel.isEmpty
                                        ? null
                                        : Text(
                                            roleDisplayLabel(t, p.roleLabel),
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                    onChanged: (v) => setState(() {
                                      if (v == true) {
                                        _selected.add(p.id);
                                      } else {
                                        _selected.remove(p.id);
                                      }
                                    }),
                                  );
                                },
                              ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: ElevatedButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => Navigator.of(context).pop(
                            _people
                                .where((p) => _selected.contains(p.id))
                                .toList(),
                          ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(t.actionConfirm),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// DB role name 원문 → 화면 라벨. 커스텀 role 은 DB 값을 그대로 보여준다
/// (조직이 직접 지은 이름이라 번역 대상이 아니다).
String roleDisplayLabel(AppL10n t, String roleName) {
  switch (roleName) {
    case 'owner':
      return t.roleOwner;
    case 'general_manager':
      return t.roleGeneralManager;
    case 'supervisor':
      return t.roleSupervisor;
    case 'staff':
      return t.roleStaff;
    default:
      return roleName;
  }
}
