/// Manage 모드 진입 — PIN 만 입력 (직원 선택 X).
///
/// Phase 6: 매니저 list 화면 제거. 사용자가 PIN 만 입력하면 server 가
/// (1) PIN 으로 user 식별 + (2) 매장 manager 자격 검증 후 진입.
/// 자격 없으면 거절 (Invalid PIN / Not authorized).
///
/// Issue 6: 자체 numpad/PIN box → 메인 화면의 PinNumpad widget 재사용.
/// 메인과 일관성 + Issue 5 의 빠른 tap fix 자동 적용.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:htm_core/htm_core.dart';

import '../../providers/attendance_manage_provider.dart';
import '../../providers/attendance_device_provider.dart';
import '../../widgets/pin_numpad.dart';
import 'attendance_manage_home_screen.dart';

class AttendanceManagePinScreen extends ConsumerStatefulWidget {
  const AttendanceManagePinScreen({super.key});

  @override
  ConsumerState<AttendanceManagePinScreen> createState() =>
      _AttendanceManagePinScreenState();
}

class _AttendanceManagePinScreenState
    extends ConsumerState<AttendanceManagePinScreen> {
  bool _loading = false;

  Future<void> _verify(String pin) async {
    if (_loading) return;
    setState(() => _loading = true);
    final ok = await ref
        .read(attendanceManageSessionProvider.notifier)
        .openWithPin(pin: pin);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AttendanceManageHomeScreen()),
      );
    } else {
      final err =
          ref.read(attendanceManageSessionProvider).error ?? 'Invalid PIN';
      await AppModal.show(
        context,
        title: 'Verification Failed',
        message: err,
        type: ModalType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(child: _buildTabletLayout()),
    );
  }

  Widget _buildTabletLayout() {
    final device = ref.watch(attendanceDeviceProvider).device;
    return Row(
      children: [
        // ── 좌: 사이드바 (store + Manage Mode 배지) ──
        Container(
          width: 220,
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppColors.bg,
            border: Border(right: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.accentBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.store,
                        size: 18, color: AppColors.accent),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device?.storeName ?? 'Store',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          device?.deviceName ?? 'Device',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textMuted),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.accentBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.admin_panel_settings_rounded,
                        size: 18, color: AppColors.accent),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Manage Mode',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // ── 중앙: PinNumpad ──
        Expanded(flex: 3, child: _buildPinContent()),
        // ── 우측: 정보 패널 ──
        Container(
          width: 260,
          padding: const EdgeInsets.all(24),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _InfoCard(
                icon: Icons.shield_outlined,
                title: 'Manager Privileges',
                description:
                    'Only store managers can enter Manage Mode. The session grants edit access for 30 minutes.',
                color: AppColors.accent,
              ),
              SizedBox(height: 16),
              _InfoCard(
                icon: Icons.history_toggle_off_rounded,
                title: 'Session Limit',
                description:
                    'The session auto-expires after 30 minutes. Tap Exit anytime to end immediately.',
                color: AppColors.warning,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPinContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Manage Mode 배지 (좌측 사이드바와 함께 식별). heading/subtitle 은
          // 공간 부담 커서 제거 — 좌측 사이드바 'Manage Mode' 와 본 배지로 충분.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.accentBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'MANAGE MODE',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.accent,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 메인 화면과 동일한 PinNumpad 재사용 (4~6 가변).
          Expanded(
            child: PinNumpad(
              key: const ValueKey('manage_pin_numpad'),
              onSubmit: _verify,
              enabled: !_loading,
            ),
          ),
          const SizedBox(height: 4),
          // Cancel & Return — 메인으로 돌아감.
          GestureDetector(
            onTap: _loading ? null : () => Navigator.of(context).pop(),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back,
                      size: 18, color: AppColors.textSecondary),
                  SizedBox(width: 6),
                  Text(
                    'Cancel & Return',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
