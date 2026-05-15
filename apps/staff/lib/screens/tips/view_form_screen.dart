/// 4070 폼 미리보기 + 서명 화면.
///
/// 단순화 (Stage C): 실제 IRS PDF 양식 대신 4 boxes 시각화 + Sign 흐름.
/// Sign 흐름 (가이드 §1.11 / §8.7):
///   - saved signature 있으면 confirm modal (Use saved / Draw new / Cancel)
///   - 없으면 draw modal (Apply + Save for future 토글)
///   - Apply 후 Preview 상태 (사인 표시 + Edit/Submit & File)
///   - Submit & File 누르면 server sign API 호출
///
/// 캔버스는 Stage C 의 SignaturePad widget 재사용.
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:htm_core/htm_core.dart';

import '../../services/api_client.dart';
import '../../services/tip_service.dart';
import 'signature_pad.dart';

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
  // sign preview 상태 — Apply 후 Submit 전.
  String? _pendingKey;
  Uint8List? _pendingPng;
  // 저장된 사인 (있으면 confirm modal 표시)
  String? _savedKey;
  String? _savedUrl;

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
      final res = await ref.read(tipServiceProvider).getSignature();
      if (!mounted) return;
      setState(() {
        _savedKey = res['signature_image_key']?.toString();
        _savedUrl = res['signature_url']?.toString();
      });
    } catch (_) {}
  }

  Future<void> _startSign() async {
    if (_savedKey != null) {
      // Confirm apply saved or draw new
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Use saved signature?'),
          content: _savedUrl == null
              ? const Text('Saved signature exists.')
              : Image.network(_savedUrl!, height: 80, fit: BoxFit.contain),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'draw'),
              child: const Text('Draw new'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, 'use'),
              child: const Text('Use this'),
            ),
          ],
        ),
      );
      if (choice == 'cancel' || choice == null) return;
      if (choice == 'use') {
        setState(() {
          _pendingKey = _savedKey;
          _pendingPng = null;
        });
        return;
      }
    }
    // draw new
    await _showDrawDialog();
  }

  Future<void> _showDrawDialog() async {
    final padKey = GlobalKey<SignaturePadState>();
    Uint8List? captured;
    bool saveForFuture = _savedKey == null;
    String? newKey;
    bool busy = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Draw your signature'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SignaturePad(
                  key: padKey,
                  height: 180,
                  onCaptured: (b) => captured = b,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => padKey.currentState?.clear(),
                        child: const Text('Clear'),
                      ),
                    ),
                  ],
                ),
                CheckboxListTile(
                  value: saveForFuture,
                  onChanged: (v) =>
                      setSt(() => saveForFuture = v ?? false),
                  title: Text(
                    _savedKey == null
                        ? 'Save for future forms'
                        : 'Replace saved signature',
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                ),
                if (busy)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: busy
                  ? null
                  : () async {
                      final pad = padKey.currentState;
                      if (pad == null || !pad.hasInk) return;
                      setSt(() => busy = true);
                      try {
                        final png = await pad.capture();
                        if (png == null) return;
                        final dio = ref.read(dioProvider);
                        final res = await dio.post<Map<String, dynamic>>(
                          '/app/my/tips/signature/blob',
                          data: png,
                          options: Options(
                            headers: {'Content-Type': 'image/png'},
                            contentType: 'image/png',
                          ),
                        );
                        final key =
                            res.data?['signature_image_key']?.toString();
                        if (key == null) return;
                        newKey = key;
                        captured = png;
                        if (saveForFuture) {
                          await ref
                              .read(tipServiceProvider)
                              .updateSignature(key);
                        }
                        if (mounted) Navigator.pop(ctx);
                      } catch (e) {
                        setSt(() => busy = false);
                      }
                    },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
    if (newKey != null) {
      setState(() {
        _pendingKey = newKey;
        _pendingPng = captured;
      });
      if (saveForFuture) await _loadSignature();
    }
  }

  Future<void> _submitFile() async {
    if (_pendingKey == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = await ref.read(tipServiceProvider).signForm(
            formId: widget.formId,
            signatureImageKey: _pendingKey!,
          );
      if (!mounted) return;
      setState(() {
        _form = updated;
        _pendingKey = null;
        _pendingPng = null;
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Form filed successfully.')),
      );
    } catch (_) {
      setState(() {
        _busy = false;
        _error = 'Could not submit. Try again.';
      });
    }
  }

  Future<bool> _onWillPop() async {
    if (_pendingKey == null) return true;
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
    final isPreview = _pendingKey != null && !isSigned;

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
                pendingPng: _pendingPng,
                pendingKey: _pendingKey,
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
                            : () => setState(() {
                                  _pendingKey = null;
                                  _pendingPng = null;
                                }),
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
  final String? pendingKey;
  final Uint8List? pendingPng;
  final VoidCallback onStartSign;
  const _SignatureSection({
    required this.form,
    required this.pendingKey,
    required this.pendingPng,
    required this.onStartSign,
  });

  @override
  Widget build(BuildContext context) {
    final isSigned = form['status'] == 'signed';
    final signedUrl = form['signature_url']?.toString();
    final signedAt = form['signed_at']?.toString();

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
          if (isSigned && signedUrl != null)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.network(signedUrl, height: 80, fit: BoxFit.contain),
            )
          else if (pendingPng != null)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.memory(pendingPng!,
                  height: 80, fit: BoxFit.contain),
            )
          else if (pendingKey != null)
            const Text(
              'Saved signature applied (preview)',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
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
