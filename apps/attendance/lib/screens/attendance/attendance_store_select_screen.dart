/// 기기에 매장(store) 할당 화면
///
/// Device token으로 `GET /api/v1/attendance/stores` 호출하여 후보 매장 목록을
/// 보여주고, 사용자가 하나를 선택하면 `PUT /api/v1/attendance/store`로 저장한다.
///
/// dart-define `ATTENDANCE_STORE_IDS` fallback도 유지 — 서버 엔드포인트가
/// 실패하거나 빈 결과일 때 수동 입력/preset UI를 표시.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/attendance_device_provider.dart';
import '../../services/attendance_device_service.dart';
import '../../widgets/app_modal.dart';

/// dart-define fallback — 서버 매장 목록 조회 실패 시 사용
const _presetStoreIdsRaw = String.fromEnvironment(
  'ATTENDANCE_STORE_IDS',
  defaultValue: '',
);

class _StoreOption {
  final String id;
  final String name;
  const _StoreOption({required this.id, required this.name});
}

List<_StoreOption> _parsePresetStores() {
  if (_presetStoreIdsRaw.isEmpty) return const [];
  return _presetStoreIdsRaw
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .map((entry) {
        final parts = entry.split(':');
        if (parts.length >= 2) {
          return _StoreOption(
            name: parts[0].trim(),
            id: parts.sublist(1).join(':').trim(),
          );
        }
        return _StoreOption(name: entry, id: entry);
      })
      .toList();
}

/// 매장 선택 화면
class AttendanceStoreSelectScreen extends ConsumerStatefulWidget {
  const AttendanceStoreSelectScreen({super.key});

  @override
  ConsumerState<AttendanceStoreSelectScreen> createState() =>
      _AttendanceStoreSelectScreenState();
}

class _AttendanceStoreSelectScreenState
    extends ConsumerState<AttendanceStoreSelectScreen> {
  final _controller = TextEditingController();
  bool _submitting = false;
  bool _loading = true;
  String? _loadError;
  List<_StoreOption> _stores = const [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadStores);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadStores() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final service = ref.read(attendanceDeviceServiceProvider);
      final raw = await service.listStores();
      final stores = raw
          .map((m) => _StoreOption(
                id: (m['id'] ?? '').toString(),
                name: (m['name'] ?? '').toString(),
              ))
          .where((s) => s.id.isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() {
        _stores = stores;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      // 서버 조회 실패 시 dart-define preset fallback
      setState(() {
        _stores = _parsePresetStores();
        _loading = false;
        _loadError = 'Failed to load stores from server. Showing preset/manual fallback.';
      });
    }
  }

  Future<void> _assign(String storeId) async {
    if (storeId.isEmpty) return;
    setState(() => _submitting = true);
    final ok = await ref
        .read(attendanceDeviceProvider.notifier)
        .assignStore(storeId);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!ok) {
      final error = ref.read(attendanceDeviceProvider).error ?? 'Failed to assign store';
      await AppModal.show(
        context,
        title: 'Couldn\'t assign store',
        message: error,
        type: ModalType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final device = ref.watch(attendanceDeviceProvider).device;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accentBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.store_mall_directory_rounded,
                    size: 36, color: AppColors.accent),
              ),
              const SizedBox(height: 20),
              const Text(
                'Select Store',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                device != null
                    ? 'This device (${device.deviceName}) needs to be assigned to a store.'
                    : 'This device needs to be assigned to a store.',
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  ),
                )
              else ...[
                if (_loadError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.dangerBg,
                      border: Border.all(color: AppColors.danger),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            size: 16, color: AppColors.danger),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _loadError!,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.danger),
                          ),
                        ),
                        TextButton(
                          onPressed: _loading ? null : _loadStores,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_stores.isNotEmpty) ...[
                  ..._stores.map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _StoreCard(
                          label: s.name,
                          id: s.id,
                          onTap: _submitting ? null : () => _assign(s.id),
                        ),
                      )),
                  const SizedBox(height: 12),
                ] else if (_loadError == null) ...[
                  const Text(
                    'No stores available. Contact an administrator.',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                ],
                // Manual UUID fallback (debug/admin 전용)
                const Divider(),
                const SizedBox(height: 12),
                const Text('Manual Store ID',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                TextField(
                  controller: _controller,
                  enabled: !_submitting,
                  decoration: const InputDecoration(
                    hintText: 'Paste store UUID (fallback)',
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _submitting
                      ? null
                      : () => _assign(_controller.text.trim()),
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Assign Store'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StoreCard extends StatelessWidget {
  final String label;
  final String id;
  final VoidCallback? onTap;
  const _StoreCard({required this.label, required this.id, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.accentBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.store_outlined,
                  color: AppColors.accent, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text)),
                  const SizedBox(height: 2),
                  Text(id,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
