/// 기기 등록용 Access Code 입력 화면
///
/// 관리자가 발급한 6자 영숫자 코드를 입력 → 서버에 register 요청 → token 발급.
/// 소문자 입력 시 자동으로 대문자 변환.
///
/// 모드:
///   - [AccessCodeMode.initial] — 최초 등록 (shell 에서 사용)
///   - [AccessCodeMode.reset]   — 매장 변경을 위한 재등록.
///       기존 device 를 unregister 한 뒤 새 코드로 register → store-select 로 진입.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/attendance_device_provider.dart';
import '../../widgets/app_modal.dart';

/// Access code 화면 사용 목적
enum AccessCodeMode {
  /// 최초 등록 (needsRegister 진입)
  initial,

  /// Change Store 등 재등록 — 기존 device 를 먼저 해제
  reset,
}

/// Access code 입력 화면
class AttendanceAccessCodeScreen extends ConsumerStatefulWidget {
  final AccessCodeMode mode;
  const AttendanceAccessCodeScreen({
    super.key,
    this.mode = AccessCodeMode.initial,
  });

  @override
  ConsumerState<AttendanceAccessCodeScreen> createState() =>
      _AttendanceAccessCodeScreenState();
}

class _AttendanceAccessCodeScreenState
    extends ConsumerState<AttendanceAccessCodeScreen> {
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _controller.text.trim().toUpperCase();
    if (code.length < 6) return;
    setState(() => _submitting = true);

    // reset 모드: 기존 device 를 먼저 해제 (실패해도 진행)
    if (widget.mode == AccessCodeMode.reset) {
      await ref.read(attendanceDeviceProvider.notifier).unregister();
    }

    final ok = await ref.read(attendanceDeviceProvider.notifier).register(code);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!ok) {
      final error = ref.read(attendanceDeviceProvider).error ?? 'Invalid access code';
      await AppModal.show(
        context,
        title: 'Couldn\'t register device',
        message: error,
        type: ModalType.error,
      );
      return;
    }
    // reset 모드 — settings 에서 push 로 열렸으므로 pop 하여 shell 의 needsStore 화면 노출
    if (widget.mode == AccessCodeMode.reset && mounted) {
      Navigator.of(context).pop();
    }
    // initial 모드 — shell 이 state 변경을 감지하여 자동 전환
  }

  @override
  Widget build(BuildContext context) {
    final error = ref.watch(attendanceDeviceProvider).error;
    final isReset = widget.mode == AccessCodeMode.reset;
    final title = isReset ? 'Change Store' : 'Register This Device';
    final description = isReset
        ? 'Enter a new 6-character access code to switch this device to a different store.'
        : 'Enter the 6-character access code provided by your manager.';
    final buttonLabel = isReset ? 'Continue' : 'Register Device';
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accentBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  isReset
                      ? Icons.swap_horiz_rounded
                      : Icons.tablet_mac_rounded,
                  size: 36,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _controller,
                autofocus: true,
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                  LengthLimitingTextInputFormatter(6),
                  TextInputFormatter.withFunction((oldValue, newValue) {
                    return newValue.copyWith(text: newValue.text.toUpperCase());
                  }),
                ],
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 6,
                  color: AppColors.text,
                ),
                decoration: const InputDecoration(
                  hintText: 'ABC123',
                  hintStyle: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 6,
                    color: AppColors.textMuted,
                  ),
                ),
                onSubmitted: (_) => _submit(),
                enabled: !_submitting,
              ),
              if (error != null && error.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  error,
                  style: const TextStyle(fontSize: 13, color: AppColors.danger),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(buttonLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
