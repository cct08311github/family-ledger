import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../models/category.dart';
import '../../providers/category_provider.dart';
import '../../providers/member_provider.dart';

class CategoryManagementPage extends ConsumerWidget {
  const CategoryManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final allCategories = ref.watch(allCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('類別管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新增類別',
            onPressed: () => _showEditDialog(context, ref, null),
          ),
        ],
      ),
      body: allCategories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('錯誤：$e')),
        data: (categories) {
          if (categories.isEmpty) {
            return const Center(child: Text('沒有類別'));
          }
          return ReorderableListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: categories.length,
            onReorder: (oldIndex, newIndex) {
              final reordered = List<Category>.from(categories);
              if (newIndex > oldIndex) newIndex--;
              final item = reordered.removeAt(oldIndex);
              reordered.insert(newIndex, item);
              ref.read(categoryNotifierProvider.notifier).reorder(reordered);
            },
            itemBuilder: (context, index) {
              final cat = categories[index];
              return Card(
                key: ValueKey(cat.isarId),
                child: ListTile(
                  leading: Text(cat.icon, style: const TextStyle(fontSize: 28)),
                  title: Text(cat.name),
                  subtitle: Row(children: [
                    if (cat.isDefault)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('預設', style: TextStyle(
                          fontSize: 11, color: theme.colorScheme.onPrimaryContainer)),
                      ),
                    if (cat.isDefault) const Gap(6),
                    Text(cat.isActive ? '啟用中' : '已停用',
                        style: TextStyle(
                          color: cat.isActive
                              ? theme.colorScheme.primary
                              : theme.colorScheme.error,
                          fontSize: 12,
                        )),
                  ]),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    // Toggle active
                    Switch(
                      value: cat.isActive,
                      onChanged: (_) => ref.read(categoryNotifierProvider.notifier).toggleActive(cat),
                    ),
                    // Edit
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () => _showEditDialog(context, ref, cat),
                    ),
                    // Delete (non-default only)
                    if (!cat.isDefault)
                      IconButton(
                        icon: Icon(Icons.delete_outline, size: 20,
                            color: theme.colorScheme.error.withValues(alpha: 0.7)),
                        onPressed: () => _confirmDelete(context, ref, cat),
                      ),
                    // Drag handle
                    const Icon(Icons.drag_handle, size: 20),
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, Category? existing) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final iconController = TextEditingController(text: existing?.icon ?? '');
    final isEdit = existing != null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? '編輯類別' : '新增類別'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: iconController,
            decoration: const InputDecoration(
              labelText: '圖示（Emoji）',
              hintText: '例如：🍜',
              border: OutlineInputBorder(),
            ),
          ),
          const Gap(12),
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: '類別名稱',
              hintText: '例如：餐飲',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              final icon = iconController.text.trim();
              if (name.isEmpty) return;
              if (isEdit) {
                existing
                  ..name = name
                  ..icon = icon.isEmpty ? '📌' : icon;
                ref.read(categoryNotifierProvider.notifier).updateCategory(existing);
              } else {
                ref.read(categoryNotifierProvider.notifier).addCategory(
                  name: name,
                  icon: icon.isEmpty ? '📌' : icon,
                );
              }
              Navigator.pop(ctx);
            },
            child: Text(isEdit ? '儲存' : '新增'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Category cat) async {
    final group = await ref.read(currentGroupProvider.future);
    if (group == null) return;
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除類別'),
        content: Text('確定要刪除「${cat.icon} ${cat.name}」嗎？已使用此類別的記錄不會受影響。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              ref.read(categoryNotifierProvider.notifier).deleteCategory(group.id, cat);
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
  }
}
