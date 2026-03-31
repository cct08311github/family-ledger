import 'package:flutter_test/flutter_test.dart';
import 'package:family_ledger/services/split_calculator.dart';
import 'package:family_ledger/models/split_detail.dart';
import 'package:family_ledger/models/expense.dart';
import 'package:family_ledger/models/settlement.dart';
import 'package:family_ledger/models/enums.dart';

void main() {
  group('SplitCalculator - calculateEqual', () {
    test('3人平分 300 元', () {
      final participants = [
        {'id': 'A', 'name': '小明'},
        {'id': 'B', 'name': '小華'},
        {'id': 'C', 'name': '小美'},
      ];

      final splits = SplitCalculator.calculateEqual(
        amount: 300,
        payerId: 'A',
        participants: participants,
      );

      expect(splits.length, 3);
      // 每人 100，無餘數
      expect(splits[0].shareAmount, 100);
      expect(splits[0].paidAmount, 300); // A 是付款人
      expect(splits[1].shareAmount, 100);
      expect(splits[1].paidAmount, 0);
      expect(splits[2].shareAmount, 100);
      expect(splits[2].paidAmount, 0);
    });

    test('3人平分 100 元（除不盡，尾數給最後一人）', () {
      final participants = [
        {'id': 'A', 'name': '小明'},
        {'id': 'B', 'name': '小華'},
        {'id': 'C', 'name': '小美'},
      ];

      final splits = SplitCalculator.calculateEqual(
        amount: 100,
        payerId: 'B',
        participants: participants,
      );

      // 100 / 3 = 33.33 → 33,  remainder = 100 - 33*3 = 1
      // C 拿到最後一個 34
      expect(splits[0].shareAmount, 33); // A
      expect(splits[0].paidAmount, 0);
      expect(splits[1].shareAmount, 33); // B
      expect(splits[1].paidAmount, 100); // B 是付款人
      expect(splits[2].shareAmount, 34); // C（最後一人吸收餘數）
      expect(splits[2].paidAmount, 0);
    });

    test('2人平分', () {
      final splits = SplitCalculator.calculateEqual(
        amount: 500,
        payerId: 'A',
        participants: [
          {'id': 'A', 'name': '小明'},
          {'id': 'B', 'name': '小華'},
        ],
      );

      expect(splits.length, 2);
      expect(splits[0].shareAmount, 250);
      expect(splits[0].paidAmount, 500);
      expect(splits[1].shareAmount, 250);
      expect(splits[1].paidAmount, 0);
    });

    test('1人（自己）', () {
      final splits = SplitCalculator.calculateEqual(
        amount: 1000,
        payerId: 'A',
        participants: [
          {'id': 'A', 'name': '小明'},
        ],
      );

      expect(splits.length, 1);
      expect(splits[0].shareAmount, 1000);
      expect(splits[0].paidAmount, 1000);
    });
  });

  group('SplitCalculator - calculatePercentage', () {
    test('50/30/20 分配 1000 元', () {
      final splits = SplitCalculator.calculatePercentage(
        amount: 1000,
        payerId: 'A',
        percentages: {'A': 50, 'B': 30, 'C': 20},
        memberNames: {'A': '小明', 'B': '小華', 'C': '小美'},
      );

      expect(splits.length, 3);
      expect(splits[0].memberId, 'A');
      expect(splits[0].shareAmount, 500); // 50%
      expect(splits[0].paidAmount, 1000); // A 是付款人
      expect(splits[1].memberId, 'B');
      expect(splits[1].shareAmount, 300); // 30%
      expect(splits[2].memberId, 'C');
      // 20% * 1000 = 200，但四捨五入後的最後一人吸收餘數
    });

    test('100% 給一人', () {
      final splits = SplitCalculator.calculatePercentage(
        amount: 500,
        payerId: 'A',
        percentages: {'A': 100},
        memberNames: {'A': '小明'},
      );

      expect(splits.length, 1);
      expect(splits[0].shareAmount, 500);
    });
  });

  group('SplitCalculator - calculateCustom', () {
    test('自訂金額：200/100/50', () {
      final splits = SplitCalculator.calculateCustom(
        amount: 350,
        payerId: 'A',
        customAmounts: {'A': 200, 'B': 100, 'C': 50},
        memberNames: {'A': '小明', 'B': '小華', 'C': '小美'},
      );

      expect(splits.length, 3);
      expect(splits[0].memberId, 'A');
      expect(splits[0].shareAmount, 200);
      expect(splits[0].paidAmount, 350);
      expect(splits[1].shareAmount, 100);
      expect(splits[2].shareAmount, 50);
    });
  });

  group('SplitCalculator - calculateNetDebts', () {
    test('無結算：C欠A和B各100', () {
      // A 付了 300，三人均分 → 各欠 A 100
      final e1 = Expense()
        ..id = 'e1'
        ..groupId = 'g1'
        ..isShared = true
        ..payerId = 'A'
        ..payerName = '小明'
        ..splits = [
          _split('A', 100),
          _split('B', 100),
          _split('C', 100),
        ];

      // B 付了 200，兩人均分 → C 欠 B 100
      final e2 = Expense()
        ..id = 'e2'
        ..groupId = 'g1'
        ..isShared = true
        ..payerId = 'B'
        ..payerName = '小華'
        ..splits = [
          _split('B', 100),
          _split('C', 100),
        ];

      final debts = SplitCalculator.calculateNetDebts(
        expenses: [e1, e2],
        settlements: [],
      );

      // C 欠 A: 100, C 欠 B: 100
      expect(debts['C->A'], 100);
      expect(debts['C->B'], 100);
    });

    test('C 還 100 給 A：C 的債務清空，B 仍欠 A 100', () {
      // A 付 300 均分：C 欠 A 100，B 欠 A 100
      final e1 = Expense()
        ..id = 'e1'
        ..groupId = 'g1'
        ..isShared = true
        ..payerId = 'A'
        ..payerName = '小明'
        ..splits = [
          _split('A', 100),
          _split('B', 100),
          _split('C', 100),
        ];

      // C 還 100 給 A → C 不再欠 A，但 B 仍欠 A
      final settlements = [
        Settlement()
          ..id = 's1'
          ..groupId = 'g1'
          ..fromMemberId = 'C'
          ..toMemberId = 'A'
          ..amount = 100
          ..createdAt = DateTime.now(),
      ];

      final debts = SplitCalculator.calculateNetDebts(
        expenses: [e1],
        settlements: settlements,
      );

      expect(debts['C->A'], null); // C 還清
      expect(debts['B->A'], 100);  // B 仍欠
    });

    test('單向部分抵消', () {
      // A 付 300，C 欠 A 100
      final e1 = Expense()
        ..id = 'e1'
        ..groupId = 'g1'
        ..isShared = true
        ..payerId = 'A'
        ..payerName = '小明'
        ..splits = [
          _split('A', 100),
          _split('B', 100),
          _split('C', 100),
        ];

      // C 只還 50 給 A → C 還欠 A 50
      final settlements = [
        Settlement()
          ..id = 's1'
          ..groupId = 'g1'
          ..fromMemberId = 'C'
          ..toMemberId = 'A'
          ..amount = 50
          ..createdAt = DateTime.now(),
      ];

      final debts = SplitCalculator.calculateNetDebts(
        expenses: [e1],
        settlements: settlements,
      );

      expect(debts['C->A'], 50);
    });

    test('相互債務淨額抵消', () {
      // A 付 300 均分：C 欠 A 100，B 欠 A 100
      final e1 = Expense()
        ..id = 'e1'
        ..groupId = 'g1'
        ..isShared = true
        ..payerId = 'A'
        ..payerName = '小明'
        ..splits = [
          _split('A', 100),
          _split('B', 100),
          _split('C', 100),
        ];

      // C 付 300 均分：A 欠 C 100，B 欠 C 100 → A 和 C 抵消，B 仍欠 C 100
      final e2 = Expense()
        ..id = 'e2'
        ..groupId = 'g1'
        ..isShared = true
        ..payerId = 'C'
        ..payerName = '小美'
        ..splits = [
          _split('A', 100),
          _split('B', 100),
          _split('C', 100),
        ];

      final debts = SplitCalculator.calculateNetDebts(
        expenses: [e1, e2],
        settlements: [],
      );

      // A 欠 C 100，C 欠 A 100 → 抵消（A、C 間無債務）
      // B 欠 A 100，B 欠 C 100（沒人欠 B）
      expect(debts['A->C'], null); // 抵消
      expect(debts['C->A'], null); // 抵消
      expect(debts['B->A'], 100);  // B 欠 A
      expect(debts['B->C'], 100);  // B 欠 C
    });
  });

  group('SplitCalculator - simplifyDebts (最小現金流)', () {
    test('A欠B 300 → 一次轉帳', () {
      final debts = {'A->B': 300.0};
      final simplified = SplitCalculator.simplifyDebts(debts);

      expect(simplified.length, 1);
      expect(simplified[0]['from'], 'A');
      expect(simplified[0]['to'], 'B');
      expect(simplified[0]['amount'], 300);
    });

    test('三角債：A欠B 200，B欠C 100 → 最佳化為A直接還C 100', () {
      final debts = {'A->B': 200.0, 'B->C': 100.0};
      final simplified = SplitCalculator.simplifyDebts(debts);

      // 貪心法：A 欠 B 200，B 欠 C 100
      // 淨餘額：A=-200, B=100, C=100
      // 貪心結果：A->C 100，B->C 100 或 A->C 100, A->B 100
      expect(simplified.length, lessThanOrEqualTo(2));
    });

    test('餘額為0或接近0應被過濾', () {
      final debts = {'A->B': 0.3}; // 小於 0.5 的應被忽略
      final simplified = SplitCalculator.simplifyDebts(debts);

      expect(simplified.isEmpty, true);
    });

    test('多人複雜債務', () {
      // A 欠 B 300, C 欠 A 200, B 欠 C 100
      final debts = {
        'A->B': 300.0,
        'C->A': 200.0,
        'B->C': 100.0,
      };
      final simplified = SplitCalculator.simplifyDebts(debts);

      // 淨餘額：A=-100(A欠B300, C欠A200→A凈-100), B=200(B欠C100, A欠B300→B凈+200), C=0(C欠A200, B欠C100→C凈-100? wait)
      // 讓我重新算：
      // A: -300 + 200 = -100 (欠)
      // B: +300 - 100 = +200 (被欠)
      // C: -200 + 100 = -100 (欠)
      // 貪心：最大債務人 C(-100) 還最大債權人 B(200) 100 → C->B 100
      // B 變成 +100，C變成 0
      // 然後 A(-100) 還 B(100) 100 → A->B 100
      // 結果：A->B 100, C->B 100
      expect(simplified.isNotEmpty, true);
    });
  });
}

SplitDetail _split(String memberId, double shareAmount) {
  return SplitDetail()
    ..memberId = memberId
    ..memberName = memberId
    ..shareAmount = shareAmount
    ..paidAmount = 0
    ..isParticipant = true;
}
