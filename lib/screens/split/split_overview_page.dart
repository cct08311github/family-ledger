import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:gap/gap.dart';
import '../../providers/balance_provider.dart';
import '../../providers/member_provider.dart';

class SplitOverviewPage extends ConsumerWidget {
  const SplitOverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final simplifiedDebts = ref.watch(simplifiedDebtsProvider);
    final netBalances = ref.watch(memberNetBalanceProvider);
    final members = ref.watch(membersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('拆帳總覽')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 每人淨餘額
          Card(child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.account_balance, color: theme.colorScheme.primary, size: 20),
                const Gap(8),
                Text('每人淨餘額', style: theme.textTheme.titleMedium),
              ]),
              const Gap(4),
              Text('正數 = 被欠（可收錢），負數 = 欠人（需還錢）',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5))),
              const Gap(16),
              netBalances.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('$e'),
                data: (balances) {
                  if (balances.isEmpty) {
                    return Text('目前沒有任何拆帳記錄', style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6)));
                  }
                  final memberList = members.valueOrNull ?? [];
                  final nameMap = {for (final m in memberList) m.id: m.name};
                  final sorted = balances.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
                  return Column(children: sorted.map((e) {
                    final name = nameMap[e.key] ?? e.key;
                    final isPositive = e.value >= 0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: isPositive
                              ? Colors.green.withOpacity(0.1)
                              : theme.colorScheme.error.withOpacity(0.1),
                          child: Text(name[0], style: TextStyle(
                              color: isPositive ? Colors.green : theme.colorScheme.error,
                              fontWeight: FontWeight.w600)),
                        ),
                        const Gap(12),
                        Expanded(child: Text(name, style: theme.textTheme.bodyLarge)),
                        Text(
                          '${isPositive ? '+' : ''}NT\$ ${NumberFormat('#,##0').format(e.value)}',
                          style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isPositive ? Colors.green : theme.colorScheme.error),
                        ),
                      ]),
                    );
                  }).toList());
                },
              ),
            ]),
          )),
          const Gap(16),
          // 簡化債務
          Card(child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.compress, color: theme.colorScheme.primary, size: 20),
                const Gap(8),
                Text('簡化結算', style: theme.textTheme.titleMedium),
              ]),
              const Gap(4),
              Text('最少轉帳次數即可結清所有債務',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5))),
              const Gap(16),
              simplifiedDebts.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('$e'),
                data: (debts) {
                  if (debts.isEmpty) {
                    return Text('所有人帳目已結清 🎉', style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6)));
                  }
                  return Column(children: debts.asMap().entries.map((entry) {
                    final i = entry.key;
                    final d = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary, shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: Text('${i + 1}', style: TextStyle(
                              color: theme.colorScheme.onPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                        const Gap(12),
                        Text(d['fromName'] as String, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                        const Gap(8),
                        const Icon(Icons.arrow_right_alt, size: 24),
                        const Gap(8),
                        Text(d['toName'] as String, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Text('NT\$ ${NumberFormat('#,##0').format(d['amount'])}',
                            style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                      ]),
                    );
                  }).toList());
                },
              ),
            ]),
          )),
        ],
      ),
    );
  }
}
