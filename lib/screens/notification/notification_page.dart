import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/notification_provider.dart';
import '../../providers/member_provider.dart';

class NotificationPage extends ConsumerWidget {
  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notifications = ref.watch(userNotificationsProvider);
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('通知'),
        actions: [
          currentUser.when(
            data: (user) => user != null
                ? TextButton(
                    onPressed: () => NotificationService.markAllAsRead(user.id),
                    child: const Text('全部已讀'),
                  )
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: notifications.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.notifications_none, size: 64,
                    color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                const SizedBox(height: 16),
                Text('目前沒有通知', style: theme.textTheme.titleMedium),
              ]),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final n = items[index];
              final icon = switch (n.type) {
                'split_expense' => Icons.receipt_long,
                'settlement' => Icons.payments_outlined,
                _ => Icons.notifications_outlined,
              };
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: n.isRead
                      ? theme.colorScheme.surfaceContainerHighest
                      : theme.colorScheme.primary.withValues(alpha: 0.1),
                  foregroundColor: n.isRead
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                      : theme.colorScheme.primary,
                  child: Icon(icon, size: 20),
                ),
                title: Text(
                  n.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: n.isRead ? FontWeight.normal : FontWeight.w600,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(n.body, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('MM/dd HH:mm', 'zh_TW').format(n.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
                trailing: n.isRead
                    ? null
                    : Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                onTap: () => NotificationService.markAsRead(n),
              );
            },
          );
        },
      ),
    );
  }
}
