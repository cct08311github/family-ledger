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
import 'notification_provider.dart';
import '../services/firebase_sync_service.dart';
import '../services/receipt_storage_service.dart';

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
    List<String> receiptPaths = const [],
    PaymentMethod paymentMethod = PaymentMethod.cash,
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
      ..paymentMethod = paymentMethod
      ..receiptPath = receiptPath
      ..receiptPaths = receiptPaths
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
    // 收據照片上傳到 Firebase Storage（本機路徑→URL）
    if (FirebaseSyncService.isSignedIn && receiptPaths.isNotEmpty) {
      final urls = await ReceiptStorageService.uploadAll(
        localPaths: receiptPaths,
        groupId: groupId,
        expenseId: expense.id,
      );
      if (urls.any((u) => u.startsWith('http'))) {
        expense.receiptPaths = urls;
        expense.receiptPath = urls.first;
        await isar.writeTxn(() async { await isar.expenses.put(expense); });
      }
    }
    // Firebase 同步（忽略失敗，本地優先）
    if (FirebaseSyncService.isSignedIn) {
      FirebaseSyncService.syncExpenseUp(groupId, expense).catchError((_) {});
    }
    if (isShared) {
      await NotificationService.notifySplitExpense(
        expenseId: expense.id,
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
    // 上傳新增的本機照片
    if (FirebaseSyncService.isSignedIn && expense.receiptPaths.isNotEmpty) {
      final urls = await ReceiptStorageService.uploadAll(
        localPaths: expense.receiptPaths,
        groupId: expense.groupId,
        expenseId: expense.id,
      );
      if (urls.any((u) => u.startsWith('http'))) {
        expense.receiptPaths = urls;
        expense.receiptPath = urls.isNotEmpty ? urls.first : null;
        await isar.writeTxn(() async { await isar.expenses.put(expense); });
      }
    }
    if (FirebaseSyncService.isSignedIn) {
      final gid = expense.groupId;
      FirebaseSyncService.syncExpenseUp(gid, expense).catchError((_) {});
    }
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
    if (FirebaseSyncService.isSignedIn) {
      ReceiptStorageService.deleteAll(
        groupId: expense.groupId, expenseId: expense.id,
      ).catchError((_) {});
    }
    await ActivityLogger.log(
      action: 'expense_delete',
      actorName: expense.payerName, actorId: expense.payerId,
      description: '刪除支出「${expense.description}」NT\$ ${expense.amount.toStringAsFixed(0)}',
      entityId: expense.id,
    );
    if (FirebaseSyncService.isSignedIn) {
      FirebaseSyncService.deleteExpenseRemote(expense.groupId, expense.id).catchError((_) {});
    }
    if (wasShared) {
      await ref.read(balanceNotifierProvider.notifier).recalculate();
    }
  }
}
