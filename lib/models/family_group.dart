import 'package:isar/isar.dart';

part 'family_group.g.dart';

/// 家庭群組（例如「本家」「爸媽家」「旅行群」）
@collection
class FamilyGroup {
  Id isarId = Isar.autoIncrement;

  /// 唯一識別碼（UUID）
  @Index(unique: true)
  late String id;

  /// 群組名稱
  late String name;

  /// 是否為主要群組
  late bool isPrimary;

  /// 建立時間
  late DateTime createdAt;

  /// 更新時間
  late DateTime updatedAt;
}
