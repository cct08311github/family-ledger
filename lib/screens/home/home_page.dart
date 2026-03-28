import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:gap/gap.dart';
import '../../models/expense.dart';
import '../../providers/expense_provider.dart';
import '../../providers/member_provider.dart';
import '../../providers/balance_provider.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final monthlyExpenses = ref.watch(monthlyExpensesProvider);
    final recentExpenses = ref.watch(recentExpensesProvider(5));
    final members = ref.watch(membersProvider);
    final currentUser = ref.watch(currentUserProvider);
    final simplifiedDebts = ref.watch(simplifiedDebtsProvider);
    final monthLabel = DateFormat('yyyy年 M月', 'zh_TW').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('家計本'),
        actions: [
          currentUser.when(
            data: (user) => user != null
                ? TextButton.icon(
                    onPressed: () => _showUserSwitcher(context, ref),
                    icon: const Icon(Icons.person, size: 18),
                    label: Text(user.name),
                  )
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: members.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('錯誤：$e')),
        data: (memberList) {
          if (memberList.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.family_restroom, size: 80,
                        color: theme.colorScheme.primary.withOpacity(0.3)),
                    const Gap(24),
                    Text('歡迎使用家計本！', style: theme.textTheme.headlineSmall),
                    const Gap(8),
                    Text('請先到「設定」新增家庭成員',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        )),
                  ],
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _MonthlySummaryCard(
                  monthLabel: monthLabel,
                  expenses: monthlyExpenses.valueOrNull ?? []),
              const Gap(16),
              _DebtOverviewCard(debts: simplifiedDebts.valueOrNull ?? []),
              const Gap(16),
              _RecentExpensesCard(expenses: recentExpenses.valueOrNull ?? []),
            ],
          );
        },
      ),
    );
  }

  void _showUserSwitcher(BuildContext context, WidgetRef ref) {
    final members = ref.read(membersProvider).valueOrNull ?? [];
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('切換身份', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ),
            ...members.map((m) => ListTile(
                  leading: CircleAvatar(child: Text(m.name[0])),
                  title: Text(m.name),
                  trailing: m.isCurrentUser ? const Icon(Icons.check, color: Colors.green) : null,
                  onTap: () {
                    ref.read(memberNotifierProvider.notifier).switchUser(m.id);
                    Navigator.pop(ctx);
                  },
                )),
            const Gap(8),
          ],
        ),
      ),
    );
  }
}

class _MonthlySummaryCard extends StatelessWidget {
  final String monthLabel;
  final List<Expense> expenses;
  const _MonthlySummaryCard({required this.monthLabel, required this.expenses});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = expenses.fold<double>(0, (s, e) => s + e.amount);
    final sharedTotal = expenses.where((e) => e.isShared).fold<double>(0, (s, e) => s + e.amount);
    final personalTotal = total - sharedTotal;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.calendar_month, color: theme.colorScheme.primary, size: 20),
              const Gap(8),
              Text(monthLabel, style: theme.textTheme.titleMedium),
            ]),
            const Gap(16),
            Text('NT\$ ${NumberFormat('#,##0').format(total)}',
                style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
            const Gap(4),
            Text('本月總支出', style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6))),
            const Gap(16),
            Row(children: [
              Expanded(child: _MiniStat(label: '共同支出', value: 'NT\$ ${NumberFormat('#,##0').format(sharedTotal)}',
                  icon: Icons.people, color: theme.colorScheme.tertiary)),
              const Gap(12),
              Expanded(child: _MiniStat(label: '個人支出', value: 'NT\$ ${NumberFormat('#,##0').format(personalTotal)}',
                  icon: Icons.person, color: theme.colorScheme.secondary)),
            ]),
            const Gap(8),
            Text('共 ${expenses.length} 筆記錄', style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5))),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 14, color: color),
          const Gap(4),
          Text(label, style: theme.textTheme.labelSmall?.copyWith(color: color)),
        ]),
        const Gap(4),
        Text(value, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _DebtOverviewCard extends StatelessWidget {
  final List<Map<String, dynamic>> debts;
  const _DebtOverviewCard({required this.debts});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.account_balance_wallet, color: theme.colorScheme.primary, size: 20),
            const Gap(8),
            Text('誰欠誰', style: theme.textTheme.titleMedium),
          ]),
          const Gap(12),
          if (debts.isEmpty)
            Text('目前沒有未結清的債務 🎉', style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6)))
          else
            ...debts.map((d) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: theme.colorScheme.error.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text(d['fromName'] as String, style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                    const Gap(8),
                    Icon(Icons.arrow_forward, size: 16, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                    const Gap(8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text(d['toName'] as String, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                    const Spacer(),
                    Text('NT\$ ${NumberFormat('#,##0').format(d['amount'])}',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  ]),
                )),
        ]),
      ),
    );
  }
}

class _RecentExpensesCard extends StatelessWidget {
  final List<Expense> expenses;
  const _RecentExpensesCard({required this.expenses});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.history, color: theme.colorScheme.primary, size: 20),
            const Gap(8),
            Text('最近記錄', style: theme.textTheme.titleMedium),
          ]),
          const Gap(12),
          if (expenses.isEmpty)
            Text('還沒有任何記錄，點下方「記帳」開始！', style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6)))
          else
            ...expenses.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(10)),
                      alignment: Alignment.center,
                      child: Text(e.isShared ? '👥' : '👤', style: const TextStyle(fontSize: 18)),
                    ),
                    const Gap(12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(e.description, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                      Text('${DateFormat('MM/dd').format(e.date)} · ${e.category} · ${e.payerName}付',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.5))),
                    ])),
                    Text('NT\$ ${NumberFormat('#,##0').format(e.amount)}',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  ]),
                )),
        ]),
      ),
    );
  }
}
