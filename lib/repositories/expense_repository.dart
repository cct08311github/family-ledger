// Expense Repository Interface - 家庭記帳 App
//
// 定義 Expense 資料的抽象介面，支援本地 Isar 和遠端 Firestore

import '../models/expense.dart';

/// Expense 資料存取介面
abstract class ExpenseRepository {
  /// 取得所有支出（依日期降序）
  Stream<List<Expense>> watchAllExpenses();

  /// 取得本月支出（依日期降序）
  Stream<List<Expense>> watchMonthlyExpenses({int? year, int? month});

  /// 取得最近 N 筆支出
  Stream<List<Expense>> watchRecentExpenses(int count);

  /// 依 ID 取得支出
  Future<Expense?> getExpenseById(String id);

  /// 依群組 ID 取得所有支出
  Future<List<Expense>> getExpensesByGroupId(String groupId);

  /// 新增支出
  Future<void> addExpense(Expense expense);

  /// 更新支出
  Future<void> updateExpense(Expense expense);

  /// 刪除支出
  Future<void> deleteExpense(int isarId);

  /// 批次刪除支出（依群組）
  Future<void> deleteExpensesByGroupId(String groupId);

  /// 搜尋支出描述（自動完成用）
  Future<List<String>> searchRecentDescriptions({int limit = 200});
}
