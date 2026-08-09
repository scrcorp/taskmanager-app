/// 관리자 모드 — 매장 설정.
///
/// 기존 Settings 화면(기기 로컬 설정: 매장 선택/기기 해제 등)과 **다른 화면**이다.
/// 여기의 값은 서버의 store 설정이라 같은 매장의 모든 기기에 적용되고, 콘솔의
/// 같은 설정과 동일한 값을 읽고 쓴다. 헷갈리면 한 기기에서만 껐다고 오해하게
/// 되므로 화면 상단에 적용 범위를 명시한다.
///
/// 권한: manage 진입은 SV+ 지만 매장 설정 변경은 콘솔과 같은 stores:update 문턱이다.
/// 서버가 매 요청 검사하며, 메뉴 자체는 홈에서 can_manage_store_settings 로 가린다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:htm_core/htm_core.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/attendance_device_provider.dart';
import '../../services/attendance_device_service.dart';

class AttendanceManageStoreSettingsScreen extends ConsumerStatefulWidget {
  /// 이 화면의 터치를 manage 세션 활동으로 상위에 알린다 (세션 조기 종료 방지).
  final VoidCallback? onActivity;

  const AttendanceManageStoreSettingsScreen({super.key, this.onActivity});

  @override
  ConsumerState<AttendanceManageStoreSettingsScreen> createState() =>
      _AttendanceManageStoreSettingsScreenState();
}

class _AttendanceManageStoreSettingsScreenState
    extends ConsumerState<AttendanceManageStoreSettingsScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  bool _tipEntryEnabled = false;

  AttendanceDeviceService get _service =>
      ref.read(attendanceDeviceServiceProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final body = await _service.manageGetStoreSettings();
      if (!mounted) return;
      setState(() {
        _tipEntryEnabled = body['tip_entry_enabled'] == true;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = AppL10n.of(context).mgStoreSettingsLoadError;
      });
    }
  }

  Future<void> _toggleTipEntry(bool value) async {
    if (_saving) return;
    final t = AppL10n.of(context);
    final previous = _tipEntryEnabled;
    setState(() {
      _tipEntryEnabled = value;
      _saving = true;
      _error = null;
    });
    try {
      await _service.manageUpdateStoreSettings(tipEntryEnabled: value);
      if (!mounted) return;
      // 이 기기도 즉시 새 값을 쓰도록 device 정보를 다시 받아온다
      // (다른 기기는 다음 폴링에서 반영).
      await ref.read(attendanceDeviceProvider.notifier).softRefreshDevice();
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.mgStoreSettingsSaved)),
      );
    } catch (e) {
      if (!mounted) return;
      // 저장 실패면 화면 값을 되돌린다 — 껐다고 보이는데 안 꺼진 상태가 최악.
      setState(() {
        _tipEntryEnabled = previous;
        _saving = false;
        _error = _isForbidden(e)
            ? t.mgStoreSettingsForbidden
            : t.mgStoreSettingsSaveError;
      });
    }
  }

  bool _isForbidden(Object e) {
    final text = e.toString();
    return text.contains('403');
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        title: Text(
          t.mgStoreSettingsTitle,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => widget.onActivity?.call(),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.accentBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              t.mgStoreSettingsScopeNote,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.dangerBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: SwitchListTile(
                        value: _tipEntryEnabled,
                        onChanged: _saving ? null : _toggleTipEntry,
                        title: Text(
                          t.mgStoreSettingsTipEntry,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            t.mgStoreSettingsTipEntryDesc,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        activeThumbColor: AppColors.accent,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
