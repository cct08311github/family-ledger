// Repository Providers - 家庭記帳 App
//
// 將所有 Repository 介面綁定到 Riverpod Provider
// 支援依賴注入和單元測試 mock

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../services/database_service.dart';
import 'expense_repository.dart';
import 'isar_expense_repository.dart';

/// Isar 資料庫實例 Provider
final isarProvider = FutureProvider<Isar>((ref) async {
  return await DatabaseService.instance;
});

/// Expense Repository Provider
/// 使用 IsarExpenseRepository 作為實作
final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  final isarAsync = ref.watch(isarProvider);
  return isarAsync.when(
        data: (isar) => IsarExpenseRepository(isar),
        loading: () => throw StateError('Isar not initialized yet'),
        error: (e, _) => throw StateError('Isar init failed: $e'),
      );
});

/// Expense Repository Stream Provider（用於需持续监听的场景）
final expenseRepositoryStreamProvider = StreamProvider<ExpenseRepository>((ref) async* {
  final isar = await DatabaseService.instance;
  yield IsarExpenseRepository(isar);
});
