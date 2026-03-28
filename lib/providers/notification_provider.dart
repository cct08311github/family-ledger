import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../models/app_notification.dart';
import '../services/database_service.dart';
import '../services/local_notification_service.dart';

/// 目前使用者的未讀通知數
final unreadNotificationCountProvider = StreamProvider<int>((ref) async* {
  final isar = await DatabaseService.instance;
  final user = await DatabaseService.getCurrentUser();
  if (user == null) {
    yield 0;
    return;
  }
  yield* isar.appNotifications
      .filter()
      .recipientIdEqualTo(user.id)
      .isReadEqualTo(false)
      .watch(fireImmediately: true)
      .map((list) => list.length);
});

/// 目前使用者的所有通知（最新在前）
final userNotificationsProvider = StreamProvider<List<AppNotification>>((ref) async* {
  final isar = await DatabaseService.instance;
  final user = await DatabaseService.getCurrentUser();
  if (user == null) {
    yield [];
    return;
  }
  yield* isar.appNotifications
      .filter()
      .recipientIdEqualTo(user.id)
      .sortByCreatedAtDesc()
      .limit(50)
      .watch(fireImmediately: true);
});

/// 通知操作
class NotificationService {
  /// 為分攤費用的參與者建立通知
  static Future<void> notifySplitExpense({
    required String expenseId,
    required String payerName,
    required String description,
    required double amount,
    required List<({String memberId, String memberName, double shareAmount})> participants,
    required String payerId,
  }) async {
    final isar = await DatabaseService.instance;
    final now = DateTime.now();
    final notifications = <AppNotification>[];

    for (final p in participants) {
      // 不通知付款人自己
      if (p.memberId == payerId) continue;
      notifications.add(AppNotification()
        ..type = 'split_expense'
        ..title = '新的分攤費用'
        ..body = '$payerName 新增了「$description」NT\$ ${amount.toStringAsFixed(0)}，你需分攤 NT\$ ${p.shareAmount.toStringAsFixed(0)}'
        ..entityId = expenseId
        ..recipientId = p.memberId
        ..isRead = false
        ..createdAt = now);
    }

    if (notifications.isEmpty) return;
    await isar.writeTxn(() async {
      await isar.appNotifications.putAll(notifications);
    });

    // 觸發本地推播通知（僅通知當前使用者）
    final currentUser = await DatabaseService.getCurrentUser();
    if (currentUser != null) {
      for (final n in notifications) {
        if (n.recipientId == currentUser.id) {
          await LocalNotificationService.show(
            id: n.isarId,
            title: n.title,
            body: n.body,
          );
        }
      }
    }
  }

  /// 標記單則通知為已讀
  static Future<void> markAsRead(AppNotification notification) async {
    if (notification.isRead) return;
    final isar = await DatabaseService.instance;
    notification.isRead = true;
    await isar.writeTxn(() async {
      await isar.appNotifications.put(notification);
    });
  }

  /// 標記全部已讀
  static Future<void> markAllAsRead(String recipientId) async {
    final isar = await DatabaseService.instance;
    final unread = await isar.appNotifications
        .filter()
        .recipientIdEqualTo(recipientId)
        .isReadEqualTo(false)
        .findAll();
    if (unread.isEmpty) return;
    for (final n in unread) {
      n.isRead = true;
    }
    await isar.writeTxn(() async {
      await isar.appNotifications.putAll(unread);
    });
  }
}
