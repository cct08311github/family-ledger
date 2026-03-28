import 'package:isar/isar.dart';

part 'activity_log.g.dart';

/// 操作日誌
@collection
class ActivityLog {
  Id isarId = Isar.autoIncrement;

  /// 操作類型：expense_add, expense_edit, expense_delete,
  ///          settlement_add, settlement_delete, member_add, member_edit, etc.
  @Index()
  late String action;

  /// 操作者名稱
  late String actorName;

  /// 操作者 ID
  late String actorId;

  /// 描述（人類可讀）
  late String description;

  /// 相關實體 ID（可選）
  String? entityId;

  /// 操作時間
  @Index()
  late DateTime createdAt;
}
