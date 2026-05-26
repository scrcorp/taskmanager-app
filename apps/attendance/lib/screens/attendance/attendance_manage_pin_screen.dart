/// Manage 모드 진입 — PIN 만 입력 (직원 선택 X).
///
/// Phase 6: 매니저 list 화면 제거. 사용자가 PIN 만 입력하면 server 가
/// (1) PIN 으로 user 식별 + (2) 매장 manager 자격 검증 후 진입.
/// 자격 없으면 거절 (Invalid PIN / Not authorized).
///
/// UI 세부 재설계는 Phase 7.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:htm_core/htm_core.dart';

import '../../providers/attendance_manage_provider.dart';
import '../../providers/attendance_device_provider.dart';
import 'attendance_manage_home_screen.dart';

class AttendanceManagePinScreen extends ConsumerStatefulWidget {
  const AttendanceManagePinScreen({super.key});

  @override
  ConsumerState<AttendanceManagePinScreen> createState() =>
      _AttendanceManagePinScreenState();
}

class _AttendanceManagePinScreenState
    extends ConsumerState<AttendanceManagePinScreen> {
  String _pin = '';
  bool _loading = false;
  bool _revealPin = false;
  static const int _pinMin = 4;
  static const int _pinMax = 6;

  void _onNumberTap(String digit) {
    if (_loading) return;
    if (_pin.length < _pinMax) {
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
    if (_pin.length < _pinMin || _loading) return;
    setState(() => _loading = true);
    final ok = await ref
        .read(attendanceManageSessionProvider.notifier)
        .openWithPin(pin: _pin);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AttendanceManageHomeScreen()),
      );
    } else {
      final err =
          ref.read(attendanceManageSessionProvider).error ?? 'Invalid PIN';
      setState(() => _pin = '');
      AppModal.show(
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
        // ── 좌: 사이드바 (store + Manage Mode 배지만) ──
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
        // ── 중앙: PIN 입력 ──
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final pinBoxW = ((w * 0.72) / _pinMax - 14).clamp(48.0, 90.0);
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
              // Manage Mode 임을 식별 — 메인 PIN 화면과 구분.
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 6),
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
              const SizedBox(height: 12),
              const Text(
                'Enter Manager PIN',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter your PIN to enter Manage Mode.\nManager privileges required.',
                style: TextStyle(
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
                      onPressed: (_pin.length >= _pinMin && !_loading)
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
                              'Enter Manage Mode',
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
        ...List.generate(_pinMax, (i) {
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
