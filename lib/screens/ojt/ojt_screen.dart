import 'package:flutter/material.dart';
import '../../config/theme.dart';

class OjtScreen extends StatelessWidget {
  const OjtScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OJT Training')),
      body: Center(
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
              child: const Icon(Icons.school_rounded, size: 32, color: AppColors.accent),
            ),
            const SizedBox(height: 16),
            const Text(
              'OJT Training',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text),
            ),
            const SizedBox(height: 8),
            const Text(
              'Coming soon',
              style: TextStyle(fontSize: 14, color: AppColors.textMuted),
            ),
            const SizedBox(height: 4),
            const Text(
              'On-the-job training modules will be available here.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
