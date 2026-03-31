import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import '../../services/auth_service.dart';
import '../../services/log_service.dart';
import '../settings/debug_log_page.dart';

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
    LogService.info(LogTag.AUTH, 'Login button pressed');
    try {
      final user = await AuthService.signInWithGoogle();
      if (user == null) {
        setState(() { _isLoading = false; });
        return; // 使用者取消
      }
      // 登入成功，繼續到主畫面（Firestore 即時監聽會自動取得資料）
      LogService.info(LogTag.AUTH, 'Login success');
      widget.onLoginSuccess();
    } catch (e, st) {
      LogService.error(LogTag.AUTH, 'Login failed (${e.runtimeType})', e, st);
      setState(() {
        _isLoading = false;
        _error = '${e.runtimeType}: $e';
      });
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
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('登入失敗', style: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                        fontWeight: FontWeight.bold, fontSize: 13)),
                      const Gap(4),
                      SelectableText(_error!, style: TextStyle(
                        color: theme.colorScheme.onErrorContainer, fontSize: 12)),
                      const Gap(8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          icon: const Icon(Icons.copy, size: 14),
                          label: const Text('複製錯誤', style: TextStyle(fontSize: 12)),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _error!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('已複製'), duration: Duration(seconds: 1)),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Gap(24),
              Text('登入後可在多台裝置間同步資料',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                  textAlign: TextAlign.center),
              // Debug Log 入口（僅 debug mode）
              if (kDebugMode) ...[
                const Gap(32),
                TextButton.icon(
                  icon: Icon(Icons.bug_report_outlined, size: 16,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                  label: Text('Debug Log', style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4))),
                  onPressed: () {
                    Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const DebugLogPage()));
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
