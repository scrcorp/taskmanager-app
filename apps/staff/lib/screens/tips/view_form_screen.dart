/// 4070 폼 미리보기 + 서명 화면.
///
/// 단순화 (Stage C): 실제 IRS PDF 양식 대신 4 boxes 시각화 + Sign 흐름.
/// 통일 벡터 서명(users.signature_strokes) 으로 이행 — 경고 서명 시트 재사용.
/// Sign 흐름:
///   - 서명 시트(Use saved / Draw new) → SignResult (벡터 strokes)
///   - Apply 후 Preview 상태 (벡터 서명 표시 + Edit/Submit & File)
///   - Submit & File 누르면 server sign API 호출 (strokes 전송)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:htm_core/htm_core.dart';

import '../../models/warning.dart';
import '../../services/tip_service.dart';
import '../../widgets/signature_strokes_view.dart';
import '../warnings/warning_sign_sheet.dart';

class ViewFormScreen extends ConsumerStatefulWidget {
  final String formId;
  final Map<String, dynamic>? initialForm;
  const ViewFormScreen({super.key, required this.formId, this.initialForm});

  @override
  ConsumerState<ViewFormScreen> createState() => _ViewFormScreenState();
}

class _ViewFormScreenState extends ConsumerState<ViewFormScreen> {
  Map<String, dynamic>? _form;
  bool _busy = false;
  String? _error;
  // sign preview 상태 — Apply 후 Submit 전 (벡터 strokes).
  SignatureStrokes? _pending;
  String _pendingMethod = 'drawn';
  bool _pendingSaveForFuture = false;
  // 저장된 벡터 서명 (있으면 시트 기본값 = Use saved).
  SignatureStrokes? _saved;

  @override
  void initState() {
    super.initState();
    _form = widget.initialForm;
    _loadSignature();
    if (_form == null) {
      _loadForm();
    }
  }

  Future<void> _loadForm() async {
    try {
      final list = await ref.read(tipServiceProvider).listForms();
      final f = list.firstWhere(
        (x) => x['id'] == widget.formId,
        orElse: () => const {},
      );
      if (!mounted) return;
      setState(() => _form = f.isEmpty ? null : f);
    } catch (_) {}
  }

  Future<void> _loadSignature() async {
    try {
      final sig = await ref.read(tipServiceProvider).getSavedSignature();
      if (!mounted) return;
      setState(() => _saved = sig);
    } catch (_) {}
  }

  Future<void> _startSign() async {
    final result = await showWarningSignSheet(
      context,
      savedSignature: _saved,
    );
    if (result == null) return;
    setState(() {
      _pending = result.signature;
      _pendingMethod = result.method;
      _pendingSaveForFuture = result.saveAsDefault;
    });
    // 시트에서 "Save as my default" 선택 시 저장 서명 프리뷰도 갱신.
    if (result.saveAsDefault) {
      setState(() => _saved = result.signature);
    }
  }

  Future<void> _submitFile() async {
    final pending = _pending;
    if (pending == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = await ref.read(tipServiceProvider).signForm(
            formId: widget.formId,
            signature: pending,
            method: _pendingMethod,
            saveForFuture: _pendingSaveForFuture,
          );
      if (!mounted) return;
      setState(() {
        _form = updated;
        _pending = null;
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Form filed successfully.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not submit. Try again.';
      });
    }
  }

  Future<bool> _onWillPop() async {
    if (_pending == null) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard signature?'),
        content: const Text(
          'You have an unsubmitted signature. Leaving will discard it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final form = _form;
    if (form == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final isSigned = form['status'] == 'signed';
    final isPreview = _pending != null && !isSigned;

    return PopScope(
      canPop: !isPreview,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _onWillPop() && mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('IRS Form 4070'),
          backgroundColor: AppColors.white,
        ),
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (isPreview)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.preview, color: AppColors.warning, size: 18),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Preview — your signature is applied but not filed yet.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.warning,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              _FormBox(form: form),
              const SizedBox(height: 16),
              _SignatureSection(
                form: form,
                pending: _pending,
                onStartSign: _startSign,
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.danger, fontSize: 12),
                ),
              ],
              const SizedBox(height: 20),
              if (!isSigned && isPreview)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() => _pending = null),
                        child: const Text('Edit sign'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _busy ? null : _submitFile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _busy
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Submit & File',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                )
              else if (!isSigned)
                ElevatedButton(
                  onPressed: _busy ? null : _startSign,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Sign this form',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormBox extends StatelessWidget {
  final Map<String, dynamic> form;
  const _FormBox({required this.form});

  @override
  Widget build(BuildContext context) {
    final cash = double.tryParse(form['reported_cash']?.toString() ?? '0') ?? 0;
    final card = double.tryParse(form['reported_card']?.toString() ?? '0') ?? 0;
    final paid = double.tryParse(form['paid_out']?.toString() ?? '0') ?? 0;
    final net = double.tryParse(form['net_tips']?.toString() ?? '0') ?? 0;
    final start = form['period_start']?.toString() ?? '';
    final end = form['period_end']?.toString() ?? '';
    final store = form['store_name']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Form 4070 — Employee\'s Report of Tips',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$start – $end · $store',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          _BoxRow(num: 1, label: 'Cash tips received', value: cash),
          _BoxRow(num: 2, label: 'Credit-card tips received', value: card),
          _BoxRow(num: 3, label: 'Tips paid out', value: paid, negative: true),
          const Divider(height: 14),
          _BoxRow(num: 4, label: 'Net tips reported', value: net, bold: true),
        ],
      ),
    );
  }
}

class _BoxRow extends StatelessWidget {
  final int num;
  final String label;
  final double value;
  final bool negative;
  final bool bold;
  const _BoxRow({
    required this.num,
    required this.label,
    required this.value,
    this.negative = false,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = bold
        ? AppColors.accent
        : (negative ? AppColors.danger : AppColors.text);
    final sign = negative ? '−' : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$num.',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: bold ? AppColors.text : AppColors.textSecondary,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            '$sign\$${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: bold ? 16 : 13,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SignatureSection extends StatelessWidget {
  final Map<String, dynamic> form;
  final SignatureStrokes? pending;
  final VoidCallback onStartSign;
  const _SignatureSection({
    required this.form,
    required this.pending,
    required this.onStartSign,
  });

  @override
  Widget build(BuildContext context) {
    final isSigned = form['status'] == 'signed';
    final signedAt = form['signed_at']?.toString();
    // 서명된 폼: 벡터 strokes 우선, 없으면 레거시 이미지(구 폼) fallback.
    final signedStrokesRaw = form['signature_strokes'];
    final signedStrokes = signedStrokesRaw is Map
        ? SignatureStrokes.fromJson(signedStrokesRaw.cast<String, dynamic>())
        : null;
    final signedUrl = form['signature_url']?.toString();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Signature',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          if (isSigned && signedStrokes != null && !signedStrokes.isEmpty)
            Container(
              height: 96,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SignatureStrokesView(signature: signedStrokes),
            )
          else if (isSigned && signedUrl != null)
            // 레거시 이미지 서명 (벡터 이행 이전 구 폼).
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.network(signedUrl, height: 80, fit: BoxFit.contain),
            )
          else if (pending != null && !pending!.isEmpty)
            Container(
              height: 96,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SignatureStrokesView(signature: pending!),
            )
          else
            InkWell(
              onTap: onStartSign,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.border,
                    style: BorderStyle.solid,
                  ),
                ),
                child: const Center(
                  child: Text(
                    'Tap to sign',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          if (isSigned && signedAt != null) ...[
            const SizedBox(height: 6),
            Text(
              'Filed ${signedAt.split("T").first}',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}
