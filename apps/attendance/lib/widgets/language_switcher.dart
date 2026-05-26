/// 언어 토글 — 동그란 국기 아바타 + 클릭 시 드롭다운.
/// Attendance 키오스크의 로그인 전(access code) 화면에서 사용.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:htm_core/htm_core.dart';
import '../providers/locale_provider.dart';

const _flagFor = <String, String>{
  'en': '🇺🇸',
  'es': '🇪🇸',
};
const _nameFor = <String, String>{
  'en': 'English',
  'es': 'Español',
};

class LanguageSwitcher extends ConsumerWidget {
  /// 크기 (지름). 기본 36 — access code 등 작은 위치용. main 헤더는 80.
  final double size;
  const LanguageSwitcher({super.key, this.size = 36});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = ref.watch(localeProvider)?.languageCode ??
        Localizations.localeOf(context).languageCode;
    return PopupMenuButton<String>(
      tooltip: 'Language',
      onSelected: (c) {
        ref.read(localeProvider.notifier).setLocale(Locale(c));
      },
      itemBuilder: (_) => [
        for (final c in ['en', 'es'])
          PopupMenuItem<String>(
            value: c,
            height: 48,
            child: Row(
              children: [
                Text(_flagFor[c]!, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Text(_nameFor[c]!,
                    style: const TextStyle(fontSize: 16, color: AppColors.text)),
                if (c == code) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.check, size: 18, color: AppColors.accent),
                ],
              ],
            ),
          ),
      ],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.bg,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border, width: size >= 60 ? 2 : 1),
        ),
        child: Text(
          _flagFor[code]!,
          style: TextStyle(fontSize: size * 0.5),
        ),
      ),
    );
  }
}
