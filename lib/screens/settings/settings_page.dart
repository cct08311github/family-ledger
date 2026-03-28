import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../providers/member_provider.dart';
import '../../services/app_settings_service.dart';
import '../../services/firebase_sync_service.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../providers/theme_provider.dart';
import 'category_management_page.dart';
import 'activity_log_page.dart';

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
          ])),
          const Gap(16),
          // 帳號 & 同步
          Card(child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.sync_outlined, color: theme.colorScheme.primary, size: 20),
                const Gap(8),
                Text('帳號與同步', style: theme.textTheme.titleMedium),
              ]),
              const Gap(8),
              // 帳號狀態
              if (AuthService.isSignedIn) ...[
                Row(children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const Gap(6),
                  Expanded(child: Text(
                    'Apple ID 已登入${AuthService.email != null ? '（${AuthService.email}）' : ''}',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.green),
                  )),
                ]),
                const Gap(4),
                Text('多台裝置登入同一個 Apple ID 即可自動同步',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
              ] else ...[
                Row(children: [
                  Icon(Icons.info_outline, size: 16,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                  const Gap(6),
                  Text('匿名模式（僅限本機）',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                ]),
                const Gap(12),
                SizedBox(width: double.infinity, child: FilledButton.icon(
                  icon: const Icon(Icons.apple, size: 20),
                  label: const Text('使用 Apple ID 登入'),
                  onPressed: () => _signInWithApple(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.onSurface,
                    foregroundColor: theme.colorScheme.surface,
                    minimumSize: const Size.fromHeight(48),
                  ),
                )),
                const Gap(4),
                Text('登入後可跨裝置同步，同 Apple ID 的所有裝置自動共享資料',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
              ],
              const Gap(16),
              // 邀請碼
              SizedBox(width: double.infinity, child: OutlinedButton.icon(
                icon: const Icon(Icons.link, size: 18),
                label: const Text('產生邀請碼（分享給家人）'),
                onPressed: () => _generateInviteCode(context),
              )),
              const Gap(8),
              SizedBox(width: double.infinity, child: OutlinedButton.icon(
                icon: const Icon(Icons.input, size: 18),
                label: const Text('輸入邀請碼（加入群組）'),
                onPressed: () => _joinByInviteCode(context, ref),
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

  void _signInWithApple(BuildContext context) async {
    try {
      final user = await AuthService.signInWithApple();
      if (user == null) return;
      // 重新同步（新 UID 可能不同）
      await FirebaseSyncService.initialSync();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Apple ID 登入成功${user.email != null ? "（${user.email}）" : ""}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('登入失敗：$e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  void _generateInviteCode(BuildContext context) async {
    final groupId = await DatabaseService.getPrimaryGroupId();
    if (groupId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('尚未建立群組'), behavior: SnackBarBehavior.floating));
      }
      return;
    }
    try {
      final code = await FirebaseSyncService.generateInviteCode(groupId);
      if (!context.mounted) return;
      showDialog(context: context, builder: (ctx) => AlertDialog(
        title: const Text('邀請碼'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('把這組邀請碼傳給家人，在他們的裝置上輸入即可加入同一個群組。'),
          const Gap(16),
          SelectableText(
            code,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4),
            textAlign: TextAlign.center,
          ),
          const Gap(8),
          const Text('有效期限：24 小時', style: TextStyle(color: Colors.grey)),
        ]),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('已複製'), behavior: SnackBarBehavior.floating));
            },
            child: const Text('複製'),
          ),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('關閉')),
        ],
      ));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('產生邀請碼失敗：$e'), behavior: SnackBarBehavior.floating));
      }
    }
  }

  void _joinByInviteCode(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('加入群組'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('輸入家人給你的邀請碼，加入同一個家庭群組。'),
        const Gap(16),
        TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '6 碼邀請碼',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.characters,
          autofocus: true,
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        FilledButton(onPressed: () async {
          final code = controller.text.trim().toUpperCase();
          if (code.isEmpty) return;
          try {
            final groupId = await FirebaseSyncService.joinGroupByCode(code);
            if (!ctx.mounted) return;
            if (groupId == null) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('邀請碼無效或已過期'), behavior: SnackBarBehavior.floating));
              return;
            }
            // 開始監聽新群組
            FirebaseSyncService.startRealtimeSync(groupId);
            Navigator.pop(ctx);
            ScaffoldMessenger.of(ctx).showSnackBar(
              const SnackBar(content: Text('已成功加入群組！資料同步中...'), behavior: SnackBarBehavior.floating));
          } catch (e) {
            if (ctx.mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(content: Text('加入失敗：$e'), behavior: SnackBarBehavior.floating));
            }
          }
        }, child: const Text('加入')),
      ],
    ));
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
