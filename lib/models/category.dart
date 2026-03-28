import 'package:isar/isar.dart';

part 'category.g.dart';

/// 自訂支出類別
@collection
class Category {
  Id isarId = Isar.autoIncrement;

  /// 所屬群組 ID
  @Index()
  late String groupId;

  /// 類別名稱
  @Index()
  late String name;

  /// 圖示（emoji）
  late String icon;

  /// 排序順序
  late int sortOrder;

  /// 是否為預設類別（不可刪除）
  late bool isDefault;

  /// 是否啟用
  late bool isActive;
}
