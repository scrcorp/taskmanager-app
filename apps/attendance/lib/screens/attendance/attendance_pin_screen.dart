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
import 'package:htm_core/htm_core.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/attendance_dashboard_provider.dart';
import '../../providers/attendance_device_provider.dart';
import 'attendance_main_screen.dart';
import 'attendance_success_screen.dart';
import 'attendance_tip_entry_screen.dart';

class AttendancePinScreen extends ConsumerStatefulWidget {
  final AttendanceAction action;
  final String userId;
  final String userName;
  /// Early clock-out 시 main 화면에서 받아온 사유. server 가 검증.
  final String? reason;
  const AttendancePinScreen({
    super.key,
    required this.action,
    required this.userId,
    required this.userName,
    this.reason,
  });

  @override
  ConsumerState<AttendancePinScreen> createState() =>
      _AttendancePinScreenState();
}

class _AttendancePinScreenState extends ConsumerState<AttendancePinScreen> {
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

    final result = await ref
        .read(attendanceDeviceProvider.notifier)
        .performClockAction(
          action: widget.action.apiKey,
          userId: widget.userId,
          pin: _pin,
          breakType: widget.action.breakType,
          reason: widget.reason,
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
      // Clock-out 일 때 근무시간 추출. net_work_minutes (비정상 break 차감) 우선,
      // 없으면 total_work_minutes fallback. 둘 다 없으면 null → 메시지 미표시.
      final netMin = data?['net_work_minutes'] as int?;
      final totalMin = data?['total_work_minutes'] as int?;
      final workedMinutes = netMin ?? totalMin;
      // Clock-out 후엔 강제 tip entry 화면을 한 번 거치게 한다 (Skip 가능).
      // 다른 액션 (clock-in, break_*) 은 바로 success.
      if (widget.action == AttendanceAction.clockOut) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => AttendanceTipEntryScreen(
              userId: widget.userId,
              userName: userName,
              pin: _pin,
              workedMinutes: workedMinutes,
            ),
          ),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => AttendanceSuccessScreen(
              action: widget.action,
              userName: userName,
              workedMinutes: workedMinutes,
            ),
          ),
        );
      }
    } else {
      final t = AppL10n.of(context);
      setState(() => _pin = '');
      AppModal.show(
        context,
        title: t.attPinVerificationFailedTitle,
        message: result.message.isNotEmpty
            ? result.message
            : t.attPinVerificationFailedMessage,
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
    final t = AppL10n.of(context);
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
                          device?.storeName ?? t.commonStore,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          device?.deviceName ?? t.commonDevice,
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
                label: widget.action.localizedLabel(t),
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
                title: t.attPinSecureAccessTitle,
                description: t.attPinSecureAccessDescription,
                color: AppColors.accent,
              ),
              const SizedBox(height: 16),
              _InfoCard(
                icon: Icons.schedule_rounded,
                title: t.attPinShiftRecognitionTitle,
                description: t.attPinShiftRecognitionDescription,
                color: AppColors.success,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPinContent() {
    final t = AppL10n.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // 가용 가로/세로 기준으로 크기 산정. 폰 landscape에서도 overflow 안 나게
        // height 기반 clamp가 dominant — numpad 4행 + PIN row + 헤더 + 버튼이 전부
        // 들어가도록 보수적 상한.
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
              if (widget.userName.isNotEmpty) ...[
                Text(
                  t.attPinHi(widget.userName),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Text(
                t.attPinTitle,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                t.attPinSubtitle(_pinLength),
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
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
                    onTap: _loading ? null : () => Navigator.of(context).pop(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.arrow_back,
                              size: 18, color: AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            t.attPinCancelReturn,
                            style: const TextStyle(
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
                          : Text(
                              t.attPinVerify,
                              style: const TextStyle(
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
    final t = AppL10n.of(context);
    return Row(
      children: keys.map((key) {
        if (key == 'CLEAR') {
          return Expanded(
            child: _PadKey(
              height: keyHeight,
              onTap: _onClear,
              child: Text(
                t.attPinPadClear,
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
  final double height;

  const _PadKey({required this.child, required this.onTap, this.height = 56});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        margin: const EdgeInsets.symmetric(horizontal: 6),
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
