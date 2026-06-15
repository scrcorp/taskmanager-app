/// 본인 사인 등록/변경 화면.
///
/// 통일 벡터 서명(users.signature_strokes) 을 관리한다 — 경고와 동일한 서명.
/// 빈 상태 + 저장된 상태 (Re-draw / Remove) 분기.
/// 캔버스 그리기 → Save → exportStrokes() 로 정규화 벡터 추출 → 서버 저장.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:htm_core/htm_core.dart';

import '../../models/warning.dart';
import '../../services/tip_service.dart';
import '../../widgets/signature_strokes_view.dart';
import 'signature_pad.dart';

class SignatureScreen extends ConsumerStatefulWidget {
  const SignatureScreen({super.key});

  @override
  ConsumerState<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends ConsumerState<SignatureScreen> {
  final _padKey = GlobalKey<SignaturePadState>();
  SignatureStrokes? _saved;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final sig = await ref.read(tipServiceProvider).getSavedSignature();
      if (!mounted) return;
      setState(() {
        _saved = sig;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load saved signature.';
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    final pad = _padKey.currentState;
    final strokes = pad?.exportStrokes();
    if (strokes == null) {
      setState(() => _error = 'Draw your signature first.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved =
          await ref.read(tipServiceProvider).putSavedSignature(strokes);
      if (!mounted) return;
      setState(() {
        _saved = saved;
        _busy = false;
      });
      pad?.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signature saved.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not save signature. Try again.';
      });
    }
  }

  Future<void> _remove() async {
    setState(() => _busy = true);
    try {
      await ref.read(tipServiceProvider).clearSignature();
      if (!mounted) return;
      setState(() {
        _saved = null;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not remove signature.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My signature'),
        backgroundColor: AppColors.white,
      ),
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_saved != null) ...[
                    const _SectionLabel(text: 'Current signature'),
                    const SizedBox(height: 6),
                    Container(
                      height: 110,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: SignatureStrokesView(
                        signature: _saved!,
                        strokeWidth: 2.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _remove,
                      icon: const Icon(Icons.delete_outline,
                          size: 16, color: AppColors.danger),
                      label: const Text(
                        'Remove signature',
                        style: TextStyle(color: AppColors.danger),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  const _SectionLabel(text: 'Draw new signature'),
                  const SizedBox(height: 6),
                  SignaturePad(
                    key: _padKey,
                    onCaptured: (_) {},
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => _padKey.currentState?.clear(),
                          child: const Text('Clear'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _busy ? null : _save,
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
                              : Text(
                                  _saved == null
                                      ? 'Save signature'
                                      : 'Replace signature',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 30),
                  const Text(
                    'Your signature is reused on IRS Form 4070 each cycle and on any warnings you sign. You can replace it any time.',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
        letterSpacing: 0.3,
      ),
    );
  }
}
