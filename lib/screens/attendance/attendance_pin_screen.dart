/// Attendance PIN 입력 화면 — 6자리 사번 입력 넘버패드
///
/// Clock In / Clock Out / Break Start / Break End 전 직원 본인 인증용.
/// 6자리 숫자 입력 후 Verify Identity 버튼으로 서버 호출.
/// 성공 시 `AttendanceSuccessScreen`으로 pushReplacement.
/// 실패 시 모달로 에러 표시 + PIN 초기화.
///
/// Device token 기반 `attendanceDeviceProvider.performClockAction` 사용.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/attendance_dashboard_provider.dart';
import '../../providers/attendance_device_provider.dart';
import '../../widgets/app_modal.dart';
import 'attendance_main_screen.dart';
import 'attendance_success_screen.dart';

class AttendancePinScreen extends ConsumerStatefulWidget {
  final AttendanceAction action;
  final String userId;
  final String userName;
  const AttendancePinScreen({
    super.key,
    required this.action,
    required this.userId,
    required this.userName,
  });

  @override
  ConsumerState<AttendancePinScreen> createState() =>
      _AttendancePinScreenState();
}

class _AttendancePinScreenState extends ConsumerState<AttendancePinScreen> {
  String _pin = '';
  bool _loading = false;
  static const int _pinLength = 6;

  void _onNumberTap(String digit) {
    if (_loading) return;
    if (_pin.length < _pinLength) {
      setState(() => _pin += digit);
    }
  }

  void _onBackspace() {
    if (_loading) return;
    if (_pin.isNotEmpty) {
      setState(() => _pin = _pin.substring(0, _pin.length - 1));
    }
  }

  void _onClear() {
    if (_loading) return;
    setState(() => _pin = '');
  }

  Future<void> _verify() async {
    if (_pin.length != _pinLength || _loading) return;

    setState(() => _loading = true);

    final result = await ref
        .read(attendanceDeviceProvider.notifier)
        .performClockAction(
          action: widget.action.apiKey,
          userId: widget.userId,
          pin: _pin,
          breakType: widget.action.breakType,
        );

    if (!mounted) return;
    setState(() => _loading = false);

    if (result.success) {
      final data = result.data;
      // 서버 응답에 user_name 이 있으면 우선, 없으면 widget.userName fallback
      final userName = (data?['user_name'] as String?) ??
          (data?['name'] as String?) ??
          (data?['user']?['name'] as String?) ??
          widget.userName;
      // 대시보드 즉시 갱신 — 60초 폴링 대기하지 않고 방금 변경사항 반영
      // fire-and-forget: 실패해도 UX 흐름 유지
      // ignore: unawaited_futures
      ref.read(attendanceDashboardProvider.notifier).refresh();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => AttendanceSuccessScreen(
            action: widget.action,
            userName: userName,
          ),
        ),
      );
    } else {
      setState(() => _pin = '');
      AppModal.show(
        context,
        title: 'Verification Failed',
        message: result.message.isNotEmpty
            ? result.message
            : 'Invalid PIN. Please try again.',
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

  /// 태블릿 3-column 레이아웃 — 좌 사이드바 + 중앙 PIN + 우 정보 패널
  Widget _buildTabletLayout() {
    final device = ref.watch(attendanceDeviceProvider).device;
    return Row(
      children: [
        // ── 좌: 사이드바 ──
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
              _SidebarItem(
                icon: Icons.access_time_rounded,
                label: widget.action.label,
                isActive: true,
              ),
            ],
          ),
        ),
        // ── 중앙: PIN 입력 ──
        Expanded(flex: 3, child: _buildPinContent()),
        // ── 우측: 정보 패널 ──
        Container(
          width: 260,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _InfoCard(
                icon: Icons.verified_user_outlined,
                title: 'Secure Access',
                description:
                    'Verification ensures the safety and accountability of all staff members.',
                color: AppColors.accent,
              ),
              const SizedBox(height: 16),
              _InfoCard(
                icon: Icons.schedule_rounded,
                title: 'Shift Recognition',
                description:
                    'Clocking in registers your presence for the current cycle.',
                color: AppColors.success,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPinContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const SizedBox(height: 40),
          if (widget.userName.isNotEmpty) ...[
            Text(
              'Hi, ${widget.userName}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 6),
          ],
          const Text(
            'Enter Your PIN',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please use your $_pinLength-digit number to proceed',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          _buildPinDisplay(),
          const SizedBox(height: 32),
          _buildNumberPad(),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _loading ? null : () => Navigator.of(context).pop(),
                child: const Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.arrow_back,
                          size: 16, color: AppColors.textSecondary),
                      SizedBox(width: 6),
                      Text(
                        'Cancel & Return',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: (_pin.length == _pinLength && !_loading)
                      ? _verify
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    disabledBackgroundColor:
                        AppColors.accent.withValues(alpha: 0.4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 32),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Verify Identity',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildPinDisplay() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pinLength, (i) {
        final filled = i < _pin.length;
        return Container(
          width: 52,
          height: 60,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: filled ? AppColors.accentBg : AppColors.bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: filled ? AppColors.accent : AppColors.border,
              width: filled ? 2 : 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: filled
              ? Text(
                  _pin[i],
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accent,
                  ),
                )
              : null,
        );
      }),
    );
  }

  Widget _buildNumberPad() {
    return SizedBox(
      width: 280,
      child: Column(
        children: [
          _padRow(['1', '2', '3']),
          const SizedBox(height: 10),
          _padRow(['4', '5', '6']),
          const SizedBox(height: 10),
          _padRow(['7', '8', '9']),
          const SizedBox(height: 10),
          _padRow(['CLEAR', '0', 'DEL']),
        ],
      ),
    );
  }

  Widget _padRow(List<String> keys) {
    return Row(
      children: keys.map((key) {
        if (key == 'CLEAR') {
          return Expanded(
            child: _PadKey(
              onTap: _onClear,
              child: const Text(
                'CLEAR',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
            ),
          );
        }
        if (key == 'DEL') {
          return Expanded(
            child: _PadKey(
              onTap: _onBackspace,
              child: const Icon(Icons.backspace_outlined,
                  size: 22, color: AppColors.textSecondary),
            ),
          );
        }
        return Expanded(
          child: _PadKey(
            onTap: () => _onNumberTap(key),
            child: Text(
              key,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Sidebar Item ────────────────────────────────────────────────────

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isActive ? AppColors.accentBg : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon,
              size: 18,
              color: isActive ? AppColors.accent : AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive
                    ? AppColors.accent
                    : AppColors.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Info Card ───────────────────────────────────────────────────────

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

// ─── Number Pad Key ──────────────────────────────────────────────────

class _PadKey extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _PadKey({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        margin: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}
