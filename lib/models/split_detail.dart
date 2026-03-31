/// 拆帳明細（嵌入在 Expense 中）
class SplitDetail {
  late String memberId;
  late String memberName;
  late double shareAmount;
  late double paidAmount;
  late bool isParticipant;

  SplitDetail();

  SplitDetail.fromMap(Map<String, dynamic> map) {
    memberId = map['memberId'] as String? ?? '';
    memberName = map['memberName'] as String? ?? '';
    shareAmount = (map['shareAmount'] as num?)?.toDouble() ?? 0;
    paidAmount = (map['paidAmount'] as num?)?.toDouble() ?? 0;
    isParticipant = map['isParticipant'] as bool? ?? false;
  }

  Map<String, dynamic> toMap() {
    return {
      'memberId': memberId,
      'memberName': memberName,
      'shareAmount': shareAmount,
      'paidAmount': paidAmount,
      'isParticipant': isParticipant,
    };
  }
}
