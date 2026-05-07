/// 화면 우측 상단에 떠 있는 flavor 표시 배지.
///
/// dev / staging 등 비-프로덕션 빌드 식별용. prod 빌드(`kAppFlavor` 빈 문자열)
/// 에선 자기 자신을 그리지 않음.
import 'package:flutter/material.dart';

import '../config/app_flavor.dart';

class FlavorBadgeOverlay extends StatelessWidget {
  final Widget child;
  const FlavorBadgeOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!kHasFlavorBadge) return child;
    return Stack(
      children: [
        child,
        Positioned(
          top: 4,
          right: 4,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: _color(kAppFlavor),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                kAppFlavor,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static Color _color(String flavor) {
    switch (flavor.toUpperCase()) {
      case 'DEV':
        return Colors.redAccent;
      case 'STAGING':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }
}
