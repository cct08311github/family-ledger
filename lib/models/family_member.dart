import 'package:isar/isar.dart';
import 'enums.dart';

part 'family_member.g.dart';

/// 家庭成員
@collection
class FamilyMember {
  Id isarId = Isar.autoIncrement;

  /// 唯一識別碼（UUID）
  @Index(unique: true)
  late String id;

  /// 所屬群組 ID
  @Index()
  late String groupId;

  /// 顯示名稱
  late String name;

  /// 大頭貼路徑（本地或網路）
  String? avatarUrl;

  /// 角色：admin / member
  @Enumerated(EnumType.name)
  late MemberRole role;

  /// 排序順序（方便 UI 排列）
  late int sortOrder;

  /// 是否為目前使用者（本地切換用）
  late bool isCurrentUser;

  /// 建立時間
  late DateTime createdAt;
}

