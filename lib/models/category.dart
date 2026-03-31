/// 自訂支出類別
class Category {
  int isarId = 0;
  late String id;
  late String groupId;
  late String name;
  late String icon;
  late int sortOrder;
  late bool isDefault;
  late bool isActive;

  Category();

  Category.fromFirestore(Map<String, dynamic> map, this.id) {
    groupId = map['groupId'] as String? ?? '';
    name = map['name'] as String? ?? '';
    icon = map['icon'] as String? ?? '📦';
    sortOrder = map['sortOrder'] as int? ?? 0;
    isDefault = map['isDefault'] as bool? ?? false;
    isActive = map['isActive'] as bool? ?? true;
  }

  Map<String, dynamic> toFirestore() {
    return {
      'groupId': groupId,
      'name': name,
      'icon': icon,
      'sortOrder': sortOrder,
      'isDefault': isDefault,
      'isActive': isActive,
    };
  }
}
