/// 結算記錄（記錄「還錢」動作）
class Settlement {
  late String id;
  late String groupId;
  late String fromMemberId;
  late String fromMemberName;
  late String toMemberId;
  late String toMemberName;
  late double amount;
  String? note;
  late DateTime date;
  late DateTime createdAt;

  Settlement();

  Settlement.fromFirestore(Map<String, dynamic> map, this.id) {
    groupId = map['groupId'] as String? ?? '';
    fromMemberId = map['fromMemberId'] as String? ?? '';
    fromMemberName = map['fromMemberName'] as String? ?? '';
    toMemberId = map['toMemberId'] as String? ?? '';
    toMemberName = map['toMemberName'] as String? ?? '';
    amount = (map['amount'] as num?)?.toDouble() ?? 0;
    note = map['note'] as String?;
    date = _toDateTime(map['date']);
    createdAt = _toDateTime(map['createdAt']);
  }

  Map<String, dynamic> toFirestore() {
    return {
      'groupId': groupId,
      'fromMemberId': fromMemberId,
      'fromMemberName': fromMemberName,
      'toMemberId': toMemberId,
      'toMemberName': toMemberName,
      'amount': amount,
      if (note != null) 'note': note,
      'date': date,
      'createdAt': createdAt,
    };
  }

  DateTime _toDateTime(dynamic value) {
    if (value is DateTime) return value;
    return DateTime.now();
  }
}
