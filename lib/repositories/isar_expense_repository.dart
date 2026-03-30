// Isar Expense Repository Implementation - 家庭記帳 App
//
// Isar 本地資料庫的 Expense 實作

import 'package:isar/isar.dart';
import '../models/expense.dart';
import 'expense_repository.dart';

class IsarExpenseRepository implements ExpenseRepository {
  final Isar _isar;

  IsarExpenseRepository(this._isar);

  @override
  Stream<List<Expense>> watchAllExpenses() {
    return _isar.expenses.where().sortByDateDesc().watch(fireImmediately: true);
  }

  @override
  Stream<List<Expense>> watchMonthlyExpenses({int? year, int? month}) {
    final now = DateTime.now();
    final startOfMonth = DateTime(year ?? now.year, month ?? now.month, 1);
    final endOfMonth = DateTime(year ?? now.year, month ?? now.month + 1, 0, 23, 59, 59);
    return _isar.expenses
        .filter()
        .dateBetween(startOfMonth, endOfMonth)
        .sortByDateDesc()
        .watch(fireImmediately: true);
  }

  @override
  Stream<List<Expense>> watchRecentExpenses(int count) {
    return _isar.expenses.where().sortByDateDesc().limit(count).watch(fireImmediately: true);
  }

  @override
  Future<Expense?> getExpenseById(String id) {
    return _isar.expenses.filter().idEqualTo(id).findFirst();
  }

  @override
  Future<List<Expense>> getExpensesByGroupId(String groupId) {
    return _isar.expenses.filter().groupIdEqualTo(groupId).sortByDateDesc().findAll();
  }

  @override
  Future<void> addExpense(Expense expense) async {
    await _isar.writeTxn(() async {
      await _isar.expenses.put(expense);
    });
  }

  @override
  Future<void> updateExpense(Expense expense) async {
    expense.updatedAt = DateTime.now();
    await _isar.writeTxn(() async {
      await _isar.expenses.put(expense);
    });
  }

  @override
  Future<void> deleteExpense(int isarId) async {
    await _isar.writeTxn(() async {
      await _isar.expenses.delete(isarId);
    });
  }

  @override
  Future<void> deleteExpensesByGroupId(String groupId) async {
    await _isar.writeTxn(() async {
      await _isar.expenses.filter().groupIdEqualTo(groupId).deleteAll();
    });
  }

  @override
  Future<List<String>> searchRecentDescriptions({int limit = 200}) async {
    final expenses = await _isar.expenses
        .where()
        .sortByDateDesc()
        .limit(limit)
        .findAll();
    final seen = <String>{};
    return expenses
        .map((e) => e.description)
        .where((d) => d.isNotEmpty && seen.add(d))
        .toList();
  }
}
