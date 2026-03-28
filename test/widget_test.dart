import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:family_ledger/screens/auth/login_page.dart';

void main() {
  testWidgets('Login page smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: LoginPage(onLoginSuccess: () {}),
    ));
    expect(find.text('家計本'), findsOneWidget);
    expect(find.text('使用 Google 帳號登入'), findsOneWidget);
  });
}
