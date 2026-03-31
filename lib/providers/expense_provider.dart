import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/enums.dart';
import '../models/expense.dart';
import '../models/split_detail.dart';
import '../services/firestore_service.dart';
import '../services/image_storage_service.dart';
import 'balance_provider.dart';
import 'activity_log_provider.dart';
import 'notification_provider.dart';
import '../services/receipt_storage_service.dart';
import 'member_provider.dart';

final monthlyExpensesProvider = StreamProvider<List<Expense>>((ref) async* {
  final group = await ref.watch(currentGroupProvider.future);
  if (group == null) {
    yield [];
    return;
  }
  final now = DateTime.now();
  yield* FirestoreService.watchMonthlyExpenses(group.id, now.year, now.month);
});

final allExpensesProvider = StreamProvider<List<Expense>>((ref) async* {
  final group = await ref.watch(currentGroupProvider.future);
  if (group == null) {
    yield [];
    return;
  }
  yield* FirestoreService.watchExpenses(group.id);
});

final recentExpensesProvider = StreamProvider.family<List<Expense>, int>((ref, count) async* {
  final all = await ref.watch(allExpensesProvider.future);
  yield all.take(count).toList();
});

/// 最近 200 筆不重複描述（依時間排序，最新在前）
final recentDescriptionsProvider = FutureProvider<List<String>>((ref) async {
  final all = await ref.watch(allExpensesProvider.future);
  final seen = <String>{};
  return all
      .take(200)
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
    List<String> receiptPaths = const [],
    PaymentMethod paymentMethod = PaymentMethod.cash,
    String? note,
    required String createdBy,
  }) async {
    final group = await ref.read(currentGroupProvider.future);
    if (group == null) return;
    final now = DateTime.now();
    final expense = Expense()
      ..groupId = group.id
      ..date = date
      ..description = description
      ..amount = amount
      ..category = category
      ..isShared = isShared
      ..splitMethod = splitMethod
      ..payerId = payerId
      ..payerName = payerName
      ..splits = splits
      ..paymentMethod = paymentMethod
      ..receiptPath = receiptPath
      ..receiptPaths = receiptPaths
      ..note = note
      ..createdBy = createdBy
      ..createdAt = now
      ..updatedAt = now;
    final expenseId = await FirestoreService.addExpense(expense);
    expense.id = expenseId;
    await ActivityLogger.log(
      action: 'expense_add',
      actorName: payerName, actorId: payerId,
      description: '$payerName 新增支出「$description」NT\$ ${amount.toStringAsFixed(0)}',
      entityId: expenseId,
      groupId: group.id,
    );
    // 收據照片上傳到 Firebase Storage（本機路徑→URL）
    if (receiptPaths.isNotEmpty) {
      final urls = await ReceiptStorageService.uploadAll(
        localPaths: receiptPaths,
        groupId: group.id,
        expenseId: expenseId,
      );
      if (urls.any((u) => u.startsWith('http'))) {
        expense.id = expenseId;
        expense.receiptPaths = urls;
        expense.receiptPath = urls.first;
        await FirestoreService.updateExpense(expense);
      }
    }
    if (isShared) {
      await NotificationService.notifySplitExpense(
        groupId: group.id,
        expenseId: expenseId,
        payerName: payerName,
        description: description,
        amount: amount,
        participants: splits
            .where((s) => s.isParticipant)
            .map((s) => (memberId: s.memberId, memberName: s.memberName, shareAmount: s.shareAmount))
            .toList(),
        payerId: payerId,
      );
      await ref.read(balanceNotifierProvider.notifier).recalculate();
    }
  }

  Future<void> updateExpense(Expense expense) async {
    expense.updatedAt = DateTime.now();
    await FirestoreService.updateExpense(expense);
    await ActivityLogger.log(
      action: 'expense_edit',
      actorName: expense.payerName, actorId: expense.payerId,
      description: '${expense.payerName} 編輯支出「${expense.description}」',
      entityId: expense.id,
      groupId: expense.groupId,
    );
    // 上傳新增的本機照片
    if (expense.receiptPaths.isNotEmpty) {
      final urls = await ReceiptStorageService.uploadAll(
        localPaths: expense.receiptPaths,
        groupId: expense.groupId,
        expenseId: expense.id,
      );
      if (urls.any((u) => u.startsWith('http'))) {
        expense.receiptPaths = urls;
        expense.receiptPath = urls.isNotEmpty ? urls.first : null;
        await FirestoreService.updateExpense(expense);
      }
    }
    if (expense.isShared) {
      await ref.read(balanceNotifierProvider.notifier).recalculate();
    }
  }

  Future<void> deleteExpense(Expense expense) async {
    final wasShared = expense.isShared;
    await FirestoreService.deleteExpense(expense.groupId, expense.id);
    // 刪除本機收據
    for (final path in expense.receiptPaths) {
      if (!path.startsWith('http')) {
        await ImageStorageService.deleteReceipt(path);
      }
    }
    if (expense.receiptPath != null && !expense.receiptPath!.startsWith('http')) {
      await ImageStorageService.deleteReceipt(expense.receiptPath!);
    }
    // 刪除 Firebase Storage 收據
    ReceiptStorageService.deleteAll(
      groupId: expense.groupId, expenseId: expense.id,
    );
    await ActivityLogger.log(
      action: 'expense_delete',
      actorName: expense.payerName, actorId: expense.payerId,
      description: '刪除支出「${expense.description}」NT\$ ${expense.amount.toStringAsFixed(0)}',
      entityId: expense.id,
      groupId: expense.groupId,
    );
    if (wasShared) {
      await ref.read(balanceNotifierProvider.notifier).recalculate();
    }
  }
}
