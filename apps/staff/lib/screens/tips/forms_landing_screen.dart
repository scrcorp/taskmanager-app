/// 본인 4070 폼 리스트 화면.
///
/// 사이클 확정 시 직원별 1건 생성됨. 카드: 기간, net tips, 상태, signed 날짜.
/// 카드 탭 → ViewFormScreen.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:htm_core/htm_core.dart';

import '../../services/tip_service.dart';

class FormsLandingScreen extends ConsumerStatefulWidget {
  const FormsLandingScreen({super.key});

  @override
  ConsumerState<FormsLandingScreen> createState() =>
      _FormsLandingScreenState();
}

class _FormsLandingScreenState extends ConsumerState<FormsLandingScreen> {
  List<Map<String, dynamic>> _forms = const [];
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
      final list = await ref.read(tipServiceProvider).listForms();
      if (!mounted) return;
      setState(() {
        _forms = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'Could not load your 4070 forms. Pull down to retry.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final unsigned = _forms.where((f) => f['status'] != 'signed').toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('IRS Form 4070'),
        backgroundColor: AppColors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'My signature',
            onPressed: () => context.push('/tips/signature'),
          ),
        ],
      ),
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_error != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              AppColors.danger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: AppColors.danger, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.danger),
                              ),
                            ),
                            TextButton(
                              onPressed: _load,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    if (unsigned.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color:
                              AppColors.warning.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.assignment_late_outlined,
                                color: AppColors.warning),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${unsigned.length} form(s) awaiting your signature.',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_forms.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Text(
                          'No 4070 forms yet. Forms appear after your manager confirms a cycle.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ..._forms.map((f) => _FormCard(
                          form: f,
                          onTap: () => context
                              .push('/tips/forms/${f['id']}', extra: f)
                              .then((_) => _load()),
                        )),
                  ],
                ),
              ),
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  final Map<String, dynamic> form;
  final VoidCallback onTap;
  const _FormCard({required this.form, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = form['status']?.toString() ?? 'generated';
    final isSigned = status == 'signed';
    final net = double.tryParse(form['net_tips']?.toString() ?? '0') ?? 0;
    final start = form['period_start']?.toString() ?? '';
    final end = form['period_end']?.toString() ?? '';
    final store = form['store_name']?.toString() ?? '';
    final signedAt = form['signed_at']?.toString();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSigned ? AppColors.success.withValues(alpha: 0.4) : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$start – $end',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isSigned
                        ? AppColors.success.withValues(alpha: 0.15)
                        : AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isSigned ? '✓ SIGNED' : 'AWAITING SIGNATURE',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color:
                          isSigned ? AppColors.success : AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              store,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Net tips',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '\$${net.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
            if (signedAt != null) ...[
              const SizedBox(height: 4),
              Text(
                'Signed ${signedAt.split("T").first}',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
