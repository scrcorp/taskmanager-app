import 'package:flutter/material.dart';
import '../../config/theme.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.accentBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.calendar_today_outlined, size: 32, color: AppColors.accent),
          ),
          const SizedBox(height: 16),
          const Text(
            'Schedule',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text),
          ),
          const SizedBox(height: 8),
          const Text(
            'Coming soon',
            style: TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          const Text(
            'View your work schedule and shifts.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
