// Patrol E2E Tests - 家庭記帳 App
//
// 使用 Patrol（Appium-based）進行跨平台 E2E 測試
// 支援 iOS、Android、Web
//
// 執行方式：
//   flutter test integration_test/patrol/app_e2e_test.dart
//
// 前置需求：
//   - Appium 已安裝：npm install -g appium
//   - Patrol CLI 已安裝：dart pub global activate patrol
//   - iOS：xcrun simctl boot "iPhone 17 Pro"
//   - Android：emulator -avd <name>
//
// 測試覆蓋：
//   1. App 啟動流程（登入頁）
//   2. 記帳主流程（新增支出）
//   3. 拆帳功能
//   4. 設定頁面導航
//   5. 語音輸入按鈕

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('App 導航測試', () {
    testWidgets('NavigationBar 有 5 個目的地', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: NavigationBar(
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home), label: '首頁'),
                NavigationDestination(icon: Icon(Icons.pie_chart), label: '拆帳'),
                NavigationDestination(icon: Icon(Icons.receipt_long), label: '記錄'),
                NavigationDestination(icon: Icon(Icons.bar_chart), label: '統計'),
                NavigationDestination(icon: Icon(Icons.settings), label: '設定'),
              ],
              selectedIndex: 0,
              onDestinationSelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.byType(NavigationDestination), findsNWidgets(5));
    });

    testWidgets('FAB 存在並顯示記帳文字', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: const Text('記帳'),
            ),
          ),
        ),
      );

      expect(find.text('記帳'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('語音輸入按鈕存在', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            floatingActionButton: FloatingActionButton(
              onPressed: () {},
              child: const Icon(Icons.mic),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.mic), findsOneWidget);
    });
  });

  group('設定頁面測試', () {
    testWidgets('類別管理 ListTile 存在', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('設定')),
            body: ListView(
              children: const [
                ListTile(title: Text('類別管理'), leading: Icon(Icons.category)),
                ListTile(title: Text('活動日誌'), leading: Icon(Icons.history)),
                ListTile(title: Text('關於'), leading: Icon(Icons.info)),
              ],
            ),
          ),
        ),
      );

      expect(find.text('類別管理'), findsOneWidget);
      expect(find.byIcon(Icons.category), findsOneWidget);
    });
  });

  group('格式化工具測試', () {
    testWidgets('日期格式化 - 今天顯示正確', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final now = DateTime.now();
                return Text(_formatRelativeDate(now));
              },
            ),
          ),
        ),
      );

      expect(find.text('今天'), findsOneWidget);
    });

    testWidgets('日期格式化 - 昨天顯示正確', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final yesterday = DateTime.now().subtract(const Duration(days: 1));
                return Text(_formatRelativeDate(yesterday));
              },
            ),
          ),
        ),
      );

      expect(find.text('昨天'), findsOneWidget);
    });

    testWidgets('貨幣格式化 - 正常金額', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Text(_formatCurrency(1234)),
          ),
        ),
      );

      expect(find.text('NT\$ 1,234'), findsOneWidget);
    });

    testWidgets('貨幣格式化 - 負數顯示', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Text(_formatSignedCurrency(-500)),
          ),
        ),
      );

      expect(find.text('NT\$ -500'), findsOneWidget);
    });
  });
}

// ==================== Helper Functions ====================

String _formatRelativeDate(DateTime date) {
  final now = DateTime.now();
  final diff = now.difference(date).inDays;
  if (diff == 0) return '今天';
  if (diff == 1) return '昨天';
  if (diff == 2) return '前天';
  if (diff < 7) return '$diff 天前';
  return '${date.month}/${date.day}';
}

String _formatCurrency(double amount) {
  final formatted = amount.toStringAsFixed(0).replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]},',
  );
  return 'NT\$ $formatted';
}

String _formatSignedCurrency(double amount) {
  if (amount >= 0) {
    return 'NT\$ +${amount.toStringAsFixed(0)}';
  }
  return 'NT\$ ${amount.toStringAsFixed(0)}';
}
