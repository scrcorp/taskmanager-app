/// 경고(Warning) 상세 화면.
///
/// 열면 getDetail() 호출 → 서버가 자동으로 acknowledge 처리한다 (별도 버튼 없음).
/// 명시적 액션은 Sign(서명) 하나뿐.
/// 우상단/본문에 "View official document" → gov-form PDF 뷰.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:htm_core/htm_core.dart';

import '../../l10n/app_localizations.dart';
import '../../models/warning.dart';
import '../../providers/warnings_provider.dart';
import '../../services/warning_service.dart';
import '../../utils/date_utils.dart';
import '../../widgets/app_header.dart';
import '../../widgets/signature_strokes_view.dart';
import 'warning_pdf_view.dart';
import 'warning_sign_sheet.dart';

class WarningDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const WarningDetailScreen({super.key, required this.id});

  @override
  ConsumerState<WarningDetailScreen> createState() => _WarningDetailScreenState();
}

class _WarningDetailScreenState extends ConsumerState<WarningDetailScreen> {
  Warning? _warning;
  SignatureStrokes? _savedSignature;
  bool _loading = true;
  bool _signing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 상세 로드 — getDetail 호출이 곧 acknowledge(자동 확인).
  /// 저장된 서명도 미리 가져와 Sign 시트의 "Use saved" 에 사용.
  Future<void> _load() async {
    final service = ref.read(warningServiceProvider);
    try {
      final warning = await service.getDetail(widget.id);
      SignatureStrokes? saved;
      try {
        saved = await service.getSavedSignature();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _warning = warning;
        _savedSignature = saved;
        _loading = false;
      });
      // 목록/배지에 acknowledge 반영.
      ref.read(warningsProvider.notifier).applyUpdated(warning);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openSignSheet() async {
    final t = AppL10n.of(context);
    final result = await showWarningSignSheet(context, savedSignature: _savedSignature);
    if (result == null || !mounted) return;
    setState(() => _signing = true);
    try {
      final updated = await ref.read(warningServiceProvider).sign(
            widget.id,
            signature: result.signature,
            method: result.method,
            saveAsDefault: result.saveAsDefault,
          );
      if (!mounted) return;
      // 새 기본 서명을 로컬에도 반영.
      if (result.saveAsDefault) _savedSignature = result.signature;
      setState(() {
        _warning = updated;
        _signing = false;
      });
      ref.read(warningsProvider.notifier).applyUpdated(updated);
    } catch (_) {
      if (!mounted) return;
      setState(() => _signing = false);
      await AppModal.show(
        context,
        title: t.warningSignFailed,
        message: t.warningSignFailed,
        type: ModalType.error,
      );
    }
  }

  void _openPdf() {
    final warning = _warning;
    if (warning == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WarningPdfView(warning: warning)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final warning = _warning;
    final title = warning != null
        ? t.warningDetailTitle(warning.refNo)
        : t.warningsHeader;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          AppHeader(title: title, isDetail: true, onBack: () => context.pop()),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.accent)))
          else if (warning == null)
            Expanded(
              child: Center(
                child: Text(_error != null ? t.warningsLoadFailed : t.warningsNotFound,
                    style: const TextStyle(color: AppColors.textMuted)),
              ),
            )
          else
            Expanded(child: _buildContent(t, warning)),
        ],
      ),
    );
  }

  Widget _buildContent(AppL10n t, Warning warning) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _HeaderCard(warning: warning),
        const SizedBox(height: 10),
        _ViewPdfRow(onTap: _openPdf),
        const SizedBox(height: 10),
        if (warning.categories.isNotEmpty) ...[
          _SectionCard(
            title: t.warningSectionReasons,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: warning.categories
                  .map((c) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.bg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(warning.labelFor(c),
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.text)),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 10),
        ],
        if ((warning.details ?? '').isNotEmpty) ...[
          _SectionCard(
            title: t.warningSectionDetails,
            child: Text(warning.details!,
                style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.text)),
          ),
          const SizedBox(height: 10),
        ],
        if ((warning.correctiveAction ?? '').isNotEmpty || warning.deadline != null) ...[
          _SectionCard(
            title: t.warningSectionCorrective,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((warning.correctiveAction ?? '').isNotEmpty)
                  Text(warning.correctiveAction!,
                      style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.text)),
                if (warning.deadline != null) ...[
                  if ((warning.correctiveAction ?? '').isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1, color: AppColors.border),
                    ),
                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 15, color: AppColors.textMuted),
                      const SizedBox(width: 6),
                      Text(t.warningDeadline,
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      const Spacer(),
                      Text(formatFixedDate(warning.deadline!),
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (warning.followUpDate != null) ...[
          _SectionCard(
            title: t.warningSectionFollowUp,
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 15, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text(formatFixedDate(warning.followUpDate!),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
                if ((warning.followUpTime ?? '').isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text('·', style: TextStyle(color: AppColors.textMuted)),
                  ),
                  Text(warning.followUpTime!,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        _SignatureSection(
          warning: warning,
          signing: _signing,
          onSign: _openSignSheet,
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

/// ordinal → 표시 라벨.
String warningTypeLabel(AppL10n t, int? ordinal) {
  switch (ordinal) {
    case 1:
      return t.warningOrdinalFirst;
    case 2:
      return t.warningOrdinalSecond;
    case null:
      return t.warningOrdinalFinal;
    default:
      return t.warningOrdinalN(ordinal);
  }
}

class _HeaderCard extends StatelessWidget {
  final Warning warning;
  const _HeaderCard({required this.warning});

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    // final/2차 이상은 amber, 그 외 accent 톤.
    final isElevated = warning.ordinal == null || (warning.ordinal ?? 0) >= 2;
    final tagFg = isElevated ? AppColors.warning : AppColors.accent;
    final tagBg = isElevated ? AppColors.warningBg : AppColors.accentBg;
    final date = warning.warningDate ?? warning.createdAt;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: tagBg, borderRadius: BorderRadius.circular(20)),
            child: Text(warningTypeLabel(t, warning.ordinal),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tagFg)),
          ),
          const SizedBox(height: 10),
          Text(warning.title,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text, height: 1.3)),
          const SizedBox(height: 8),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (warning.issuedByName != null)
                Text(t.warningIssuedBy(warning.issuedByName!),
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              if (warning.storeName != null) ...[
                _dot(),
                Text(warning.storeName!,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ],
              if (date != null) ...[
                _dot(),
                Text(formatFixedDate(date),
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ],
            ],
          ),
          if (warning.acknowledgedAt != null) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check, size: 13, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(t.warningReadOn(formatDate(warning.acknowledgedAt!)),
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _dot() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 6),
        child: Text('·', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
      );
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(),
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: AppColors.textMuted)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _ViewPdfRow extends StatelessWidget {
  final VoidCallback onTap;
  const _ViewPdfRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                  color: AppColors.accentBg, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.description_outlined, size: 20, color: AppColors.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.warningViewDocument,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
                  const SizedBox(height: 2),
                  Text(t.warningViewDocumentSubtitle,
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _SignatureSection extends StatelessWidget {
  final Warning warning;
  final bool signing;
  final VoidCallback onSign;

  const _SignatureSection({
    required this.warning,
    required this.signing,
    required this.onSign,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final sig = warning.employeeSignature;

    // SIGNED → 서명 stroke + "Signed on {date}".
    if (warning.isSigned && sig != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 24, height: 24,
                  decoration: const BoxDecoration(
                      color: AppColors.success, shape: BoxShape.circle),
                  child: const Icon(Icons.check, size: 14, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Text(
                  sig.signedAt != null
                      ? t.warningSignedOn(formatDate(sig.signedAt!))
                      : t.warningStatusSigned,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.success),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (sig.signatureStrokes != null) ...[
              SizedBox(
                height: 80,
                width: double.infinity,
                child: SignatureStrokesView(signature: sig.signatureStrokes!, strokeWidth: 2.4),
              ),
              const SizedBox(height: 6),
              const Divider(height: 1, color: AppColors.textMuted),
              const SizedBox(height: 6),
              Text(t.warningEmployeeSignature,
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ],
            _managerStatus(context),
          ],
        ),
      );
    }

    // UNSIGNED → 안내 + Sign 버튼.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
                color: AppColors.warningBg, borderRadius: BorderRadius.circular(12)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.warning),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(t.warningSignatureRequired,
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.text)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: signing ? null : onSign,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: signing
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(t.warningActionSign,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          _managerStatus(context),
        ],
      ),
    );
  }

  /// 매니저(발행자) 서명 상태 줄 — PDF뿐 아니라 네이티브 상세에도 표시.
  Widget _managerStatus(BuildContext context) {
    final t = AppL10n.of(context);
    final mgr = warning.managerSignature;
    final signed = mgr?.signedAt != null;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Icon(signed ? Icons.verified_outlined : Icons.schedule,
              size: 16, color: signed ? AppColors.success : AppColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              signed
                  ? t.warningManagerSignedOn(formatDate(mgr!.signedAt!))
                  : t.warningManagerAwaiting,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: signed ? AppColors.text : AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
