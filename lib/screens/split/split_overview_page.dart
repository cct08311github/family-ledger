import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../providers/balance_provider.dart';
import '../../providers/member_provider.dart';
import '../../providers/settlement_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/member_avatar.dart';

class SplitOverviewPage extends ConsumerStatefulWidget {
  const SplitOverviewPage({super.key});

  @override
  ConsumerState<SplitOverviewPage> createState() => _SplitOverviewPageState();
}

class _SplitOverviewPageState extends ConsumerState<SplitOverviewPage> {
  void _showSettlementDialog(Map<String, dynamic> debt) {
    final amountController = TextEditingController(
      text: (debt['amount'] as num).toStringAsFixed(0),
    );
    final noteController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('記錄付款', style: theme.textTheme.titleLarge),
            const Gap(16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              MemberAvatar(name: debt['fromName'] as String, size: 40),
              const Gap(8),
              Text(debt['fromName'] as String,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const Gap(12),
              const Icon(Icons.arrow_right_alt, size: 28),
              const Gap(12),
              MemberAvatar(name: debt['toName'] as String, size: 40),
              const Gap(8),
              Text(debt['toName'] as String,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            ]),
            const Gap(20),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '金額',
                prefixText: 'NT\$ ',
                border: OutlineInputBorder(),
              ),
            ),
            const Gap(12),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: '備註（選填）',
                border: OutlineInputBorder(),
              ),
            ),
            const Gap(20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  final amount = double.tryParse(amountController.text);
                  if (amount == null || amount <= 0) return;
                  try {
                    await ref.read(settlementNotifierProvider.notifier).addSettlement(
                      fromMemberId: debt['from'] as String,
                      fromMemberName: debt['fromName'] as String,
                      toMemberId: debt['to'] as String,
                      toMemberName: debt['toName'] as String,
                      amount: amount,
                      note: noteController.text.isEmpty ? null : noteController.text,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('付款記錄失敗：$e'), behavior: SnackBarBehavior.floating),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.check),
                label: const Text('確認付款'),
              ),
            ),
          ]),
        );
      },
    ).whenComplete(() {
      amountController.dispose();
      noteController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
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
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
              const Gap(16),
              netBalances.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('$e'),
                data: (balances) {
                  if (balances.isEmpty) {
                    return Text('目前沒有任何拆帳記錄', style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6)));
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
                        MemberAvatar(name: name, size: 36),
                        const Gap(12),
                        Expanded(child: Text(name, style: theme.textTheme.bodyLarge)),
                        Text(
                          Formatters.signedCurrency(e.value),
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
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
              const Gap(16),
              simplifiedDebts.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('$e'),
                data: (debts) {
                  if (debts.isEmpty) {
                    return Text('所有人帳目已結清 🎉', style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6)));
                  }
                  return Column(children: debts.asMap().entries.map((entry) {
                    final i = entry.key;
                    final d = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(children: [
                        Row(children: [
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
                          Expanded(
                            child: Text(d['toName'] as String, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                          ),
                          Text(Formatters.currency(d['amount'] as num),
                              style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                        ]),
                        const Gap(8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _showSettlementDialog(d),
                            icon: const Icon(Icons.payments_outlined, size: 18),
                            label: const Text('記錄付款'),
                          ),
                        ),
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
