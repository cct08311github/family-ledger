import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:gap/gap.dart';
import '../../models/expense.dart';
import '../../providers/expense_provider.dart';
import '../../utils/formatters.dart';
import '../expense/expense_form_page.dart';

class RecordsPage extends ConsumerStatefulWidget {
  const RecordsPage({super.key});
  @override
  ConsumerState<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends ConsumerState<RecordsPage> {
  String _filterType = '全部'; // 全部 / 共同 / 個人

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allExpenses = ref.watch(allExpensesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('所有記錄'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (v) => setState(() => _filterType = v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: '全部', child: Text('全部')),
              const PopupMenuItem(value: '共同', child: Text('共同支出')),
              const PopupMenuItem(value: '個人', child: Text('個人支出')),
            ],
          ),
        ],
      ),
      body: allExpenses.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (expenses) {
          var filtered = expenses;
          if (_filterType == '共同') filtered = filtered.where((e) => e.isShared).toList();
          if (_filterType == '個人') filtered = filtered.where((e) => !e.isShared).toList();

          if (filtered.isEmpty) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.receipt_long_outlined, size: 64,
                  color: theme.colorScheme.primary.withValues(alpha: 0.3)),
              const Gap(16),
              Text('沒有記錄', style: theme.textTheme.titleMedium),
            ]));
          }

          // 按日期分組
          final Map<String, List<Expense>> grouped = {};
          for (final e in filtered) {
            final key = DateFormat('yyyy/MM/dd (E)', 'zh_TW').format(e.date);
            grouped.putIfAbsent(key, () => []).add(e);
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: grouped.length,
            itemBuilder: (context, index) {
              final dateKey = grouped.keys.elementAt(index);
              final items = grouped[dateKey]!;
              final dayTotal = items.fold<double>(0, (s, e) => s + e.amount);

              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    Text(dateKey, style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary)),
                    const Spacer(),
                    Text(Formatters.currency(dayTotal),
                        style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                  ]),
                ),
                ...items.map((e) => Slidable(
                      startActionPane: ActionPane(motion: const DrawerMotion(), children: [
                        SlidableAction(
                          onPressed: (_) => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => ExpenseFormPage(existingExpense: e))),
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          icon: Icons.edit,
                          label: '編輯',
                          borderRadius: BorderRadius.circular(12),
                        ),
                        SlidableAction(
                          onPressed: (_) => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => ExpenseFormPage(duplicateFrom: e))),
                          backgroundColor: theme.colorScheme.tertiary,
                          foregroundColor: theme.colorScheme.onTertiary,
                          icon: Icons.copy,
                          label: '複製',
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ]),
                      endActionPane: ActionPane(motion: const DrawerMotion(), children: [
                        SlidableAction(
                          onPressed: (_) => _confirmDelete(e),
                          backgroundColor: theme.colorScheme.error,
                          foregroundColor: theme.colorScheme.onError,
                          icon: Icons.delete,
                          label: '刪除',
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ]),
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => ExpenseFormPage(existingExpense: e))),
                          leading: Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(10)),
                            alignment: Alignment.center,
                            child: Text(e.isShared ? '👥' : '👤', style: const TextStyle(fontSize: 18)),
                          ),
                          title: Text(e.description),
                          subtitle: Row(children: [
                            Expanded(child: Text('${e.category} · ${e.payerName}付${e.isShared ? ' · 共同' : ''}')),
                            if (e.receiptPath != null) GestureDetector(
                              onTap: () => _viewReceipt(e.receiptPath!),
                              child: Icon(Icons.receipt_long, size: 16,
                                  color: theme.colorScheme.primary.withValues(alpha: 0.7)),
                            ),
                          ]),
                          trailing: Text(Formatters.currency(e.amount),
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    )),
                const Gap(8),
              ]);
            },
          );
        },
      ),
    );
  }

  void _viewReceipt(String path) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: Colors.white,
            title: const Text('收據照片')),
        body: Center(child: InteractiveViewer(
          child: Image.file(File(path)),
        )),
      ),
    ));
  }

  void _confirmDelete(Expense expense) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('刪除支出'),
      content: Text('確定要刪除「${expense.description}」嗎？'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        FilledButton(
          onPressed: () {
            Navigator.pop(ctx);
            ref.read(expenseNotifierProvider.notifier).deleteExpense(expense);
          },
          style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
          child: const Text('刪除'),
        ),
      ],
    ));
  }
}
