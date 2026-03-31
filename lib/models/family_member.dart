import 'enums.dart';

/// 家庭成員
class FamilyMember {
  late String id;
  late String groupId;
  late String name;
  String? avatarUrl;
  late MemberRole role;
  late int sortOrder;
  late bool isCurrentUser;
  late DateTime createdAt;
  DateTime? updatedAt;

  FamilyMember();

  FamilyMember.fromFirestore(Map<String, dynamic> map, this.id) {
    groupId = map['groupId'] as String? ?? '';
    name = map['name'] as String? ?? '';
    avatarUrl = map['avatarUrl'] as String?;
    role = MemberRole.values.firstWhere(
      (e) => e.name == map['role'],
      orElse: () => MemberRole.member,
    );
    sortOrder = map['sortOrder'] as int? ?? 0;
    isCurrentUser = map['isCurrentUser'] as bool? ?? false;
    createdAt = _toDateTime(map['createdAt']);
    updatedAt = _toDateTimeOrNull(map['updatedAt']);
  }

  Map<String, dynamic> toFirestore() {
    return {
      'groupId': groupId,
      'name': name,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      'role': role.name,
      'sortOrder': sortOrder,
      'isCurrentUser': isCurrentUser,
      'createdAt': createdAt,
      if (updatedAt != null) 'updatedAt': updatedAt,
    };
  }

  DateTime _toDateTime(dynamic value) {
    if (value is DateTime) return value;
    return DateTime.now();
  }

  DateTime? _toDateTimeOrNull(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.now();
  }
}
