import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_notification.dart';
import '../services/firestore_service.dart';
import '../services/local_notification_service.dart';
import 'member_provider.dart';

/// 目前使用者的未讀通知數
final unreadNotificationCountProvider = StreamProvider<int>((ref) async* {
  final members = await ref.watch(membersProvider.future);
  final currentMember = members.where((m) => m.isCurrentUser).firstOrNull;
  if (currentMember == null) {
    yield 0;
    return;
  }
  final group = await ref.watch(currentGroupProvider.future);
  if (group == null) {
    yield 0;
    return;
  }
  final notifications = await ref.watch(userNotificationsProvider.future);
  yield notifications.where((n) => !n.isRead).length;
});

/// 目前使用者的所有通知（最新在前）
final userNotificationsProvider = StreamProvider<List<AppNotification>>((ref) async* {
  final members = await ref.watch(membersProvider.future);
  final currentMember = members.where((m) => m.isCurrentUser).firstOrNull;
  if (currentMember == null) {
    yield [];
    return;
  }
  final group = await ref.watch(currentGroupProvider.future);
  if (group == null) {
    yield [];
    return;
  }
  yield* FirestoreService.watchNotifications(group.id, currentMember.id);
});

/// 通知操作
class NotificationService {
  /// 為分攤費用的參與者建立通知
  static Future<void> notifySplitExpense({
    required String groupId,
    required String expenseId,
    required String payerName,
    required String description,
    required double amount,
    required List<({String memberId, String memberName, double shareAmount})> participants,
    required String payerId,
  }) async {
    final now = DateTime.now();
    final notifications = <AppNotification>[];

    for (final p in participants) {
      // 不通知付款人自己
      if (p.memberId == payerId) continue;
      final notif = AppNotification()
        ..type = 'split_expense'
        ..title = '新的分攤費用'
        ..body = '$payerName 新增了「$description」NT\$ ${amount.toStringAsFixed(0)}，你需分攤 NT\$ ${p.shareAmount.toStringAsFixed(0)}'
        ..entityId = expenseId
        ..recipientId = p.memberId
        ..groupId = groupId
        ..isRead = false
        ..createdAt = now;
      await FirestoreService.addNotification(groupId, notif);
      notifications.add(notif);
    }

    // 觸發本地推播通知（僅通知當前使用者）
    for (final n in notifications) {
      // 這裡假設 currentMember 的 id 就是 payerId 的持有者
      // 在實際使用中，LocalNotificationService.show 可能需要不同的 ID
      try {
        await LocalNotificationService.show(
          id: n.id.hashCode,
          title: n.title,
          body: n.body,
        );
      } catch (_) {
        // 忽略本地通知失敗
      }
    }
  }

  /// 標記單則通知為已讀
  static Future<void> markAsRead(String groupId, AppNotification notification) async {
    if (notification.isRead) return;
    await FirestoreService.markNotificationRead(groupId, notification.id);
  }

  /// 標記全部已讀
  static Future<void> markAllAsRead(String groupId, String recipientId) async {
    await FirestoreService.markAllNotificationsRead(groupId, recipientId);
  }
}
