/// 관리자 모드 진입 1단계 — 매장 매니저 선택.
///
/// device token 으로 /admin/managers 호출 → Owner + 매장 SV/GM is_manager=true
/// 리스트를 보여줌. 선택 시 PIN 화면으로.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:htm_core/htm_core.dart';

import '../../providers/attendance_admin_provider.dart';
import '../../services/attendance_device_service.dart';
import 'attendance_admin_pin_screen.dart';

class AttendanceAdminSelectScreen extends ConsumerStatefulWidget {
  const AttendanceAdminSelectScreen({super.key});

  @override
  ConsumerState<AttendanceAdminSelectScreen> createState() =>
      _AttendanceAdminSelectScreenState();
}

class _AttendanceAdminSelectScreenState
    extends ConsumerState<AttendanceAdminSelectScreen> {
  bool _loading = true;
  List<AdminManager> _managers = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetch());
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = ref.read(attendanceDeviceServiceProvider);
      final rows = await service.listAdminManagers();
      if (!mounted) return;
      setState(() {
        _managers = rows.map(AdminManager.fromJson).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load managers.';
        _loading = false;
      });
    }
  }

  String _roleLabel(AdminManager m) {
    // Display priority-based label so SV/GM/Owner is clear.
    if (m.rolePriority <= 10) return 'Owner';
    if (m.rolePriority <= 20) return 'General Manager';
    if (m.rolePriority <= 30) return 'Supervisor';
    return m.roleName;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Manager Mode'),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
            const SizedBox(height: 12),
            FilledButton(onPressed: _fetch, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_managers.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No managers available for this store.\nAsk a GM or Owner to assign one.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _managers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final m = _managers[i];
        return Material(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AttendanceAdminPinScreen(manager: m),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.accentBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.shield_outlined,
                        color: AppColors.accent),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.fullName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _roleLabel(m),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
