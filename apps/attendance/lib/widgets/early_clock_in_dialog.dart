/// EarlyClockInDialog — 예정 시작보다 이른 출근을 강행할 때의 사유 입력.
///
/// 왜 있는가: 매니저/SV 가 현장에 없을 때 "좀 더 일찍 와달라"로 온 직원이
/// 출근을 못 찍는 상황이 실제로 있었다. 서버는 이제 차단 대신 사유를 요구하고
/// (code=early_clock_in_reason_required), 이 화면이 그 사유를 받는다.
///
/// 형태는 BreakReasonDialog / EarlyClockOutDialog 와 동일한 preset + Other 패턴 —
/// 키오스크는 터치 환경이라 자유 입력만 두면 실질적으로 못 쓴다.
///
/// "예정보다 얼마나 이른지" 를 헤더에 크게 보여준다. 서버가 시간 상한을 두지
/// 않으므로(몇 시간 전에 부를지 예측 불가), 다음날 shift 오선택 같은 오조작을
/// 사용자가 알아채는 장치가 이 문구뿐이다.
///
/// 2026-08-13(D8): "Asked to come in early" 는 **누가 불렀는지**까지 받는다.
/// 매장 Manager/SV 목록에서 고르거나 "Someone else" 로 직접 적는다 —
/// 직접 입력은 목록이 비었을 때의 fallback 이 아니라 **상시 노출**이다.
/// 명단 밖 사람(다른 매장 매니저, 본사)이 부른 경우가 실제로 있어서 목록만으론 막힌다.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:htm_core/htm_core.dart';

import '../l10n/app_localizations.dart';
import '../models/early_clock_in_reason.dart';
import '../models/store_manager_option.dart';
import '../utils/early_clock_in_logic.dart';

/// EarlyClockInReason → l10n label.
String localizedEarlyClockInLabel(AppL10n t, EarlyClockInReason r) => switch (r) {
      EarlyClockInReason.askedToComeEarly => t.pfEarlyInAsked,
      EarlyClockInReason.coveringForSomeone => t.pfEarlyInCovering,
      EarlyClockInReason.storeNeedsHelp => t.pfEarlyInStoreHelp,
      EarlyClockInReason.other => t.pfEarlyInOther,
    };

class EarlyClockInDialog extends StatefulWidget {
  final String userName;

  /// 예정 시작보다 몇 분 이른지 (서버 detail.minutes_early).
  final int minutesEarly;

  /// 매장 Manager/SV 목록 (계약 §4). 사유 단계에 들어갈 때마다 새로 받아온다.
  final List<StoreManagerOption> managers;

  /// 목록을 아직 받는 중인가.
  final bool managersLoading;

  /// 목록 조회가 실패했는가 — 실패해도 다이얼로그는 열리고 "Someone else" 는 남는다.
  final bool managersFailed;

  /// reason 문자열과 요청자 user_id(있으면)를 함께 넘긴다 (D9 이중 기록).
  final void Function(String reason, String? requestedBy) onSubmit;
  final VoidCallback onCancel;

  /// 서버가 거부했을 때 표시할 inline 에러 (raw 메시지 대신 화면 안에서 안내).
  final String? errorText;

  const EarlyClockInDialog({
    super.key,
    required this.userName,
    required this.minutesEarly,
    required this.onSubmit,
    required this.onCancel,
    this.managers = const [],
    this.managersLoading = false,
    this.managersFailed = false,
    this.errorText,
  });

  @override
  State<EarlyClockInDialog> createState() => _EarlyClockInDialogState();
}

class _EarlyClockInDialogState extends State<EarlyClockInDialog> {
  EarlyClockInReason? _reason;
  final _detailController = TextEditingController();

  /// 목록에서 고른 사람. "Someone else" 를 고르면 null 이 되고 [_manualSelected] 가 켜진다.
  StoreManagerOption? _pickedManager;
  bool _manualSelected = false;
  final _manualNameController = TextEditingController();

  @override
  void dispose() {
    _detailController.dispose();
    _manualNameController.dispose();
    super.dispose();
  }

  /// 지금 화면 상태가 뜻하는 요청자. 아무것도 안 골랐으면 null.
  EarlyRequester? get _requester {
    if (_manualSelected) {
      final name = _manualNameController.text.trim();
      return name.isEmpty ? null : EarlyRequester(name: name);
    }
    final picked = _pickedManager;
    if (picked == null) return null;
    return EarlyRequester(name: picked.fullName, userId: picked.userId);
  }

  bool get _canSubmit => canSubmitEarlyClockIn(
        _reason,
        _detailController.text,
        requester: _requester,
      );

  void _submit() {
    if (!_canSubmit) return;
    final reason = _reason!;
    final requester = _requester;
    widget.onSubmit(
      earlyClockInReasonToSubmit(
        reason,
        _detailController.text,
        requester: requester,
      ),
      earlyClockInRequestedBy(reason, requester: requester),
    );
  }

  void _selectReason(EarlyClockInReason r) {
    setState(() {
      _reason = r;
      // 다른 사유로 옮기면 요청자 선택은 의미가 없다 — 남겨두면 되돌아왔을 때
      // 예전 선택이 유령처럼 붙어 나간다.
      if (r != EarlyClockInReason.askedToComeEarly) {
        _pickedManager = null;
        _manualSelected = false;
        _manualNameController.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Material(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _EarlyHeader(minutesEarly: widget.minutesEarly),
                  const SizedBox(height: 20),
                  Text(
                    t.pfEarlyInTitle(widget.userName),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t.pfEarlyInBody,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...EarlyClockInReason.values.map(_buildReasonOption),
                  if (_reason == EarlyClockInReason.askedToComeEarly)
                    _buildRequesterSection(t),
                  if (_reason == EarlyClockInReason.other) ...[
                    const SizedBox(height: 8),
                    _DetailField(
                      controller: _detailController,
                      hint: t.pfEarlyInOtherHint,
                      maxLength: 300,
                      maxLines: 3,
                      onChanged: () => setState(() {}),
                    ),
                  ],
                  if (widget.errorText != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.dangerBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.errorText!,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: OutlinedButton(
                            onPressed: widget.onCancel,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                              side: const BorderSide(
                                color: AppColors.border,
                                width: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              t.pfEarlyInCancel,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _canSubmit ? _submit : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.warning,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: AppColors.warning
                                  .withValues(alpha: 0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              t.pfEarlyInSubmit,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// "누가 불렀나" — 목록 + 상시 "Someone else".
  Widget _buildRequesterSection(AppL10n t) {
    final children = <Widget>[
      const SizedBox(height: 12),
      Text(
        t.pfEarlyInWhoAsked,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: AppColors.text,
        ),
      ),
      const SizedBox(height: 8),
    ];

    if (widget.managersLoading) {
      children.add(_hintLine(t.pfEarlyInManagersLoading));
    } else if (widget.managersFailed) {
      // 실패해도 진행은 막지 않는다 — 직접 입력으로 계속 간다.
      children.add(_hintLine(t.pfEarlyInManagersFailed));
    } else if (widget.managers.isEmpty) {
      children.add(_hintLine(t.pfEarlyInManagersEmpty));
    }

    for (final m in widget.managers) {
      children.add(
        _OptionTile(
          selected: !_manualSelected && _pickedManager?.userId == m.userId,
          // 동명이인 구분을 위해 role 을 함께 보여준다 (계약 §4).
          label: m.fullName,
          sub: m.roleName,
          onTap: () => setState(() {
            _pickedManager = m;
            _manualSelected = false;
          }),
        ),
      );
    }

    children.add(
      _OptionTile(
        selected: _manualSelected,
        label: t.pfEarlyInManual,
        onTap: () => setState(() {
          _manualSelected = true;
          _pickedManager = null;
        }),
      ),
    );

    if (_manualSelected) {
      children.add(
        _DetailField(
          controller: _manualNameController,
          hint: t.pfEarlyInManualHint,
          maxLength: kEarlyRequesterNameMaxLength,
          maxLines: 1,
          onChanged: () => setState(() {}),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Widget _hintLine(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      );

  Widget _buildReasonOption(EarlyClockInReason r) {
    return _OptionTile(
      selected: _reason == r,
      label: localizedEarlyClockInLabel(AppL10n.of(context), r),
      onTap: () => _selectReason(r),
    );
  }
}

/// 라디오형 선택 타일 — 사유·요청자 양쪽에서 같은 모양을 쓴다.
class _OptionTile extends StatelessWidget {
  final bool selected;
  final String label;
  final String? sub;
  final VoidCallback onTap;

  const _OptionTile({
    required this.selected,
    required this.label,
    required this.onTap,
    this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.accentBg : AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.border,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: selected ? AppColors.accent : AppColors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? AppColors.accent : AppColors.textMuted,
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: selected
                    ? Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: selected ? AppColors.accent : AppColors.text,
                      ),
                    ),
                    if (sub != null && sub!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        sub!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EarlyHeader extends StatelessWidget {
  final int minutesEarly;
  const _EarlyHeader({required this.minutesEarly});

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.schedule_rounded,
              size: 26,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.pfEarlyInHeader,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  t.pfEarlyInEarlyBy(formatEarlyBy(minutesEarly)),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLength;
  final int maxLines;
  final VoidCallback onChanged;

  const _DetailField({
    required this.controller,
    required this.hint,
    required this.maxLength,
    required this.maxLines,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      inputFormatters: [LengthLimitingTextInputFormatter(maxLength)],
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.accent, width: 2),
        ),
      ),
    );
  }
}
