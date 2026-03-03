import 'package:flutter/material.dart';
import '../../config/theme.dart';

class ClockScreen extends StatelessWidget {
  const ClockScreen({super.key});

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
            child: const Icon(Icons.access_time_outlined, size: 32, color: AppColors.accent),
          ),
          const SizedBox(height: 16),
          const Text(
            'Clock In / Out',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text),
          ),
          const SizedBox(height: 8),
          const Text(
            'Coming soon',
            style: TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          const Text(
            'Clock in and out to track your work hours.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
