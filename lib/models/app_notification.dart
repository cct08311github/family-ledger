import 'package:isar/isar.dart';

part 'app_notification.g.dart';

/// 應用內通知
@collection
class AppNotification {
  Id isarId = Isar.autoIncrement;

  /// 通知類型：split_expense, settlement
  @Index()
  late String type;

  /// 通知標題
  late String title;

  /// 通知內容
  late String body;

  /// 相關實體 ID（expense / settlement）
  String? entityId;

  /// 接收者成員 ID
  @Index()
  late String recipientId;

  /// 是否已讀
  @Index()
  late bool isRead;

  /// 建立時間
  @Index()
  late DateTime createdAt;
}
