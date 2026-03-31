/// 兩人之間的債務餘額（快取）
class Balance {
  int isarId = 0;
  late String id;
  late String groupId;
  late String fromMemberId;
  late String fromMemberName;
  late String toMemberId;
  late String toMemberName;
  late double amount;
  late DateTime updatedAt;

  Balance();

  Balance.fromFirestore(Map<String, dynamic> map, this.id) {
    groupId = map['groupId'] as String? ?? '';
    fromMemberId = map['fromMemberId'] as String? ?? '';
    fromMemberName = map['fromMemberName'] as String? ?? '';
    toMemberId = map['toMemberId'] as String? ?? '';
    toMemberName = map['toMemberName'] as String? ?? '';
    amount = (map['amount'] as num?)?.toDouble() ?? 0;
    updatedAt = _toDateTime(map['updatedAt']);
  }

  Map<String, dynamic> toFirestore() {
    return {
      'groupId': groupId,
      'fromMemberId': fromMemberId,
      'fromMemberName': fromMemberName,
      'toMemberId': toMemberId,
      'toMemberName': toMemberName,
      'amount': amount,
      'updatedAt': updatedAt,
    };
  }

  DateTime _toDateTime(dynamic value) {
    if (value is DateTime) return value;
    return DateTime.now();
  }
}
