import 'package:flutter_test/flutter_test.dart';
import 'package:family_ledger/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const FamilyLedgerApp());
    expect(find.text('首頁'), findsOneWidget);
  });
}
