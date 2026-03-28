import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';
import '../models/enums.dart';
import '../models/expense.dart';
import '../models/split_detail.dart';
import '../services/database_service.dart';
import 'balance_provider.dart';

const _uuid = Uuid();

final monthlyExpensesProvider = StreamProvider<List<Expense>>((ref) async* {
  final isar = await DatabaseService.instance;
  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);
  final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
  yield* isar.expenses
      .filter()
      .dateBetween(startOfMonth, endOfMonth)
      .sortByDateDesc()
      .watch(fireImmediately: true);
});

final allExpensesProvider = StreamProvider<List<Expense>>((ref) async* {
  final isar = await DatabaseService.instance;
  yield* isar.expenses.where().sortByDateDesc().watch(fireImmediately: true);
});

final recentExpensesProvider = StreamProvider.family<List<Expense>, int>((ref, count) async* {
  final isar = await DatabaseService.instance;
  yield* isar.expenses.where().sortByDateDesc().limit(count).watch(fireImmediately: true);
});

final expenseNotifierProvider = AsyncNotifierProvider<ExpenseNotifier, void>(ExpenseNotifier.new);

class ExpenseNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> addExpense({
    required DateTime date,
    required String description,
    required double amount,
    required String category,
    required bool isShared,
    required SplitMethod splitMethod,
    required String payerId,
    required String payerName,
    required List<SplitDetail> splits,
    String? receiptPath,
    String? note,
    required String createdBy,
  }) async {
    final isar = await DatabaseService.instance;
    final groupId = await DatabaseService.getPrimaryGroupId();
    if (groupId == null) return;
    final now = DateTime.now();
    final expense = Expense()
      ..id = _uuid.v4()
      ..groupId = groupId
      ..date = date
      ..description = description
      ..amount = amount
      ..category = category
      ..isShared = isShared
      ..splitMethod = splitMethod
      ..payerId = payerId
      ..payerName = payerName
      ..splits = splits
      ..receiptPath = receiptPath
      ..note = note
      ..createdBy = createdBy
      ..createdAt = now
      ..updatedAt = now;
    await isar.writeTxn(() async {
      await isar.expenses.put(expense);
    });
    if (isShared) {
      await ref.read(balanceNotifierProvider.notifier).recalculate();
    }
  }

  Future<void> updateExpense(Expense expense) async {
    final isar = await DatabaseService.instance;
    expense.updatedAt = DateTime.now();
    await isar.writeTxn(() async {
      await isar.expenses.put(expense);
    });
    if (expense.isShared) {
      await ref.read(balanceNotifierProvider.notifier).recalculate();
    }
  }

  Future<void> deleteExpense(Expense expense) async {
    final isar = await DatabaseService.instance;
    final wasShared = expense.isShared;
    await isar.writeTxn(() async {
      await isar.expenses.delete(expense.isarId);
    });
    if (wasShared) {
      await ref.read(balanceNotifierProvider.notifier).recalculate();
    }
  }
}
