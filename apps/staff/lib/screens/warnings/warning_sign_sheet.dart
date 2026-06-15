/// 경고 서명 바텀시트.
///
/// 모드 토글: "Draw new" (새 서명 그리기) vs "Use saved signature" (저장된 서명 재사용).
/// - Draw new: SignaturePad (벡터 캡처) → exportStrokes() 로 정규화 stroke 추출.
///   "Save as my default signature" 체크 시 save_as_default=true 로 제출.
/// - Use saved: 저장된 서명 프리뷰를 그대로 사용 (method='saved').
///
/// Confirm 시 SignResult 를 반환한다. 실제 /sign 호출은 호출 측(상세 화면)이 수행.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:htm_core/htm_core.dart';

import '../../l10n/app_localizations.dart';
import '../../models/warning.dart';
import '../../providers/auth_provider.dart';
import '../tips/signature_pad.dart';
import '../../widgets/signature_strokes_view.dart';

/// 서명 시트 결과 — 정규화 stroke + method + 기본 저장 여부.
class SignResult {
  final SignatureStrokes signature;

  /// 'drawn' (새로 그림) 또는 'saved' (저장된 서명 재사용).
  final String method;
  final bool saveAsDefault;

  const SignResult({
    required this.signature,
    required this.method,
    required this.saveAsDefault,
  });
}

/// 서명 시트를 띄우고 결과(SignResult)를 반환. 취소 시 null.
Future<SignResult?> showWarningSignSheet(
  BuildContext context, {
  SignatureStrokes? savedSignature,
}) {
  return showModalBottomSheet<SignResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _WarningSignSheet(savedSignature: savedSignature),
  );
}

class _WarningSignSheet extends ConsumerStatefulWidget {
  final SignatureStrokes? savedSignature;

  const _WarningSignSheet({this.savedSignature});

  @override
  ConsumerState<_WarningSignSheet> createState() => _WarningSignSheetState();
}

enum _Mode { draw, saved }

class _WarningSignSheetState extends ConsumerState<_WarningSignSheet> {
  final _padKey = GlobalKey<SignaturePadState>();
  late _Mode _mode;
  bool _saveAsDefault = false;
  // SignaturePad 의 stroke 상태 변화에 따라 Confirm 활성화 갱신용.
  bool _hasInk = false;

  @override
  void initState() {
    super.initState();
    // 저장된 서명이 있으면 기본으로 "Use saved" 선택.
    _mode = widget.savedSignature != null ? _Mode.saved : _Mode.draw;
  }

  bool get _canConfirm {
    if (_mode == _Mode.saved) return widget.savedSignature != null;
    return _hasInk;
  }

  void _refreshInk() {
    final ink = _padKey.currentState?.hasInk ?? false;
    if (ink != _hasInk) setState(() => _hasInk = ink);
  }

  void _confirm() {
    final t = AppL10n.of(context);
    if (_mode == _Mode.saved) {
      final saved = widget.savedSignature;
      if (saved == null) return;
      Navigator.pop(
        context,
        SignResult(signature: saved, method: 'saved', saveAsDefault: false),
      );
      return;
    }
    final strokes = _padKey.currentState?.exportStrokes();
    if (strokes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.warningSignDrawHint)),
      );
      return;
    }
    Navigator.pop(
      context,
      SignResult(
        signature: strokes,
        method: 'drawn',
        saveAsDefault: _saveAsDefault,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final user = ref.watch(authProvider).user;
    final signerName = user?.fullName ?? t.commonStaff;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // grabber
                Center(
                  child: Container(
                    width: 40, height: 5,
                    decoration: BoxDecoration(
                        color: AppColors.border, borderRadius: BorderRadius.circular(3)),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(t.warningSignSheetTitle,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text)),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 22, color: AppColors.textMuted),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(t.warningSignSheetSubtitle,
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                const SizedBox(height: 14),

                // mode toggle
                Row(
                  children: [
                    Expanded(
                      child: _ModeButton(
                        label: t.warningSignDrawNew,
                        selected: _mode == _Mode.draw,
                        onTap: () => setState(() => _mode = _Mode.draw),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ModeButton(
                        label: t.warningSignUseSaved,
                        selected: _mode == _Mode.saved,
                        enabled: widget.savedSignature != null,
                        onTap: widget.savedSignature != null
                            ? () => setState(() => _mode = _Mode.saved)
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // pad / saved preview
                if (_mode == _Mode.draw)
                  Listener(
                    onPointerUp: (_) => _refreshInk(),
                    child: SignaturePad(key: _padKey, height: 160, onCaptured: (_) {}),
                  )
                else
                  Container(
                    height: 160,
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: widget.savedSignature != null
                        ? SignatureStrokesView(
                            signature: widget.savedSignature!, strokeWidth: 2.6)
                        : Center(
                            child: Text(t.warningSignNoSaved,
                                style: const TextStyle(
                                    fontSize: 13, color: AppColors.textMuted)),
                          ),
                  ),
                const SizedBox(height: 8),

                // signing-as + clear
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.warningSignSigningAs(signerName),
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_mode == _Mode.draw)
                      TextButton(
                        onPressed: _hasInk
                            ? () {
                                _padKey.currentState?.clear();
                                _refreshInk();
                              }
                            : null,
                        style: TextButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(t.warningSignClear,
                            style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.accent)),
                      ),
                  ],
                ),

                // save-as-default (draw mode only)
                if (_mode == _Mode.draw)
                  InkWell(
                    onTap: () => setState(() => _saveAsDefault = !_saveAsDefault),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Icon(
                            _saveAsDefault
                                ? Icons.check_box_rounded
                                : Icons.check_box_outline_blank_rounded,
                            size: 20,
                            color: _saveAsDefault ? AppColors.accent : AppColors.textMuted,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(t.warningSignSaveAsDefault,
                                style: const TextStyle(
                                    fontSize: 13, color: AppColors.textSecondary)),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),

                // actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(t.actionCancel,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _canConfirm ? _confirm : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          disabledBackgroundColor: AppColors.textMuted,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(t.warningSignConfirm,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  const _ModeButton({
    required this.label,
    required this.selected,
    this.enabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color fg = !enabled
        ? AppColors.textMuted
        : selected
            ? AppColors.accent
            : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.accentBg : AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? AppColors.accent : AppColors.border),
          ),
          child: Text(label,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
        ),
      ),
    );
  }
}
