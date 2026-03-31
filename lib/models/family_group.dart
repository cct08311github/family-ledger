/// 家庭群組（例如「本家」「爸媽家」「旅行群」）
/// 作為 Firestore DTO，序列化邏輯由 FirestoreService 處理。
class FamilyGroup {
  /// Isar auto-increment ID（移除 Isar 後保留欄位，純相容用）
  int isarId = 0;

  /// 唯一識別碼（UUID）
  late String id;

  /// 群組名稱
  late String name;

  /// 是否為主要群組
  late bool isPrimary;

  /// 建立時間
  late DateTime createdAt;

  /// 更新時間
  late DateTime updatedAt;

  /// 成員 UID 列表（僅存於 Firestore，用於 Security Rules）
  List<String> memberUids = [];

  /// 擁有者 UID
  String? ownerUid;

  /// 邀請碼（可選）
  String? inviteCode;

  FamilyGroup();

  /// 從 Firestore 文件建立
  FamilyGroup.fromFirestore(Map<String, dynamic> map, this.id) {
    name = map['name'] as String? ?? '';
    isPrimary = map['isPrimary'] as bool? ?? false;
    createdAt = _toDateTime(map['createdAt']);
    updatedAt = _toDateTime(map['updatedAt']);
    memberUids = (map['memberUids'] as List?)?.cast<String>() ?? [];
    ownerUid = map['ownerUid'] as String?;
    inviteCode = map['inviteCode'] as String?;
  }

  DateTime _toDateTime(dynamic value) {
    if (value is DateTime) return value;
    return DateTime.now();
  }
}
