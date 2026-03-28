import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../providers/member_provider.dart';
import '../../services/app_settings_service.dart';
import 'category_management_page.dart';

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
