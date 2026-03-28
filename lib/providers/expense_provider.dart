import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';
import '../models/enums.dart';
import '../models/expense.dart';
import '../models/split_detail.dart';
import '../services/database_service.dart';
import '../services/image_storage_service.dart';
import 'balance_provider.dart';
import 'activity_log_provider.dart';

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

/// 最近 200 筆不重複描述（依時間排序，最新在前）
final recentDescriptionsProvider = FutureProvider<List<String>>((ref) async {
  final isar = await DatabaseService.instance;
  final expenses = await isar.expenses.where().sortByDateDesc().limit(200).findAll();
  final seen = <String>{};
  return expenses
      .map((e) => e.description)
      .where((d) => d.isNotEmpty && seen.add(d))
      .toList();
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
    await ActivityLogger.log(
      action: 'expense_add',
      actorName: payerName, actorId: payerId,
      description: '$payerName 新增支出「$description」NT\$ ${amount.toStringAsFixed(0)}',
      entityId: expense.id,
    );
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
    await ActivityLogger.log(
      action: 'expense_edit',
      actorName: expense.payerName, actorId: expense.payerId,
      description: '${expense.payerName} 編輯支出「${expense.description}」',
      entityId: expense.id,
    );
    if (expense.isShared) {
      await ref.read(balanceNotifierProvider.notifier).recalculate();
    }
  }

  Future<void> deleteExpense(Expense expense) async {
    final isar = await DatabaseService.instance;
    final wasShared = expense.isShared;
    final receiptPath = expense.receiptPath;
    await isar.writeTxn(() async {
      await isar.expenses.delete(expense.isarId);
    });
    if (receiptPath != null) {
      await ImageStorageService.deleteReceipt(receiptPath);
    }
    await ActivityLogger.log(
      action: 'expense_delete',
      actorName: expense.payerName, actorId: expense.payerId,
      description: '刪除支出「${expense.description}」NT\$ ${expense.amount.toStringAsFixed(0)}',
      entityId: expense.id,
    );
    if (wasShared) {
      await ref.read(balanceNotifierProvider.notifier).recalculate();
    }
  }
}
