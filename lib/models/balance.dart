import 'package:isar/isar.dart';

part 'balance.g.dart';

/// 兩人之間的債務餘額（快取，每次支出變動後重新計算）
@collection
class Balance {
  Id isarId = Isar.autoIncrement;

  /// 所屬群組 ID
  @Index()
  late String groupId;

  /// 欠錢的人 ID
  @Index()
  late String fromMemberId;

  /// 欠錢的人名稱
  late String fromMemberName;

  /// 被欠錢的人 ID
  @Index()
  late String toMemberId;

  /// 被欠錢的人名稱
  late String toMemberName;

  /// 金額（正數 = fromMember 欠 toMember）
  late double amount;

  /// 最後更新時間
  late DateTime updatedAt;
}
