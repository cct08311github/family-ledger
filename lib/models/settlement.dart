import 'package:isar/isar.dart';

part 'settlement.g.dart';

/// 結算記錄（記錄「還錢」動作）
@collection
class Settlement {
  Id isarId = Isar.autoIncrement;

  /// 唯一識別碼（UUID）
  @Index(unique: true)
  late String id;

  /// 所屬群組 ID
  @Index()
  late String groupId;

  /// 還錢的人 ID
  late String fromMemberId;

  /// 還錢的人名稱
  late String fromMemberName;

  /// 收錢的人 ID
  late String toMemberId;

  /// 收錢的人名稱
  late String toMemberName;

  /// 還款金額
  late double amount;

  /// 備註
  String? note;

  /// 結算日期
  @Index()
  late DateTime date;

  /// 建立時間
  late DateTime createdAt;
}
