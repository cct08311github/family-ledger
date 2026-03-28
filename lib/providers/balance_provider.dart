import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../models/expense.dart';
import '../models/balance.dart';
import '../models/family_member.dart';
import '../services/database_service.dart';
import '../services/split_calculator.dart';

final balancesProvider = StreamProvider<List<Balance>>((ref) async* {
  final isar = await DatabaseService.instance;
  yield* isar.balances.where().watch(fireImmediately: true);
});

final simplifiedDebtsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final isar = await DatabaseService.instance;
  final expenses = await isar.expenses.filter().isSharedEqualTo(true).findAll();
  final netDebts = SplitCalculator.calculateNetDebts(expenses: expenses, settlements: []);
  final simplified = SplitCalculator.simplifyDebts(netDebts);
  final members = await isar.familyMembers.where().findAll();
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
  final isar = await DatabaseService.instance;
  final expenses = await isar.expenses.filter().isSharedEqualTo(true).findAll();
  final netDebts = SplitCalculator.calculateNetDebts(expenses: expenses, settlements: []);
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

  Future<void> recalculate() async {
    final isar = await DatabaseService.instance;
    final groupId = await DatabaseService.getPrimaryGroupId();
    if (groupId == null) return;
    final expenses = await isar.expenses.filter().isSharedEqualTo(true).findAll();
    final members = await isar.familyMembers.where().findAll();
    final nameMap = {for (final m in members) m.id: m.name};
    final netDebts = SplitCalculator.calculateNetDebts(expenses: expenses, settlements: []);
    final now = DateTime.now();
    await isar.writeTxn(() async {
      await isar.balances.filter().groupIdEqualTo(groupId).deleteAll();
      for (final entry in netDebts.entries) {
        final parts = entry.key.split('->');
        final balance = Balance()
          ..groupId = groupId
          ..fromMemberId = parts[0]
          ..fromMemberName = nameMap[parts[0]] ?? parts[0]
          ..toMemberId = parts[1]
          ..toMemberName = nameMap[parts[1]] ?? parts[1]
          ..amount = entry.value
          ..updatedAt = now;
        await isar.balances.put(balance);
      }
    });
    ref.invalidate(simplifiedDebtsProvider);
    ref.invalidate(memberNetBalanceProvider);
  }
}
