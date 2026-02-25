import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_header.dart';

class MyPageScreen extends ConsumerWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          AppHeader(title: 'My Page', isDetail: true, onBack: () => context.pop()),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Profile card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: AppColors.accentBg,
                          child: Text(
                            user?.initials ?? '?',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.accent),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(user?.fullName ?? 'Unknown', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text)),
                        const SizedBox(height: 4),
                        if (user != null && user.roleName.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: AppColors.accentBg, borderRadius: BorderRadius.circular(8)),
                            child: Text(user.roleName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accent)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Info section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        _InfoRow(icon: Icons.email_outlined, label: 'Email', value: user?.email ?? '-'),
                        _InfoRow(icon: Icons.person_outline, label: 'Username', value: user?.username ?? '-'),
                        _InfoRow(icon: Icons.badge_outlined, label: 'Status', value: (user?.isActive ?? false) ? 'Active' : 'Inactive'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Logout
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await ref.read(authProvider.notifier).logout();
                        if (context.mounted) context.go('/login');
                      },
                      icon: const Icon(Icons.logout, color: AppColors.danger),
                      label: const Text('Logout', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.danger),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 10),
          SizedBox(width: 80, child: Text(label, style: TextStyle(fontSize: 13, color: AppColors.textMuted))),
          Expanded(child: Text(value, style: TextStyle(fontSize: 14, color: AppColors.text))),
        ],
      ),
    );
  }
}
