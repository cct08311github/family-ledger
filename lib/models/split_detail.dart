import 'package:isar/isar.dart';

/// 拆帳明細（嵌入在 Expense 中）
@embedded
class SplitDetail {
  /// 成員 ID
  late String memberId;

  /// 成員名稱（冗餘儲存，方便顯示）
  late String memberName;

  /// 該成員應付金額
  late double shareAmount;

  /// 該成員實際已付金額（付款人 = 全額，其他人 = 0）
  late double paidAmount;

  /// 該成員是否參與此筆拆帳
  late bool isParticipant;
}
