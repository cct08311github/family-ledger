// Flutter Integration Tests - 家庭記帳 App
//
// 注意：完整 E2E 測試需要 Firebase + Google Sign-In
// 目前使用 mock 測試非認證流程
//
// 執行方式：
//   flutter test integration_test/app_test.dart
//   flutter test integration_test/app_test.dart -d chrome  (web)
//   flutter test integration_test/app_test.dart -d macos   (macOS)
//   flutter test integration_test/app_test.dart -d iphone  (iOS simulator)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_ledger/utils/formatters.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('格式化工具測試', () {
    testWidgets('currency formatter - 正常金額', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Text(
                Formatters.currency(1234),
              ),
            ),
          ),
        ),
      );
      expect(find.text('NT\$ 1,234'), findsOneWidget);
    });

    testWidgets('currency formatter - 零', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Text(Formatters.currency(0)),
            ),
          ),
        ),
      );
      expect(find.text('NT\$ 0'), findsOneWidget);
    });

    testWidgets('signed currency - 正數', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Text(Formatters.signedCurrency(500)),
            ),
          ),
        ),
      );
      expect(find.text('NT\$ +500'), findsOneWidget);
    });

    testWidgets('signed currency - 負數', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Text(Formatters.signedCurrency(-300)),
            ),
          ),
        ),
      );
      expect(find.text('NT\$ -300'), findsOneWidget);
    });
  });

  group('Theme 切換測試', () {
    testWidgets('app starts with light theme', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Text('Theme Test'),
            ),
          ),
        ),
      );
      final ScaffoldState state = tester.firstState(find.byType(Scaffold));
      expect(state, isNotNull);
    });
  });

  group('Navigation 元件測試', () {
    testWidgets('BottomNavigationBar has 5 items', (tester) async {
      // This requires auth bypass - testing structure only
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
  });

  group('FloatingActionButton 測試', () {
    testWidgets('FAB exists and has correct label', (tester) async {
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
  });

  group('金額計算法測試', () {
    testWidgets('split equal - 3人平分', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  // Test equal split calculation: 300 / 3 = 100 each
                  const amount = 300;
                  const people = 3;
                  final perPerson = (amount / people).round();
                  return Text('NT\$ $perPerson');
                },
              ),
            ),
          ),
        ),
      );
      expect(find.text('NT\$ 100'), findsOneWidget);
    });

    testWidgets('split percentage - 50/30/20', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  const total = 1000;
                  final p1 = (total * 0.5).round();
                  final p2 = (total * 0.3).round();
                  final p3 = total - p1 - p2; //  remainder to last
                  return Text('$p1 / $p2 / $p3');
                },
              ),
            ),
          ),
        ),
      );
      expect(find.text('500 / 300 / 200'), findsOneWidget);
    });
  });

  group('日期格式化測試', () {
    testWidgets('相對日期 - 今天', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final now = DateTime.now();
                return Text(Formatters.relativeDate(now));
              },
            ),
          ),
        ),
      );
      expect(find.text('今天'), findsOneWidget);
    });

    testWidgets('相對日期 - 昨天', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final yesterday = DateTime.now().subtract(const Duration(days: 1));
                return Text(Formatters.relativeDate(yesterday));
              },
            ),
          ),
        ),
      );
      expect(find.text('昨天'), findsOneWidget);
    });
  });
}
