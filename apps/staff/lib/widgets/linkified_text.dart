/// 본문 텍스트 안의 http/https URL 만 탭 가능한 링크로 렌더한다.
///
/// 서버는 description 을 가공하지 않으므로 링크화는 전적으로 클라 렌더 단계의 일이다.
/// http/https 이외의 스킴(mailto:, tel:, javascript: 등)은 **링크로 만들지 않고**
/// 평문으로 둔다 — 임의 스킴을 그대로 넘기면 외부 앱 실행 경로가 열린다.
///
/// 열기에 실패하면 조용히 넘기지 않고 사유 + 다음 행동(복사)을 스낵바로 준다.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:htm_core/htm_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';

/// http/https URL 매칭. 뒤에 붙은 문장부호는 링크에서 떼어낸다.
final RegExp _urlPattern = RegExp(r'https?://[^\s<]+', caseSensitive: false);

/// URL 끝에 흔히 딸려오는 문장부호(문장 끝 마침표, 괄호 등)를 제외한다.
String _trimTrailingPunctuation(String url) {
  var out = url;
  while (out.isNotEmpty && '.,;:!?'.contains(out[out.length - 1])) {
    out = out.substring(0, out.length - 1);
  }
  // 짝이 맞지 않는 닫는 괄호만 제거
  while (out.endsWith(')') &&
      ')'.allMatches(out).length > '('.allMatches(out).length) {
    out = out.substring(0, out.length - 1);
  }
  return out;
}

class LinkifiedText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextStyle? linkStyle;

  const LinkifiedText(
    this.text, {
    super.key,
    this.style,
    this.linkStyle,
  });

  @override
  State<LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<LinkifiedText> {
  /// url → recognizer 캐시. rebuild 마다 새로 만들면 이전 recognizer 가 살아있는
  /// 상태에서 dispose 되므로 URL 별로 하나만 만들고 dispose 에서 정리한다.
  final Map<String, TapGestureRecognizer> _recognizers = {};

  @override
  void dispose() {
    for (final r in _recognizers.values) {
      r.dispose();
    }
    super.dispose();
  }

  TapGestureRecognizer _recognizerFor(String url) => _recognizers.putIfAbsent(
        url,
        () => TapGestureRecognizer()..onTap = () => _open(url),
      );

  Future<void> _open(String url) async {
    final t = AppL10n.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    var ok = false;
    try {
      final uri = Uri.parse(url);
      ok = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
    } catch (_) {
      ok = false;
    }
    if (ok || !mounted || messenger == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(t.issueLinkOpenFailed),
        action: SnackBarAction(
          label: t.issueLinkCopyAction,
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: url));
            messenger.showSnackBar(
              SnackBar(content: Text(t.issueLinkCopied)),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle = widget.style ??
        const TextStyle(fontSize: 14, color: AppColors.text, height: 1.5);
    final linkStyle = widget.linkStyle ??
        baseStyle.copyWith(
          color: AppColors.accent,
          decoration: TextDecoration.underline,
          decorationColor: AppColors.accent,
        );

    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final m in _urlPattern.allMatches(widget.text)) {
      if (m.start > cursor) {
        spans.add(TextSpan(text: widget.text.substring(cursor, m.start)));
      }
      final raw = m.group(0)!;
      final url = _trimTrailingPunctuation(raw);
      spans.add(TextSpan(
        text: url,
        style: linkStyle,
        recognizer: _recognizerFor(url),
      ));
      // 링크에서 떼어낸 꼬리 문장부호는 평문으로 되돌린다.
      if (url.length < raw.length) {
        spans.add(TextSpan(text: raw.substring(url.length)));
      }
      cursor = m.end;
    }
    if (cursor < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(cursor)));
    }

    return SelectableText.rich(
      TextSpan(style: baseStyle, children: spans),
    );
  }
}
