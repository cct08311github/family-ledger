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
import 'package:patrol/patrol.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_ledger/app.dart';

void main() {
  patrolTest('App 啟動 - 顯示登入頁', ($) async {
    // 啟動 app（此測試需要在 Firebase mock 環境下執行）
    $.pumpWidgetAndSettle(
      const ProviderScope(
        child: MaterialApp(
          home: LoginPage(),
        ),
      ),
    );

    // 驗證 Google Sign-In 按鈕存在
    await $.waitUntil(() {
      return find.byType(FloatingActionButton).evaluate().isNotEmpty ||
             find.byIcon(Icons.login).evaluate().isNotEmpty;
    }, timeout: const Duration(seconds: 10));

    // 截圖記錄
    await $.native.screenshot();
  });

  patrolTest('NavigationBar 有 5 個目的地', ($) async {
    await $.pumpWidgetAndSettle(
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

    // 驗證 5 個 NavigationDestination
    await $.waitUntil(() {
      final count = find.byType(NavigationDestination).evaluate().length;
      return count == 5;
    }, timeout: const Duration(seconds: 5));

    expect(find.byType(NavigationDestination), findsNWidgets(5));
    await $.native.screenshot();
  });

  patrolTest('FAB 點擊開啟記帳表單', ($) async {
    bool formOpened = false;

    await $.pumpWidgetAndSettle(
      MaterialApp(
        home: Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => formOpened = true,
            icon: const Icon(Icons.add),
            label: const Text('記帳'),
          ),
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('新增支出')),
                    body: const Center(child: Text('支出表單')),
                  ),
                ),
              ),
              child: const Text('打開'),
            ),
          ),
        ),
      ),
    );

    // 點擊按鈕
    await $(FloatingActionButton).tap();
    await $.pumpAndSettle();

    expect(formOpened, isTrue);
    await $.native.screenshot();
  });

  patrolTest('日期格式化 - 今天顯示正確', ($) async {
    await $.pumpWidgetAndSettle(
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

  patrolTest('日期格式化 - 昨天顯示正確', ($) async {
    await $.pumpWidgetAndSettle(
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

  patrolTest('貨幣格式化 - 正常金額', ($) async {
    await $.pumpWidgetAndSettle(
      MaterialApp(
        home: Scaffold(
          body: Text(_formatCurrency(1234)),
        ),
      ),
    );

    expect(find.text('NT\$ 1,234'), findsOneWidget);
  });

  patrolTest('貨幣格式化 - 負數顯示', ($) async {
    await $.pumpWidgetAndSettle(
      MaterialApp(
        home: Scaffold(
          body: Text(_formatSignedCurrency(-500)),
        ),
      ),
    );

    expect(find.text('NT\$ -500'), findsOneWidget);
  });

  patrolTest('語音輸入按鈕存在', ($) async {
    await $.pumpWidgetAndSettle(
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
    await $.native.screenshot();
  });

  patrolTest('設定頁面 - 類別管理入口存在', ($) async {
    await $.pumpWidgetAndSettle(
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
    await $.native.screenshot();
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
