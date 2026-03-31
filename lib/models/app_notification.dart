/// 應用內通知
class AppNotification {
  late String id;
  late String type;
  late String title;
  late String body;
  String? entityId;
  late String groupId;
  late String recipientId;
  late bool isRead;
  late DateTime createdAt;

  AppNotification();

  AppNotification.fromFirestore(Map<String, dynamic> map, this.id) {
    type = map['type'] as String? ?? '';
    title = map['title'] as String? ?? '';
    body = map['body'] as String? ?? '';
    entityId = map['entityId'] as String?;
    recipientId = map['recipientId'] as String? ?? '';
    isRead = map['isRead'] as bool? ?? false;
    createdAt = _toDateTime(map['createdAt']);
    groupId = map['groupId'] as String? ?? '';
  }

  Map<String, dynamic> toFirestore() {
    return {
      'type': type,
      'title': title,
      'body': body,
      if (entityId != null) 'entityId': entityId,
      'recipientId': recipientId,
      'isRead': isRead,
      'createdAt': createdAt,
      'groupId': groupId,
    };
  }

  DateTime _toDateTime(dynamic value) {
    if (value is DateTime) return value;
    return DateTime.now();
  }
}
