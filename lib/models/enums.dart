/// 支出類型
enum ExpenseType {
  personal, // 個人支出
  shared,   // 共同支出（需拆帳）
}

/// 分帳方式
enum SplitMethod {
  equal,      // 均分
  percentage, // 比例分
  custom,     // 自訂金額
}

/// 付款方式
enum PaymentMethod {
  cash,       // 現金
  creditCard, // 信用卡
  transfer,   // 轉帳
}

/// 成員角色
enum MemberRole {
  admin,
  member,
}

/// 預設支出類別
class DefaultCategories {
  static const List<String> all = [
    '餐飲',
    '交通',
    '購物',
    '房租',
    '水電',
    '醫療',
    '娛樂',
    '孝親',
    '子女教育',
    '日用品',
    '通訊',
    '其他',
  ];

  static const Map<String, String> icons = {
    '餐飲': '🍜',
    '交通': '🚗',
    '購物': '🛍️',
    '房租': '🏠',
    '水電': '💡',
    '醫療': '🏥',
    '娛樂': '🎮',
    '孝親': '❤️',
    '子女教育': '📚',
    '日用品': '🧴',
    '通訊': '📱',
    '其他': '📌',
  };
}
