import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../providers/member_provider.dart';
import '../../services/app_settings_service.dart';
import '../../services/auth_service.dart';
import '../auth/login_page.dart';
import '../../app.dart';
import '../../providers/theme_provider.dart';
import 'package:flutter/foundation.dart';
import 'category_management_page.dart';
import 'activity_log_page.dart';
import 'debug_log_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final members = ref.watch(membersProvider);
    final currentGroup = ref.watch(currentGroupProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 群組資訊
          Card(child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.home_outlined, color: theme.colorScheme.primary, size: 20),
                const Gap(8),
                Text('家庭群組', style: theme.textTheme.titleMedium),
              ]),
              const Gap(12),
              currentGroup.when(
                data: (group) => Text(group?.name ?? '未設定', style: theme.textTheme.bodyLarge),
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('$e'),
              ),
            ]),
          )),
          const Gap(16),
          // 成員管理
          Card(child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.people_outline, color: theme.colorScheme.primary, size: 20),
                const Gap(8),
                Text('家庭成員', style: theme.textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.person_add_outlined),
                  onPressed: () => _showAddMemberDialog(context, ref),
                ),
              ]),
              const Gap(8),
              members.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('$e'),
                data: (memberList) {
                  if (memberList.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(children: [
                        Icon(Icons.person_add, size: 48,
                            color: theme.colorScheme.primary.withValues(alpha:0.3)),
                        const Gap(8),
                        Text('還沒有成員，請點右上角新增',
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha:0.6))),
                      ]),
                    );
                  }
                  return Column(children: memberList.map((m) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: m.isCurrentUser
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surfaceContainerHighest,
                      foregroundColor: m.isCurrentUser
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface,
                      child: Text(m.name[0]),
                    ),
                    title: Text(m.name),
                    subtitle: Text(m.isCurrentUser ? '目前使用者' : '成員'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (!m.isCurrentUser)
                        TextButton(
                          onPressed: () => ref.read(memberNotifierProvider.notifier).switchUser(m.id),
                          child: const Text('切換'),
                        ),
                      IconButton(
                        icon: Icon(Icons.edit_outlined, size: 20,
                            color: theme.colorScheme.onSurface.withValues(alpha:0.5)),
                        onPressed: () => _showEditMemberDialog(context, ref, m.id, m.name),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, size: 20,
                            color: theme.colorScheme.error.withValues(alpha:0.5)),
                        onPressed: () => _confirmDeleteMember(context, ref, m.id, m.name),
                      ),
                    ]),
                  )).toList());
                },
              ),
            ]),
          )),
          const Gap(16),
          // 主題設定
          Card(child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.palette_outlined, color: theme.colorScheme.primary, size: 20),
                const Gap(8),
                Text('主題', style: theme.textTheme.titleMedium),
              ]),
              const Gap(12),
              // 模式切換
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(value: ThemeMode.system, label: Text('跟隨系統'), icon: Icon(Icons.brightness_auto)),
                  ButtonSegment(value: ThemeMode.light, label: Text('淺色'), icon: Icon(Icons.light_mode)),
                  ButtonSegment(value: ThemeMode.dark, label: Text('深色'), icon: Icon(Icons.dark_mode)),
                ],
                selected: {ref.watch(themeSettingsProvider).mode},
                onSelectionChanged: (s) => ref.read(themeSettingsProvider.notifier).setMode(s.first),
              ),
              const Gap(16),
              // 配色選擇
              Wrap(spacing: 8, runSpacing: 8, children: AppTheme.values.map((t) {
                final isSelected = ref.watch(themeSettingsProvider).theme == t;
                return ChoiceChip(
                  label: Text(t.label),
                  selected: isSelected,
                  avatar: CircleAvatar(backgroundColor: t.lightSeed, radius: 10),
                  onSelected: (_) => ref.read(themeSettingsProvider.notifier).setTheme(t),
                );
              }).toList()),
            ]),
          )),
          const Gap(16),
          // 類別管理
          Card(child: Column(children: [
            ListTile(
              leading: const Icon(Icons.category_outlined),
              title: const Text('類別管理'),
              subtitle: const Text('新增、編輯、排序支出類別'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const CategoryManagementPage())),
            ),
          ])),
          const Gap(16),
          // AI 設定
          Card(child: Column(children: [
            ListTile(
              leading: const Icon(Icons.smart_toy_outlined),
              title: const Text('Gemini API Key'),
              subtitle: const Text('語音記帳 AI 解析所需'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showApiKeyDialog(context),
            ),
          ])),
          const Gap(16),
          // 操作日誌
          Card(child: Column(children: [
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('操作日誌'),
              subtitle: const Text('查看所有成員的操作記錄'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ActivityLogPage())),
            ),
            if (kDebugMode) ...[
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.terminal),
                title: const Text('Debug Log'),
                subtitle: const Text('技術除錯記錄'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const DebugLogPage())),
              ),
            ],
          ])),
          const Gap(16),
          // 帳號
          Card(child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.account_circle_outlined, color: theme.colorScheme.primary, size: 20),
                const Gap(8),
                Text('帳號', style: theme.textTheme.titleMedium),
              ]),
              const Gap(8),
              Row(children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 16),
                const Gap(6),
                Expanded(child: Text(
                  '已登入${AuthService.email != null ? '（${AuthService.email}）' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.green),
                )),
              ]),
              const Gap(4),
              Text('多台裝置登入同一個帳號即可自動同步',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
              const Gap(12),
              SizedBox(width: double.infinity, child: OutlinedButton.icon(
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('登出'),
                onPressed: () => _signOut(context),
                style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
              )),
            ]),
          )),
          const Gap(16),
          // 其他設定
          Card(child: Column(children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('關於'),
              subtitle: const Text('家計本 v1.0.0'),
              onTap: () {},
            ),
          ])),
        ],
      ),
    );
  }

  void _showAddMemberDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('新增成員'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(
          hintText: '請輸入名稱（例如：爸爸）',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        FilledButton(onPressed: () {
          final name = controller.text.trim();
          if (name.isNotEmpty) {
            ref.read(memberNotifierProvider.notifier).addMember(name: name);
            Navigator.pop(ctx);
          }
        }, child: const Text('新增')),
      ],
    ));
  }

  void _showEditMemberDialog(BuildContext context, WidgetRef ref, String id, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('編輯成員'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(border: OutlineInputBorder()),
        autofocus: true,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        FilledButton(onPressed: () {
          final name = controller.text.trim();
          if (name.isNotEmpty) {
            ref.read(memberNotifierProvider.notifier).updateMember(id, name);
            Navigator.pop(ctx);
          }
        }, child: const Text('儲存')),
      ],
    ));
  }

  void _showApiKeyDialog(BuildContext context) async {
    final currentKey = await AppSettingsService.geminiApiKey;
    final controller = TextEditingController(text: currentKey);
    if (!context.mounted) return;
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('設定 Gemini API Key'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('語音記帳需要 Google Gemini API Key 來進行 AI 解析。'),
        const SizedBox(height: 16),
        TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '請輸入 API Key',
            border: OutlineInputBorder(),
          ),
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        FilledButton(onPressed: () async {
          final key = controller.text.trim();
          await AppSettingsService.setGeminiApiKey(key.isEmpty ? null : key);
          if (ctx.mounted) {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(content: Text(key.isEmpty ? 'API Key 已清除' : 'API Key 已儲存'),
                  behavior: SnackBarBehavior.floating),
            );
          }
        }, child: const Text('儲存')),
      ],
    ));
  }

  void _signOut(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('登出'),
        content: const Text('登出後將無法存取資料，確定要登出嗎？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('登出'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await AuthService.signOut();
    if (context.mounted) {
      // 回到登入頁
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const _LoggedOutPage()),
        (route) => false,
      );
    }
  }

  void _confirmDeleteMember(BuildContext context, WidgetRef ref, String id, String name) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('刪除成員'),
      content: Text('確定要刪除「$name」嗎？相關的拆帳記錄不會被刪除。'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        FilledButton(
          onPressed: () {
            ref.read(memberNotifierProvider.notifier).deleteMember(id);
            Navigator.pop(ctx);
          },
          style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
          child: const Text('刪除'),
        ),
      ],
    ));
  }
}

/// 登出後顯示的頁面（重新登入）
class _LoggedOutPage extends StatelessWidget {
  const _LoggedOutPage();
  @override
  Widget build(BuildContext context) {
    return LoginPage(
      onLoginSuccess: () {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ProviderScope(child: FamilyLedgerApp())),
          (route) => false,
        );
      },
    );
  }
}
