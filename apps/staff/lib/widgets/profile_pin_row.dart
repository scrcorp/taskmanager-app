/// My Page 의 clock-in PIN row.
///
/// 본인 폰 전용 화면이라 PIN 마스킹/Show-Hide 없음 — 평문 그대로 표시.
/// Edit (연필 아이콘) 으로 인라인 편집. 4~6 자리 숫자.
/// unique 위반 (pin_not_available) → "Not available" 모달.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:htm_core/htm_core.dart';

import '../l10n/app_localizations.dart';
import '../services/clockin_pin_service.dart';

class ProfilePinRow extends ConsumerStatefulWidget {
  const ProfilePinRow({super.key});

  @override
  ConsumerState<ProfilePinRow> createState() => ProfilePinRowState();
}

class ProfilePinRowState extends ConsumerState<ProfilePinRow> {
  String? _pin;
  bool _loading = true;
  bool _editing = false;
  bool _saving = false;
  final _editCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _editCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await ref.read(clockinPinServiceProvider).getPin();
      if (!mounted) return;
      setState(() {
        _pin = data['clockin_pin']?.toString();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _startEdit() => setState(() {
        _editing = true;
        _editCtrl.text = _pin ?? '';
      });

  void _cancelEdit() => setState(() {
        _editing = false;
        _editCtrl.clear();
      });

  Future<void> _saveEdit() async {
    final value = _editCtrl.text.trim();
    if (!RegExp(r'^\d{4,6}$').hasMatch(value)) return;
    setState(() => _saving = true);
    try {
      final data = await ref.read(clockinPinServiceProvider).updatePin(value);
      if (!mounted) return;
      setState(() {
        _pin = data['clockin_pin']?.toString() ?? value;
        _editing = false;
        _saving = false;
        _editCtrl.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      final t = AppL10n.of(context);
      final isConflict = e.toString().contains('pin_not_available');
      await AppModal.show(
        context,
        title: isConflict ? t.myPinNotAvailable : t.myPinSaveFailed,
        message: isConflict ? t.myPinNotAvailable : t.myPinSaveFailed,
        type: ModalType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Text(
            t.myPinLabel,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : _editing
                    ? _buildEditRow()
                    : _buildDisplayRow(),
          ),
        ],
      ),
    );
  }

  Widget _buildDisplayRow() {
    final t = AppL10n.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            _pin ?? '—',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.accent,
              letterSpacing: 6,
            ),
          ),
        ),
        if (_pin != null)
          IconButton(
            onPressed: _startEdit,
            icon: const Icon(Icons.edit_outlined, size: 20),
            color: AppColors.accent,
            tooltip: t.myPinEdit,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
      ],
    );
  }

  Widget _buildEditRow() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _editCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            autofocus: true,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 6,
              color: AppColors.accent,
            ),
            decoration: const InputDecoration(
              counterText: '',
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            onSubmitted: (_) => _saveEdit(),
          ),
        ),
        if (_saving)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else ...[
          IconButton(
            onPressed: _saveEdit,
            icon: const Icon(Icons.check, size: 20),
            color: AppColors.success,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            onPressed: _cancelEdit,
            icon: const Icon(Icons.close, size: 20),
            color: AppColors.textMuted,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ],
    );
  }
}
