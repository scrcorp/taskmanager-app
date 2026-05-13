/// 관리자 모드 진입 2단계 — 매니저 PIN 입력.
///
/// 일반 staff PIN 화면(`attendance_pin_screen.dart`)과 동일한 3-column 태블릿
/// 레이아웃 + LayoutBuilder 기반 반응형 사이즈를 그대로 따라간다. 동작만 다르다:
///   - verify: /admin/session 호출 → admin token 발급
///   - 성공 시 AttendanceAdminHomeScreen 으로 pushReplacement
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:htm_core/htm_core.dart';

import '../../providers/attendance_admin_provider.dart';
import '../../providers/attendance_device_provider.dart';
import 'attendance_admin_home_screen.dart';

class AttendanceAdminPinScreen extends ConsumerStatefulWidget {
  final AdminManager manager;

  const AttendanceAdminPinScreen({super.key, required this.manager});

  @override
  ConsumerState<AttendanceAdminPinScreen> createState() =>
      _AttendanceAdminPinScreenState();
}

class _AttendanceAdminPinScreenState
    extends ConsumerState<AttendanceAdminPinScreen> {
  String _pin = '';
  bool _loading = false;
  bool _revealPin = false;
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
    final ok = await ref
        .read(attendanceAdminSessionProvider.notifier)
        .openWithPin(userId: widget.manager.userId, pin: _pin);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AttendanceAdminHomeScreen()),
      );
    } else {
      final err =
          ref.read(attendanceAdminSessionProvider).error ?? 'Invalid PIN';
      setState(() => _pin = '');
      AppModal.show(
        context,
        title: 'Verification Failed',
        message: err,
        type: ModalType.error,
      );
    }
  }

  String _roleLabel() {
    final m = widget.manager;
    if (m.rolePriority <= 10) return 'Owner';
    if (m.rolePriority <= 20) return 'General Manager';
    if (m.rolePriority <= 30) return 'Supervisor';
    return m.roleName;
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
                        'Manager Mode',
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
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MANAGER',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMuted,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.manager.fullName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _roleLabel(),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
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
                icon: Icons.shield_outlined,
                title: 'Manager Privileges',
                description:
                    'PIN verification grants edit access to today\'s schedule and attendance for 30 minutes.',
                color: AppColors.accent,
              ),
              const SizedBox(height: 16),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        // staff PIN 화면과 동일한 사이즈 계산식 사용 — 일관성 유지.
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final pinBoxW = ((w * 0.72) / _pinLength - 14).clamp(48.0, 90.0);
        final pinBoxH = (pinBoxW * 1.15).clamp(56.0, h * 0.16);
        final pinFontSize = (pinBoxH * 0.45).clamp(24.0, 48.0);
        final padW = (w * 0.78).clamp(320.0, 640.0);
        final keyH = (h * 0.10).clamp(52.0, 84.0);
        final keyFont = (keyH * 0.42).clamp(20.0, 36.0);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Hi, ${widget.manager.fullName}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Enter Manager PIN',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the $_pinLength-digit PIN of this manager to enter Manager Mode',
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: h * 0.025),
              _buildPinDisplay(pinBoxW, pinBoxH, pinFontSize),
              SizedBox(height: h * 0.025),
              _buildNumberPad(padW, keyH, keyFont),
              SizedBox(height: h * 0.02),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap:
                        _loading ? null : () => Navigator.of(context).pop(),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
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
                  const SizedBox(width: 24),
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: (_pin.length == _pinLength && !_loading)
                          ? _verify
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        disabledBackgroundColor:
                            AppColors.accent.withValues(alpha: 0.4),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 40),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Enter Manager Mode',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPinDisplay(double boxW, double boxH, double fontSize) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ...List.generate(_pinLength, (i) {
          final filled = i < _pin.length;
          return Container(
            width: boxW,
            height: boxH,
            margin: const EdgeInsets.symmetric(horizontal: 7),
            decoration: BoxDecoration(
              color: filled ? AppColors.accentBg : AppColors.bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: filled ? AppColors.accent : AppColors.border,
                width: filled ? 2.5 : 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: filled
                ? (_revealPin
                    ? Text(
                        _pin[i],
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accent,
                        ),
                      )
                    : Container(
                        width: boxW * 0.35,
                        height: boxW * 0.35,
                        decoration: const BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                      ))
                : null,
          );
        }),
        const SizedBox(width: 6),
        IconButton(
          onPressed: _loading || _pin.isEmpty
              ? null
              : () => setState(() => _revealPin = !_revealPin),
          icon: Icon(
            _revealPin
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: 22,
            color: AppColors.textSecondary,
          ),
          tooltip: _revealPin ? 'Hide PIN' : 'Show PIN',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    );
  }

  Widget _buildNumberPad(double width, double keyHeight, double keyFont) {
    return SizedBox(
      width: width,
      child: Column(
        children: [
          _padRow(['1', '2', '3'], keyHeight, keyFont),
          const SizedBox(height: 12),
          _padRow(['4', '5', '6'], keyHeight, keyFont),
          const SizedBox(height: 12),
          _padRow(['7', '8', '9'], keyHeight, keyFont),
          const SizedBox(height: 12),
          _padRow(['CLEAR', '0', 'DEL'], keyHeight, keyFont),
        ],
      ),
    );
  }

  Widget _padRow(List<String> keys, double keyHeight, double keyFont) {
    return Row(
      children: keys.map((key) {
        if (key == 'CLEAR') {
          return Expanded(
            child: _PadKey(
              height: keyHeight,
              onTap: _onClear,
              child: Text(
                'CLEAR',
                style: TextStyle(
                  fontSize: (keyFont * 0.55).clamp(15.0, 24.0),
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
              height: keyHeight,
              onTap: _onBackspace,
              child: Icon(Icons.backspace_outlined,
                  size: (keyFont * 0.9).clamp(24.0, 38.0),
                  color: AppColors.textSecondary),
            ),
          );
        }
        return Expanded(
          child: _PadKey(
            height: keyHeight,
            onTap: () => _onNumberTap(key),
            child: Text(
              key,
              style: TextStyle(
                fontSize: keyFont,
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

// ─── Info Card (staff PIN screen 과 동일 모양) ──────────────────────

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

// ─── Number Pad Key (staff PIN screen 과 동일) ───────────────────────

class _PadKey extends StatelessWidget {
  final Widget child;
  final double height;
  final VoidCallback onTap;

  const _PadKey({
    required this.child,
    required this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        margin: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}
