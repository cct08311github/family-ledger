import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../../services/auth_service.dart';
import '../../services/firebase_sync_service.dart';

/// 登入頁面（未登入 Google 前不能使用 app）
class LoginPage extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  const LoginPage({super.key, required this.onLoginSuccess});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLoading = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final user = await AuthService.signInWithGoogle();
      if (user == null) {
        setState(() { _isLoading = false; });
        return; // 使用者取消
      }
      // 登入成功，同步資料
      await FirebaseSyncService.initialSync();
      widget.onLoginSuccess();
    } catch (e) {
      setState(() { _isLoading = false; _error = '$e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.account_balance_wallet,
                  size: 80, color: theme.colorScheme.primary),
              const Gap(24),
              Text('家計本', style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
              const Gap(8),
              Text('全家人共享記帳．自動拆帳．一目了然誰欠誰',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                  textAlign: TextAlign.center),
              const Gap(48),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.g_mobiledata, size: 24),
                    label: const Text('使用 Google 帳號登入', style: TextStyle(fontSize: 16)),
                    onPressed: _signIn,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
              if (_error != null) ...[
                const Gap(16),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
                    textAlign: TextAlign.center),
              ],
              const Gap(24),
              Text('登入後可在多台裝置間同步資料',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
