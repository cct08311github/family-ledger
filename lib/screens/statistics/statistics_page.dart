import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:gap/gap.dart';
import '../../utils/formatters.dart';
import '../../models/enums.dart';
import '../../providers/expense_provider.dart';


class StatisticsPage extends ConsumerWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final monthlyExpenses = ref.watch(monthlyExpensesProvider);
    final monthLabel = DateFormat('yyyy年 M月', 'zh_TW').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text('統計報表')),
      body: monthlyExpenses.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (expenses) {
          if (expenses.isEmpty) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.bar_chart_outlined, size: 64,
                  color: theme.colorScheme.primary.withValues(alpha:0.3)),
              const Gap(16),
              Text('本月還沒有記錄', style: theme.textTheme.titleMedium),
            ]));
          }

          // 類別統計
          final Map<String, double> categoryTotals = {};
          for (final e in expenses) {
            categoryTotals[e.category] = (categoryTotals[e.category] ?? 0) + e.amount;
          }
          final sortedCats = categoryTotals.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          final total = expenses.fold<double>(0, (s, e) => s + e.amount);

          // 每人貢獻（付款金額）
          final Map<String, double> payerTotals = {};
          for (final e in expenses) {
            payerTotals[e.payerName] = (payerTotals[e.payerName] ?? 0) + e.amount;
          }

          final colors = [
            theme.colorScheme.primary,
            theme.colorScheme.secondary,
            theme.colorScheme.tertiary,
            Colors.orange,
            Colors.purple,
            Colors.teal,
            Colors.pink,
            Colors.indigo,
            Colors.amber,
            Colors.cyan,
            Colors.lime,
            Colors.brown,
          ];

          return ListView(padding: const EdgeInsets.all(16), children: [
            Text(monthLabel, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const Gap(16),
            // 類別圓餅圖
            Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('各類別花費', style: theme.textTheme.titleMedium),
                const Gap(16),
                SizedBox(height: 200, child: PieChart(PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: sortedCats.asMap().entries.map((entry) {
                    final i = entry.key;
                    final cat = entry.value;
                    final pct = cat.value / total * 100;
                    return PieChartSectionData(
                      color: colors[i % colors.length],
                      value: cat.value,
                      title: '${pct.toStringAsFixed(0)}%',
                      radius: 50,
                      titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                    );
                  }).toList(),
                ))),
                const Gap(16),
                // 圖例
                Wrap(spacing: 16, runSpacing: 8, children: sortedCats.asMap().entries.map((entry) {
                  final i = entry.key;
                  final cat = entry.value;
                  final icon = DefaultCategories.icons[cat.key] ?? '📌';
                  return Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 12, height: 12,
                        decoration: BoxDecoration(color: colors[i % colors.length], borderRadius: BorderRadius.circular(3))),
                    const Gap(4),
                    Text('$icon ${cat.key}', style: theme.textTheme.bodySmall),
                    const Gap(4),
                    Text(Formatters.currency(cat.value),
                        style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                  ]);
                }).toList()),
              ],
            ))),
            const Gap(16),
            // 每人付款柱狀圖
            Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('每人付款金額', style: theme.textTheme.titleMedium),
                const Gap(16),
                ...payerTotals.entries.map((e) {
                  final ratio = total > 0 ? e.value / total : 0.0;
                  return Padding(padding: const EdgeInsets.only(bottom: 12), child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(e.key, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                        const Spacer(),
                        Text(Formatters.currency(e.value),
                            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                      ]),
                      const Gap(4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 8,
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ));
                }),
              ],
            ))),
            const Gap(16),
            // 類別排行
            Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('類別排行', style: theme.textTheme.titleMedium),
                const Gap(12),
                ...sortedCats.asMap().entries.map((entry) {
                  final i = entry.key;
                  final cat = entry.value;
                  final icon = DefaultCategories.icons[cat.key] ?? '📌';
                  return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
                    SizedBox(width: 24, child: Text('${i + 1}',
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary))),
                    const Gap(8),
                    Text('$icon ${cat.key}', style: theme.textTheme.bodyMedium),
                    const Spacer(),
                    Text(Formatters.currency(cat.value),
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const Gap(8),
                    Text('${(cat.value / total * 100).toStringAsFixed(0)}%',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha:0.5))),
                  ]));
                }),
              ],
            ))),
          ]);
        },
      ),
    );
  }
}
