import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';

class BottomNav extends StatelessWidget {
  const BottomNav({super.key});

  static const _tabs = [
    _Tab('/home', Icons.home_outlined, Icons.home, 'Home'),
    _Tab('/work', Icons.assignment_outlined, Icons.assignment, 'mytask'),
    _Tab('/clock', Icons.access_time_outlined, Icons.access_time, 'Clock In Out'),
    _Tab('/schedule', Icons.calendar_today_outlined, Icons.calendar_today, 'Schedule'),
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;

    return Container(
      height: 82,
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: _tabs.map((tab) {
          final active = location == tab.path;
          return Expanded(
            child: GestureDetector(
              onTap: () => context.go(tab.path),
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(active ? tab.activeIcon : tab.icon, size: 22, color: active ? AppColors.accent : AppColors.tabInactive),
                  const SizedBox(height: 4),
                  Text(tab.label, style: TextStyle(fontSize: 10, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: active ? AppColors.accent : AppColors.tabInactive)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _Tab {
  final String path;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _Tab(this.path, this.icon, this.activeIcon, this.label);
}
