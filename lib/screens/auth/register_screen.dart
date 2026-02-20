import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../utils/toast_manager.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _fullNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _isLoading = false;

  Future<void> _register() async {
    if (_passwordCtrl.text != _confirmCtrl.text) {
      ToastManager().error(context, 'Passwords do not match');
      return;
    }
    if (_fullNameCtrl.text.isEmpty || _usernameCtrl.text.isEmpty || _passwordCtrl.text.isEmpty) {
      ToastManager().warning(context, 'Please fill in required fields');
      return;
    }
    setState(() => _isLoading = true);
    final success = await ref.read(authProvider.notifier).register(
      username: _usernameCtrl.text.trim(),
      password: _passwordCtrl.text,
      fullName: _fullNameCtrl.text.trim(),
      email: _emailCtrl.text.isNotEmpty ? _emailCtrl.text.trim() : null,
    );
    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        context.go('/home');
      } else {
        final error = ref.read(authProvider).error ?? 'Registration failed';
        ToastManager().error(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => context.go('/login'), padding: EdgeInsets.zero),
              const SizedBox(height: 16),
              Text('Register', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 28),
              TextField(controller: _fullNameCtrl, decoration: const InputDecoration(hintText: 'Full Name *')),
              const SizedBox(height: 14),
              TextField(controller: _usernameCtrl, decoration: const InputDecoration(hintText: 'Username *')),
              const SizedBox(height: 14),
              TextField(controller: _emailCtrl, decoration: const InputDecoration(hintText: 'Email'), keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 14),
              TextField(controller: _passwordCtrl, obscureText: true, decoration: const InputDecoration(hintText: 'Password *')),
              const SizedBox(height: 14),
              TextField(controller: _confirmCtrl, obscureText: true, decoration: const InputDecoration(hintText: 'Confirm Password *')),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Register'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
