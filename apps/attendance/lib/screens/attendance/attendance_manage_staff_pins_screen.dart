/// 관리자 모드 — 직원 clock-in PIN 조회/변경.
///
/// 가입 시 PIN 이 랜덤 배정이라 직원이 확인 못 한 채 현장에 나오는 경우를
/// 그 자리에서 해결하기 위한 화면. 콘솔을 열 필요가 없어야 한다.
///
/// 노출 정책: 목록은 항상 마스킹. Reveal 을 누른 행만 5초간 평문으로 열리고
/// 자동으로 다시 마스킹된다. 키오스크는 매장 공용 화면이라, 매니저가 목록을
/// 열어둔 채 자리를 비우면 전 직원 PIN 이 그대로 노출되기 때문이다.
/// 평문은 reveal API 호출로만 얻고(목록 응답엔 없음), 그 호출마다 서버에
/// 감사 로그가 남는다.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:htm_core/htm_core.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/attendance_manage_provider.dart';
import '../../services/attendance_device_service.dart';
import '../../widgets/pin_numpad.dart';

/// 평문 PIN 이 열려 있는 시간. 짧게 잡아야 자리 비움 노출을 줄인다.
const _revealSeconds = 5;

class AttendanceManageStaffPinsScreen extends ConsumerStatefulWidget {
  /// 이 화면에서의 터치를 manage 세션 활동으로 상위에 알린다.
  ///
  /// manage 홈의 무반응 타이머는 홈 body 의 Listener 로만 갱신되는데, 이 화면은
  /// 새 라우트로 올라가 터치가 그 Listener 를 거치지 않는다. 연결하지 않으면
  /// **PIN 을 찾는 도중에 세션이 끊긴다.**
  final VoidCallback? onActivity;

  const AttendanceManageStaffPinsScreen({super.key, this.onActivity});

  @override
  ConsumerState<AttendanceManageStaffPinsScreen> createState() =>
      _AttendanceManageStaffPinsScreenState();
}

class _StaffPinRow {
  final String userId;
  final String fullName;
  final String? employeeNo;
  final String? roleName;
  final bool hasPin;
  final bool worksToday;

  const _StaffPinRow({
    required this.userId,
    required this.fullName,
    this.employeeNo,
    this.roleName,
    required this.hasPin,
    required this.worksToday,
  });

  factory _StaffPinRow.fromJson(Map<String, dynamic> json) => _StaffPinRow(
    userId: json['user_id']?.toString() ?? '',
    fullName: json['full_name']?.toString() ?? '',
    employeeNo: json['employee_no']?.toString(),
    roleName: json['role_name']?.toString(),
    hasPin: json['has_pin'] == true,
    worksToday: json['works_today'] == true,
  );
}

class _AttendanceManageStaffPinsScreenState
    extends ConsumerState<AttendanceManageStaffPinsScreen> {
  bool _loading = true;
  String? _error;
  List<_StaffPinRow> _rows = const [];

  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  /// 지금 평문이 열려 있는 행. 한 번에 하나만 — 여러 개를 동시에 열어두면
  /// 마스킹 정책 자체가 무의미해진다.
  String? _revealedUserId;
  String? _revealedPin;
  int _revealLeft = 0;
  Timer? _revealTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _revealTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  AttendanceDeviceService get _service =>
      ref.read(attendanceDeviceServiceProvider);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await _service.manageListStaffPins(
        query: _searchController.text,
      );
      if (!mounted) return;
      setState(() {
        _rows = raw.map(_StaffPinRow.fromJson).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _messageFor(e, AppL10n.of(context).mgPinErrorLoad);
      });
    }
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), _load);
  }

  /// 서버 에러 → 사용자가 다음에 뭘 해야 하는지 알 수 있는 문구.
  /// raw detail 을 그대로 띄우지 않는다.
  String _messageFor(Object e, String fallback) {
    final t = AppL10n.of(context);
    final status = _statusOf(e);
    switch (status) {
      case 403:
        return t.mgPinErrorForbidden;
      case 404:
        return t.mgPinErrorNotFound;
      case 409:
        return _conflictMessageFor(e, t);
      default:
        return fallback;
    }
  }

  /// 409 detail 이 구조화된 pin_conflict dict 면 사유별 문구 (2-C).
  /// 서버는 사유 코드만 보내고 타인의 PIN/이름은 싣지 않는다 — 여기서도
  /// "다른 매장 사용중 / 앞자리 겹침" 수준의 사유만 보여준다.
  String _conflictMessageFor(Object e, AppL10n t) {
    final detail = _detailOf(e);
    if (detail is Map && detail['code'] == 'pin_conflict') {
      if (detail['reason'] == 'prefix') return t.mgPinErrorConflictPrefix;
      if (detail['other_store'] == true) {
        return t.mgPinErrorConflictOtherStore;
      }
    }
    // dict 가 아니거나(구버전 서버) exact + 같은 매장이면 기존 문구.
    return t.mgPinErrorConflict;
  }

  Object? _detailOf(Object e) {
    try {
      final dynamic err = e;
      final data = err.response?.data;
      if (data is Map) return data['detail'];
    } catch (_) {
      // response/data 형태가 아니면 무시
    }
    return null;
  }

  int? _statusOf(Object e) {
    try {
      final dynamic err = e;
      return err.response?.statusCode as int?;
    } catch (_) {
      return null;
    }
  }

  void _toast(String message, {bool danger = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: danger ? AppColors.danger : AppColors.text,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Reveal ──────────────────────────────────────────────

  void _clearReveal() {
    _revealTimer?.cancel();
    _revealTimer = null;
    if (!mounted) return;
    setState(() {
      _revealedUserId = null;
      _revealedPin = null;
      _revealLeft = 0;
    });
  }

  Future<void> _reveal(_StaffPinRow row) async {
    // 같은 행을 다시 누르면 즉시 닫기 — 노출을 스스로 끊을 수단.
    if (_revealedUserId == row.userId) {
      _clearReveal();
      return;
    }
    _clearReveal();
    try {
      final pin = await _service.manageRevealStaffPin(row.userId);
      if (!mounted) return;
      _startRevealCountdown(row.userId, pin);
    } catch (e) {
      _toast(
        _messageFor(e, AppL10n.of(context).mgPinErrorGeneric),
        danger: true,
      );
    }
  }

  void _startRevealCountdown(String userId, String? pin) {
    setState(() {
      _revealedUserId = userId;
      _revealedPin = pin;
      _revealLeft = _revealSeconds;
    });
    _revealTimer?.cancel();
    _revealTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _revealLeft -= 1);
      if (_revealLeft <= 0) {
        timer.cancel();
        _clearReveal();
      }
    });
  }

  // ── 변경 ────────────────────────────────────────────────

  Future<void> _openEdit(_StaffPinRow row) async {
    _clearReveal();
    final t = AppL10n.of(context);
    final newPin = await showDialog<String>(
      context: context,
      builder: (ctx) => _SetPinDialog(name: row.fullName),
    );
    if (newPin == null || !mounted) return;

    try {
      final saved = await _service.manageUpdateStaffPin(
        userId: row.userId,
        pin: newPin,
      );
      if (!mounted) return;
      _toast(t.mgPinSaved);
      _startRevealCountdown(row.userId, saved);
      await _load();
    } catch (e) {
      if (!mounted) return;
      // 409 는 detail dict(code=pin_conflict) 의 사유(다른 매장/앞자리 겹침)별로
      // 문구를 나눠 보여준다 — 매니저가 왜 막혔는지 알아야 다음 번호를 고른다.
      _toast(_messageFor(e, t.mgPinErrorGeneric), danger: true);
    }
  }

  Future<void> _regenerate(_StaffPinRow row) async {
    _clearReveal();
    final t = AppL10n.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.mgPinRegenerateConfirmTitle),
        content: Text(t.mgPinRegenerateConfirmBody(row.fullName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t.mgPinCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.mgPinRegenerateConfirm),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      final pin = await _service.manageRegenerateStaffPin(row.userId);
      if (!mounted) return;
      _toast(t.mgPinSaved);
      // 새 PIN 은 바로 알려줘야 하므로 reveal 상태로 띄운다.
      _startRevealCountdown(row.userId, pin);
      await _load();
    } catch (e) {
      if (!mounted) return;
      _toast(_messageFor(e, t.mgPinErrorGeneric), danger: true);
    }
  }

  // ── build ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final session = ref.watch(attendanceManageSessionProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        title: Text(
          t.mgPinTitle,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => widget.onActivity?.call(),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: t.mgPinSearchHint,
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: AppColors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ),
              Expanded(child: _buildBody(t, session.canUpdatePins)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(AppL10n t, bool canUpdate) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.danger),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: Text(t.pfErrorOk)),
          ],
        ),
      );
    }
    if (_rows.isEmpty) {
      final query = _searchController.text.trim();
      return Center(
        child: Text(
          query.isEmpty ? t.mgPinEmpty : t.mgPinNoSearchResult(query),
          style: const TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: _rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final row = _rows[i];
          return _StaffPinTile(
            row: row,
            revealedPin: _revealedUserId == row.userId ? _revealedPin : null,
            revealSecondsLeft: _revealedUserId == row.userId
                ? _revealLeft
                : null,
            canUpdate: canUpdate,
            onReveal: () => _reveal(row),
            onEdit: () => _openEdit(row),
            onRegenerate: () => _regenerate(row),
          );
        },
      ),
    );
  }
}

// ── 행 ────────────────────────────────────────────────────

class _StaffPinTile extends StatelessWidget {
  final _StaffPinRow row;
  final String? revealedPin;
  final int? revealSecondsLeft;
  final bool canUpdate;
  final VoidCallback onReveal;
  final VoidCallback onEdit;
  final VoidCallback onRegenerate;

  const _StaffPinTile({
    required this.row,
    required this.revealedPin,
    required this.revealSecondsLeft,
    required this.canUpdate,
    required this.onReveal,
    required this.onEdit,
    required this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final revealed = revealedPin != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        row.fullName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    if (row.worksToday) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.successBg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          t.mgPinWorksToday,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.success,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    row.employeeNo,
                    row.roleName,
                  ].where((e) => e != null && e.isNotEmpty).join(' · '),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      revealed
                          ? revealedPin!
                          : (row.hasPin ? '••••••' : t.mgPinNoPin),
                      style: TextStyle(
                        fontSize: revealed ? 20 : 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: revealed ? 3 : 2,
                        color: revealed
                            ? AppColors.accent
                            : AppColors.textMuted,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (revealed && revealSecondsLeft != null) ...[
                      const SizedBox(width: 10),
                      Text(
                        t.mgPinHideIn(revealSecondsLeft!),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (row.hasPin)
            IconButton(
              tooltip: t.mgPinReveal,
              onPressed: onReveal,
              icon: Icon(
                revealed
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: AppColors.accent,
              ),
            ),
          if (canUpdate)
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert_rounded,
                color: AppColors.textSecondary,
              ),
              onSelected: (value) {
                if (value == 'edit') onEdit();
                if (value == 'regen') onRegenerate();
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(value: 'edit', child: Text(t.mgPinEdit)),
                PopupMenuItem(value: 'regen', child: Text(t.mgPinRegenerate)),
              ],
            ),
        ],
      ),
    );
  }
}

// ── PIN 입력 다이얼로그 ────────────────────────────────────

class _SetPinDialog extends StatelessWidget {
  final String name;

  const _SetPinDialog({required this.name});

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final size = MediaQuery.of(context).size;

    // PinNumpad 는 LayoutBuilder 로 가용 높이에 맞춰 키 크기를 계산한다.
    // 스크롤로 감싸면 높이가 무한대가 되어 키가 최대 크기로 부풀고 저장 버튼이
    // 화면 밖으로 밀려난다 — 그래서 스크롤 대신 **높이를 확정해서** 넘긴다.
    final dialogHeight = size.height * 0.92;

    return Dialog(
      backgroundColor: AppColors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 520,
        height: dialogHeight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t.mgPinSetTitle(name),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                t.mgPinSetHelp,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              // 4~6자리. auto-submit 이 아니라 명시적 확인 버튼이라
              // 길이가 섞여 있어도 오조작으로 짧게 제출되지 않는다.
              Expanded(
                child: PinNumpad(
                  minLength: 4,
                  maxLength: 6,
                  submitLabel: t.mgPinSave,
                  hintText: t.mgPinSaveHint,
                  onSubmit: (pin) => Navigator.of(context).pop(pin),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(t.mgPinCancel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
