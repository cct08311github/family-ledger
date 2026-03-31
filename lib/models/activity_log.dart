/// 操作日誌
class ActivityLog {
  int isarId = 0;
  late String id;
  late String action;
  late String actorName;
  late String actorId;
  late String description;
  String? entityId;
  late String groupId;
  late DateTime createdAt;

  ActivityLog();

  ActivityLog.fromFirestore(Map<String, dynamic> map, this.id) {
    action = map['action'] as String? ?? '';
    actorName = map['actorName'] as String? ?? '';
    actorId = map['actorId'] as String? ?? '';
    description = map['description'] as String? ?? '';
    entityId = map['entityId'] as String?;
    groupId = map['groupId'] as String? ?? '';
    createdAt = _toDateTime(map['createdAt']);
  }

  Map<String, dynamic> toFirestore() {
    return {
      'action': action,
      'actorName': actorName,
      'actorId': actorId,
      'description': description,
      if (entityId != null) 'entityId': entityId,
      'createdAt': createdAt,
      'groupId': groupId,
    };
  }

  DateTime _toDateTime(dynamic value) {
    if (value is DateTime) return value;
    return DateTime.now();
  }
}
