/// 알림 설정 화면
///
/// 카테고리×채널(in-app/email) 격자 토글. 서버가 카테고리 메타를 내려주므로
/// 클라이언트는 받은 그대로 렌더만 한다. Save 시 변경된 카테고리만 PUT.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_modal.dart';

class AlertSettingsScreen extends ConsumerStatefulWidget {
  const AlertSettingsScreen({super.key});

  @override
  ConsumerState<AlertSettingsScreen> createState() => _AlertSettingsScreenState();
}

class _AlertSettingsScreenState extends ConsumerState<AlertSettingsScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  List<_Category> _categories = const [];
  // 사용자 변경분 — { code: { in_app: bool?, email: bool? } }
  Map<String, Map<String, bool>> _local = {};
  Map<String, Map<String, bool>> _server = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() { _loading = true; _loadError = null; });
    try {
      final svc = ref.read(authServiceProvider);
      final res = await svc.getAlertPreferences();
      final cats = (res['categories'] as List? ?? const [])
          .map((c) => _Category.fromJson(c as Map<String, dynamic>))
          .toList();
      final prefs = _decodePrefs(res['preferences']);
      if (!mounted) return;
      setState(() {
        _categories = cats;
        _server = prefs;
        _local = _clone(prefs);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = "Couldn't load alert settings.";
      });
    }
  }

  Map<String, Map<String, bool>> _decodePrefs(dynamic raw) {
    if (raw is! Map) return {};
    final out = <String, Map<String, bool>>{};
    raw.forEach((k, v) {
      if (k is String && v is Map) {
        final entry = <String, bool>{};
        if (v['in_app'] is bool) entry['in_app'] = v['in_app'] as bool;
        if (v['email'] is bool) entry['email'] = v['email'] as bool;
        if (entry.isNotEmpty) out[k] = entry;
      }
    });
    return out;
  }

  Map<String, Map<String, bool>> _clone(Map<String, Map<String, bool>> src) {
    return {for (final e in src.entries) e.key: Map<String, bool>.from(e.value)};
  }

  bool _isOn(String code, String channel) {
    final v = _local[code]?[channel];
    return v ?? true;
  }

  void _setChannel(String code, String channel, bool value) {
    setState(() {
      final entry = Map<String, bool>.from(_local[code] ?? {});
      entry[channel] = value;
      _local[code] = entry;
    });
  }

  bool get _dirty {
    if (_local.length != _server.length) return true;
    for (final entry in _local.entries) {
      final s = _server[entry.key];
      if (s == null) return true;
      if (s['in_app'] != entry.value['in_app']) return true;
      if (s['email'] != entry.value['email']) return true;
    }
    return false;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      // 클라가 명시한 값만 보냄 — 빈 entry 카테고리는 default(=on)로 복귀
      final payload = <String, dynamic>{};
      _local.forEach((code, channels) {
        if (channels.isEmpty) return;
        payload[code] = {for (final c in channels.entries) c.key: c.value};
      });
      final svc = ref.read(authServiceProvider);
      final res = await svc.updateAlertPreferences(payload);
      final newPrefs = _decodePrefs(res['preferences']);
      if (!mounted) return;
      setState(() {
        _server = newPrefs;
        _local = _clone(newPrefs);
        _saving = false;
      });
      await AppModal.show(
        context,
        title: 'Saved',
        message: 'Alert preferences updated.',
        type: ModalType.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      await AppModal.show(
        context,
        title: "Couldn't save",
        message: 'Please check your connection and try again.',
        type: ModalType.error,
      );
    }
  }

  Future<void> _resetToDefault() async {
    final ok = await AppModal.show(
      context,
      title: 'Reset to default?',
      message: 'All categories will be turned back on. You can adjust them again later.',
      type: ModalType.confirm,
      confirmText: 'Reset',
    );
    if (ok != true) return;
    setState(() => _local = {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          AppHeader(
            title: 'Alert Settings',
            isDetail: true,
            onBack: () => Navigator.of(context).pop(),
          ),
          Expanded(child: _buildBody()),
          if (!_loading && _loadError == null) _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_loadError!, style: const TextStyle(color: AppColors.danger)),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        const _IntroText(),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              const _GridHeader(),
              for (int i = 0; i < _categories.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: AppColors.border),
                _CategoryRow(
                  category: _categories[i],
                  inApp: _isOn(_categories[i].code, 'in_app'),
                  email: _categories[i].emailAvailable
                      ? _isOn(_categories[i].code, 'email')
                      : false,
                  onChangedInApp: (v) => _setChannel(_categories[i].code, 'in_app', v),
                  onChangedEmail: (v) => _setChannel(_categories[i].code, 'email', v),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton.icon(
            onPressed: _local.isEmpty ? null : _resetToDefault,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Reset to default'),
            style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (_saving || !_dirty) ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _saving
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Save', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}

class _IntroText extends StatelessWidget {
  const _IntroText();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Choose which categories you receive in the app and via email. A dash (—) means email isn\'t available for that category.',
      style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
    );
  }
}

class _GridHeader extends StatelessWidget {
  const _GridHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: const [
          Expanded(child: SizedBox()),
          SizedBox(
            width: 56,
            child: Text(
              'IN-APP',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textMuted,
                letterSpacing: 1,
              ),
            ),
          ),
          SizedBox(
            width: 56,
            child: Text(
              'EMAIL',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textMuted,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final _Category category;
  final bool inApp;
  final bool email;
  final ValueChanged<bool> onChangedInApp;
  final ValueChanged<bool> onChangedEmail;

  const _CategoryRow({
    required this.category,
    required this.inApp,
    required this.email,
    required this.onChangedInApp,
    required this.onChangedEmail,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(category.label,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
                const SizedBox(height: 2),
                Text(category.description,
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.35)),
              ],
            ),
          ),
          SizedBox(
            width: 56,
            child: Center(child: Switch(
              value: inApp,
              onChanged: onChangedInApp,
              activeColor: AppColors.accent,
            )),
          ),
          SizedBox(
            width: 56,
            child: Center(
              child: category.emailAvailable
                  ? Switch(
                      value: email,
                      onChanged: onChangedEmail,
                      activeColor: AppColors.accent,
                    )
                  : const Text(
                      '—',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 16),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Category {
  final String code;
  final String label;
  final String description;
  final bool emailAvailable;

  const _Category({
    required this.code,
    required this.label,
    required this.description,
    required this.emailAvailable,
  });

  factory _Category.fromJson(Map<String, dynamic> j) => _Category(
        code: j['code'] as String,
        label: j['label'] as String,
        description: j['description'] as String,
        emailAvailable: j['email_available'] as bool? ?? false,
      );
}
