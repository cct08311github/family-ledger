import 'dart:math';
import '../models/split_detail.dart';
import '../models/expense.dart';
import '../models/settlement.dart';

/// 拆帳計算核心服務
class SplitCalculator {
  /// ===== 拆帳計算 =====

  /// 均分計算
  /// [amount] 總金額
  /// [payerId] 付款人 ID
  /// [participants] 參與拆帳的成員列表 [{id, name}]
  static List<SplitDetail> calculateEqual({
    required double amount,
    required String payerId,
    required List<Map<String, String>> participants,
  }) {
    final perPerson = amount / participants.length;
    // 處理除不盡的尾數：最後一個人吸收差額
    final rounded = double.parse(perPerson.toStringAsFixed(0));
    final remainder = amount - (rounded * participants.length);

    return participants.asMap().entries.map((entry) {
      final i = entry.key;
      final member = entry.value;
      final memberId = member['id']!;
      final isLast = i == participants.length - 1;

      final share = isLast ? rounded + remainder : rounded;
      return SplitDetail()
        ..memberId = memberId
        ..memberName = member['name']!
        ..shareAmount = share
        ..paidAmount = (memberId == payerId) ? amount : 0
        ..isParticipant = true;
    }).toList();
  }

  /// 比例分計算
  /// [percentages] Map<memberId, percentage> 各成員的百分比
  static List<SplitDetail> calculatePercentage({
    required double amount,
    required String payerId,
    required Map<String, double> percentages,
    required Map<String, String> memberNames,
  }) {
    return percentages.entries.map((entry) {
      final memberId = entry.key;
      final pct = entry.value;
      final share = double.parse((amount * pct / 100).toStringAsFixed(0));

      return SplitDetail()
        ..memberId = memberId
        ..memberName = memberNames[memberId] ?? ''
        ..shareAmount = share
        ..paidAmount = (memberId == payerId) ? amount : 0
        ..isParticipant = true;
    }).toList();
  }

  /// 自訂金額計算
  /// [customAmounts] Map<memberId, customAmount> 各成員自訂金額
  static List<SplitDetail> calculateCustom({
    required double amount,
    required String payerId,
    required Map<String, double> customAmounts,
    required Map<String, String> memberNames,
  }) {
    return customAmounts.entries.map((entry) {
      final memberId = entry.key;
      final share = entry.value;

      return SplitDetail()
        ..memberId = memberId
        ..memberName = memberNames[memberId] ?? ''
        ..shareAmount = share
        ..paidAmount = (memberId == payerId) ? amount : 0
        ..isParticipant = true;
    }).toList();
  }

  /// ===== 債務計算 =====

  /// 從所有支出和結算記錄計算兩兩之間的淨債務
  /// 回傳 Map<'fromId->toId', amount>，amount > 0 表示 from 欠 to
  static Map<String, double> calculateNetDebts({
    required List<Expense> expenses,
    required List<Settlement> settlements,
  }) {
    // debts[fromId][toId] = 累計金額
    final Map<String, Map<String, double>> debts = {};

    // 1. 處理所有共同支出
    for (final expense in expenses) {
      if (!expense.isShared) continue;

      final payerId = expense.payerId;
      for (final split in expense.splits) {
        if (!split.isParticipant) continue;
        if (split.memberId == payerId) continue;

        debts.putIfAbsent(split.memberId, () => {});
        debts[split.memberId]!.putIfAbsent(payerId, () => 0);
        debts[split.memberId]![payerId] =
            debts[split.memberId]![payerId]! + split.shareAmount;
      }
    }

    // 2. 扣除結算記錄（settlement = 已還錢，減少債務）
    for (final s in settlements) {
      // from 已經還錢給 to → 減少 from 欠 to 的金額
      debts.putIfAbsent(s.fromMemberId, () => {});
      debts[s.fromMemberId]!.putIfAbsent(s.toMemberId, () => 0);
      debts[s.fromMemberId]![s.toMemberId] =
          debts[s.fromMemberId]![s.toMemberId]! - s.amount;
    }

    // 3. 淨額化（A 欠 B 和 B 欠 A 互相抵消）
    final Map<String, double> netDebts = {};
    final processed = <String>{};

    debts.forEach((from, targets) {
      targets.forEach((to, amount) {
        final pair = _sortedPair(from, to);
        if (processed.contains(pair)) return;
        processed.add(pair);

        final forward = debts[from]?[to] ?? 0;
        final reverse = debts[to]?[from] ?? 0;
        final net = forward - reverse;

        if (net.abs() > 0.5) {
          // 忽略小於 0.5 的零頭
          if (net > 0) {
            netDebts['$from->$to'] = net;
          } else {
            netDebts['$to->$from'] = net.abs();
          }
        }
      });
    });

    return netDebts;
  }

  /// ===== 簡化債務演算法（最小現金流） =====
  ///
  /// 使用貪心演算法：
  /// 1. 計算每個人的淨餘額（正 = 別人欠他，負 = 他欠別人）
  /// 2. 每次讓最大債務人還錢給最大債權人
  /// 3. 重複直到所有債務清零
  static List<Map<String, dynamic>> simplifyDebts(
      Map<String, double> netDebts) {
    // 計算每人淨餘額
    final Map<String, double> netBalance = {};

    netDebts.forEach((key, amount) {
      final parts = key.split('->');
      final from = parts[0];
      final to = parts[1];

      netBalance.putIfAbsent(from, () => 0);
      netBalance.putIfAbsent(to, () => 0);
      netBalance[from] = netBalance[from]! - amount; // 欠錢 → 負
      netBalance[to] = netBalance[to]! + amount;     // 被欠 → 正
    });

    // 過濾掉餘額接近 0 的人
    netBalance.removeWhere((_, v) => v.abs() < 0.5);

    // 貪心法：反覆配對最大債務人和最大債權人
    final List<Map<String, dynamic>> result = [];

    while (netBalance.isNotEmpty) {
      // 找最大債務人（餘額最小 = 欠最多）
      final debtor = netBalance.entries
          .reduce((a, b) => a.value < b.value ? a : b);
      // 找最大債權人（餘額最大 = 被欠最多）
      final creditor = netBalance.entries
          .reduce((a, b) => a.value > b.value ? a : b);

      if (debtor.value >= -0.5 || creditor.value <= 0.5) break;

      final transferAmount = min(creditor.value, debtor.value.abs());

      result.add({
        'from': debtor.key,
        'to': creditor.key,
        'amount': double.parse(transferAmount.toStringAsFixed(0)),
      });

      netBalance[debtor.key] = debtor.value + transferAmount;
      netBalance[creditor.key] = creditor.value - transferAmount;

      // 移除已清零的
      netBalance.removeWhere((_, v) => v.abs() < 0.5);
    }

    return result;
  }

  /// 輔助：產生排序後的成對 key（避免重複計算 A-B 和 B-A）
  static String _sortedPair(String a, String b) {
    return a.compareTo(b) <= 0 ? '$a|$b' : '$b|$a';
  }
}
