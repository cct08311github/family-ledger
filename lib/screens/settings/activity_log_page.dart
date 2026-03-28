import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/activity_log_provider.dart';

class ActivityLogPage extends ConsumerWidget {
  const ActivityLogPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final logs = ref.watch(activityLogsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('操作日誌')),
      body: logs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (entries) {
          if (entries.isEmpty) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.history, size: 64,
                  color: theme.colorScheme.primary.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              Text('尚無操作記錄', style: theme.textTheme.titleMedium),
            ]));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final log = entries[index];
              final icon = switch (log.action) {
                'expense_add' => Icons.add_circle_outline,
                'expense_edit' => Icons.edit_outlined,
                'expense_delete' => Icons.delete_outline,
                'settlement_add' => Icons.payments_outlined,
                'settlement_delete' => Icons.money_off,
                'member_add' => Icons.person_add_outlined,
                'member_edit' => Icons.person_outline,
                _ => Icons.info_outline,
              };
              final color = log.action.contains('delete')
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary;

              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.1),
                  foregroundColor: color,
                  child: Icon(icon, size: 20),
                ),
                title: Text(log.description, style: theme.textTheme.bodyMedium),
                subtitle: Text(
                  DateFormat('MM/dd HH:mm', 'zh_TW').format(log.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
