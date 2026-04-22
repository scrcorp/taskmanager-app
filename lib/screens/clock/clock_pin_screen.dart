/// PIN 입력 화면 — 6자리 사번 입력 넘버패드
///
/// Clock In/Out/Break 전 직원 본인 인증용 화면.
/// 6자리 숫자 입력 후 Verify Identity 버튼으로 인증.
/// 인증 성공 시 clock_success_screen으로 이동.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../providers/clock_provider.dart';
import '../../widgets/app_modal.dart';
import 'clock_screen.dart';

class ClockPinScreen extends ConsumerStatefulWidget {
  final ClockAction action;
  const ClockPinScreen({super.key, required this.action});

  @override
  ConsumerState<ClockPinScreen> createState() => _ClockPinScreenState();
}

class _ClockPinScreenState extends ConsumerState<ClockPinScreen> {
  String _pin = '';
  bool _loading = false;
  static const int _pinLength = 6;

  void _onNumberTap(String digit) {
    if (_pin.length < _pinLength) {
      setState(() => _pin += digit);
    }
  }

  void _onBackspace() {
    if (_pin.isNotEmpty) {
      setState(() => _pin = _pin.substring(0, _pin.length - 1));
    }
  }

  void _onClear() {
    setState(() => _pin = '');
  }

  Future<void> _verify() async {
    if (_pin.length != _pinLength) return;

    setState(() => _loading = true);

    Map<String, dynamic>? result;
    switch (widget.action) {
      case ClockAction.clockIn:
        result = await ref.read(clockProvider.notifier).clockIn(_pin);
        break;
      case ClockAction.clockOut:
        result = await ref.read(clockProvider.notifier).clockOut(_pin);
        break;
      case ClockAction.takeBreak:
        result = await ref.read(clockProvider.notifier).toggleBreak(_pin);
        break;
    }

    if (!mounted) return;
    setState(() => _loading = false);

    if (result != null) {
      final userName = result['user_name'] as String? ?? result['name'] as String? ?? '';
      context.pushReplacement('/clock/success', extra: {
        'action': widget.action,
        'userName': userName,
      });
    } else {
      setState(() => _pin = '');
      AppModal.show(
        context,
        title: 'Verification Failed',
        message: 'Invalid Employee ID. Please try again.',
        type: ModalType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isTablet = width >= 768;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: isTablet ? _buildTabletLayout() : _buildMobileLayout(),
      ),
    );
  }

  /// 패드 레이아웃 — 좌측 사이드바 + 중앙 PIN + 우측 정보
  Widget _buildTabletLayout() {
    return Row(
      children: [
        // ── 좌측 사이드바 ──
        Container(
          width: 200,
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
                    child: const Icon(Icons.store, size: 18, color: AppColors.accent),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Kiosk', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text)),
                        Text('Store Device', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _SidebarItem(
                icon: Icons.access_time_rounded,
                label: 'Clock In/Out',
                isActive: true,
              ),
            ],
          ),
        ),
        // ── 중앙 PIN 입력 ──
        Expanded(
          flex: 3,
          child: _buildPinContent(),
        ),
        // ── 우측 정보 패널 ──
        Container(
          width: 240,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildInfoCard(
                icon: Icons.verified_user_outlined,
                title: 'Secure Access',
                description: 'Verification ensures the safety and accountability of all staff members.',
                color: AppColors.accent,
              ),
              const SizedBox(height: 16),
              _buildInfoCard(
                icon: Icons.schedule_rounded,
                title: 'Shift Recognition',
                description: 'Clocking in registers your presence for the current cycle.',
                color: AppColors.success,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 모바일 레이아웃
  Widget _buildMobileLayout() {
    return Column(
      children: [
        // 상단 바
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => context.pop(),
                child: const Row(
                  children: [
                    Icon(Icons.arrow_back_ios, size: 18, color: AppColors.textSecondary),
                    SizedBox(width: 4),
                    Text('Cancel & Return', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _buildPinContent()),
      ],
    );
  }

  /// PIN 입력 메인 콘텐츠 (공통)
  Widget _buildPinContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Text(
            'Enter Your Employee ID',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.text),
          ),
          const SizedBox(height: 8),
          Text(
            'Please use your $_pinLength-digit number to proceed',
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 32),
          // PIN 입력 표시
          _buildPinDisplay(),
          const SizedBox(height: 32),
          // 넘버패드
          _buildNumberPad(),
          const SizedBox(height: 24),
          // 하단 버튼
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Cancel
              GestureDetector(
                onTap: () => context.pop(),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.arrow_back, size: 16, color: AppColors.textSecondary),
                      SizedBox(width: 6),
                      Text('Cancel & Return', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),
              // Verify
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: (_pin.length == _pinLength && !_loading) ? _verify : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.4),
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Verify Identity', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// PIN 6자리 표시 박스
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
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.accent),
                )
              : null,
        );
      }),
    );
  }

  /// 넘버패드 (3x4 그리드)
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
              child: Text('CLEAR', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.accent)),
              onTap: _onClear,
            ),
          );
        }
        if (key == 'DEL') {
          return Expanded(
            child: _PadKey(
              child: const Icon(Icons.backspace_outlined, size: 22, color: AppColors.textSecondary),
              onTap: _onBackspace,
            ),
          );
        }
        return Expanded(
          child: _PadKey(
            child: Text(key, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.text)),
            onTap: () => _onNumberTap(key),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
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
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
          const SizedBox(height: 6),
          Text(description, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4)),
        ],
      ),
    );
  }
}

// ─── Sidebar Item ────────────────────────────────────────────────────────

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
          Icon(icon, size: 18, color: isActive ? AppColors.accent : AppColors.textMuted),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color: isActive ? AppColors.accent : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Number Pad Key ──────────────────────────────────────────────────────

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
