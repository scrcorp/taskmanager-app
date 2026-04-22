/// 키오스크 매장 설정 화면 — 패드에 고정 매장 지정
///
/// 최초 Clock 탭 진입 시 매장이 미설정이면 이 화면으로 이동.
/// 서버에서 매장 목록을 조회하여 선택하면 SharedPreferences에 저장.
/// 설정 후 Clock 대시보드로 이동.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../models/store.dart';
import '../../services/clock_service.dart';
import '../../utils/token_storage.dart';

/// 매장 목록 로딩 Provider
final kioskStoresProvider = FutureProvider<List<Store>>((ref) async {
  final service = ref.read(clockServiceProvider);
  final data = await service.getStores();
  return data
      .map((e) => Store.fromJson(e as Map<String, dynamic>))
      .toList();
});

class KioskSetupScreen extends ConsumerWidget {
  const KioskSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storesAsync = ref.watch(kioskStoresProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: Container(
            width: 440,
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── 아이콘 ──
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.accentBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.store_rounded, size: 32, color: AppColors.accent),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Kiosk Store Setup',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.text),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Select the store assigned to this device.\nThis setting will be saved for all future sessions.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 28),
                // ── 매장 목록 ──
                storesAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline, size: 32, color: AppColors.danger),
                        const SizedBox(height: 8),
                        Text(
                          'Failed to load stores.\nPlease check your connection.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => ref.invalidate(kioskStoresProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                  data: (stores) => Column(
                    children: stores.map((store) => _StoreCard(
                      store: store,
                      onTap: () async {
                        await TokenStorage.setKioskStore(store.id, store.name);
                        if (context.mounted) {
                          context.go('/clock');
                        }
                      },
                    )).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StoreCard extends StatelessWidget {
  final Store store;
  final VoidCallback onTap;

  const _StoreCard({required this.store, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accentBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.storefront_rounded, size: 20, color: AppColors.accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.name,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text),
                    ),
                    if (store.address != null)
                      Text(
                        store.address!,
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
