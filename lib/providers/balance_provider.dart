import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/split_calculator.dart';
import 'member_provider.dart';
import 'expense_provider.dart';
import 'settlement_provider.dart';

final simplifiedDebtsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final expenses = await ref.watch(allExpensesProvider.future);
  final settlements = await ref.watch(allSettlementsProvider.future);
  final members = await ref.watch(membersProvider.future);
  final sharedExpenses = expenses.where((e) => e.isShared).toList();
  final netDebts = SplitCalculator.calculateNetDebts(expenses: sharedExpenses, settlements: settlements);
  final simplified = SplitCalculator.simplifyDebts(netDebts);
  final nameMap = {for (final m in members) m.id: m.name};
  return simplified.map((debt) => {
    'from': debt['from'],
    'fromName': nameMap[debt['from']] ?? debt['from'],
    'to': debt['to'],
    'toName': nameMap[debt['to']] ?? debt['to'],
    'amount': debt['amount'],
  }).toList();
});

final memberNetBalanceProvider = FutureProvider<Map<String, double>>((ref) async {
  final expenses = await ref.watch(allExpensesProvider.future);
  final settlements = await ref.watch(allSettlementsProvider.future);
  final sharedExpenses = expenses.where((e) => e.isShared).toList();
  final netDebts = SplitCalculator.calculateNetDebts(expenses: sharedExpenses, settlements: settlements);
  final Map<String, double> balances = {};
  netDebts.forEach((key, amount) {
    final parts = key.split('->');
    balances.putIfAbsent(parts[0], () => 0);
    balances.putIfAbsent(parts[1], () => 0);
    balances[parts[0]] = balances[parts[0]]! - amount;
    balances[parts[1]] = balances[parts[1]]! + amount;
  });
  return balances;
});

final balanceNotifierProvider = AsyncNotifierProvider<BalanceNotifier, void>(BalanceNotifier.new);

class BalanceNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// 重新計算餘額（invalidate 依賴的 FutureProvider）
  Future<void> recalculate() async {
    // 雲端優先：直接 invalidate，未來需要可擴充為快取至 Firestore
    ref.invalidate(simplifiedDebtsProvider);
    ref.invalidate(memberNetBalanceProvider);
  }
}
