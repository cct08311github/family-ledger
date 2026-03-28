import 'package:flutter_test/flutter_test.dart';
import 'package:family_ledger/services/local_expense_parser.dart';

void main() {
  const categories = ['餐飲', '交通', '購物', '房租', '水電', '醫療', '娛樂', '孝親', '子女教育', '日用品', '通訊', '其他'];

  Map<String, dynamic> p(String text) =>
      LocalExpenseParser.parse(text, availableCategories: categories);

  group('阿拉伯數字金額', () {
    test('基本', () {
      expect(p('午餐250')['amount'], 250);
      expect(p('咖啡85')['amount'], 85);
      expect(p('停車費60')['amount'], 60);
    });

    test('帶元/塊', () {
      expect(p('加油1500元')['amount'], 1500);
      expect(p('買菜500塊')['amount'], 500);
    });

    test('帶空格', () {
      expect(p('晚餐 300')['amount'], 300);
    });
  });

  group('中文數字金額', () {
    test('簡單', () {
      expect(p('晚餐三百')['amount'], 300);
      expect(p('咖啡八十五')['amount'], 85);
    });

    test('千', () {
      expect(p('加油一千五')['amount'], 1500);
      expect(p('手機兩千')['amount'], 2000);
    });

    test('萬', () {
      expect(p('房租兩萬五')['amount'], 25000);
    });

    test('百+簡寫', () {
      expect(p('計程車兩百五')['amount'], 250);
      expect(p('水電費三千二')['amount'], 3200);
    });

    test('複合', () {
      expect(p('補習費一萬五千')['amount'], 15000);
    });

    test('十', () {
      expect(p('飲料五十')['amount'], 50);
    });
  });

  group('類別推斷', () {
    test('餐飲', () {
      expect(p('午餐便當100')['category'], '餐飲');
      expect(p('星巴克咖啡180')['category'], '餐飲');
      expect(p('外送300')['category'], '餐飲');
    });

    test('交通', () {
      expect(p('加油1500')['category'], '交通');
      expect(p('停車費60')['category'], '交通');
      expect(p('搭捷運35')['category'], '交通');
      expect(p('計程車兩百五')['category'], '交通');
    });

    test('醫療', () {
      expect(p('看醫生掛號250')['category'], '醫療');
      expect(p('買藥300')['category'], '醫療');
    });

    test('娛樂', () {
      expect(p('看電影350')['category'], '娛樂');
      expect(p('Netflix訂閱390')['category'], '娛樂');
    });

    test('水電', () {
      expect(p('電費2300')['category'], '水電');
      expect(p('繳水費800')['category'], '水電');
    });
  });

  group('日期解析', () {
    test('今天', () {
      final now = DateTime.now();
      final expected = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      expect(p('今天午餐100')['date'], expected);
    });

    test('昨天', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final expected = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
      expect(p('昨天晚餐300')['date'], expected);
    });

    test('前天', () {
      final d = DateTime.now().subtract(const Duration(days: 2));
      final expected = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      expect(p('前天加油1000')['date'], expected);
    });

    test('MM/DD', () {
      final result = p('3/15看醫生800');
      expect(result['date'], contains('-03-15'));
    });
  });

  group('描述提取', () {
    test('基本', () {
      expect(p('午餐250')['description'], contains('午餐'));
      expect(p('加油花了1500')['description'], contains('加油'));
    });

    test('含動詞', () {
      final r = p('昨天買菜500');
      expect(r['description'], contains('菜'));
    });
  });

  group('綜合場景', () {
    test('完整語句', () {
      final r = p('昨天晚餐花了三百');
      expect(r['amount'], 300);
      expect(r['category'], '餐飲');
      expect(r['description'], isNotEmpty);
    });

    test('搭計程車兩百五', () {
      final r = p('搭計程車兩百五');
      expect(r['amount'], 250);
      expect(r['category'], '交通');
    });

    test('繳房租兩萬五', () {
      final r = p('繳房租兩萬五');
      expect(r['amount'], 25000);
      expect(r['category'], '房租');
    });

    test('星巴克咖啡180', () {
      final r = p('星巴克咖啡180');
      expect(r['amount'], 180);
      expect(r['category'], '餐飲');
    });

    test('3/15看醫生八百', () {
      final r = p('3/15看醫生八百');
      expect(r['amount'], 800);
      expect(r['category'], '醫療');
      expect(r['date'], contains('-03-15'));
    });
  });
}
