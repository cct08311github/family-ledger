/// 本地智能記帳解析引擎（免 API Key）
///
/// 支援語句模式：
///   "晚餐三百"、"午餐 250"、"加油花了1500"、"昨天買菜500元"
///   "前天搭計程車兩百五"、"水電費三千二"、"繳房租兩萬五"
///   "星期三請客吃飯一千二"、"3/15 看醫生八百"
///   "咖啡85"、"停車費60"
class LocalExpenseParser {
  /// 解析自然語言為記帳結構
  /// 回傳 Map: {description, amount, category, date}
  static Map<String, dynamic> parse(
    String text, {
    required List<String> availableCategories,
  }) {
    final input = text.trim();
    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // 1. 提取日期
    final dateResult = _extractDate(input, now);
    final date = dateResult.date ?? today;
    final textAfterDate = dateResult.remaining;

    // 2. 提取金額
    final amountResult = _extractAmount(textAfterDate);
    final amount = amountResult.amount;
    final textAfterAmount = amountResult.remaining.trim();

    // 3. 提取描述（去掉金額和日期後的剩餘文字）
    final description = _extractDescription(textAfterAmount, input);

    // 4. 推斷類別
    final category = _inferCategory(input, description, availableCategories);

    return {
      'description': description.isEmpty ? input : description,
      'amount': amount,
      'category': category,
      'date': date,
    };
  }

  // ─── 中文數字轉換 ───

  static final _cnDigits = {
    '零': 0, '〇': 0, '一': 1, '壹': 1, '二': 2, '貳': 2, '兩': 2,
    '三': 3, '參': 3, '四': 4, '肆': 4, '五': 5, '伍': 5,
    '六': 6, '陸': 6, '七': 7, '柒': 7, '八': 8, '捌': 8,
    '九': 9, '玖': 9, '十': 10, '拾': 10, '百': 100, '佰': 100,
    '千': 1000, '仟': 1000, '萬': 10000, '万': 10000,
  };

  /// 將中文數字轉為 double
  /// "三百五" → 350, "兩千" → 2000, "一萬五千" → 15000, "五十" → 50
  static double _chineseToNumber(String cn) {
    if (cn.isEmpty) return 0;

    double total = 0;
    double current = 0;
    double lastUnit = 1;

    for (int i = 0; i < cn.length; i++) {
      final char = cn[i];
      final value = _cnDigits[char];
      if (value == null) continue;

      if (value >= 10) {
        // 這是一個單位（十/百/千/萬）
        if (value == 10000) {
          // 萬：把目前累積的乘以萬
          if (current == 0 && total == 0) {
            total = 10000;
          } else {
            total = (total + current) * 10000;
          }
          current = 0;
          lastUnit = 10000;
        } else {
          // 十/百/千
          if (current == 0) {
            // "十" 單獨出現 = 10, "百" = 100
            current = value.toDouble();
          } else {
            current = current * value;
          }
          total += current;
          current = 0;
          lastUnit = value.toDouble();
        }
      } else {
        // 這是一個數字（0-9）
        current = value.toDouble();
      }
    }

    // 處理尾數：如 "三百五" = 350（"五"是下一個量級的簡寫）
    if (current > 0) {
      if (lastUnit >= 100 && current < 10) {
        // 簡寫：三百五 = 350, 兩千三 = 2300
        total += current * (lastUnit / 10);
      } else {
        total += current;
      }
    }

    return total;
  }

  // ─── 金額提取 ───

  static ({double amount, String remaining}) _extractAmount(String text) {
    // 策略：先找阿拉伯數字，再找中文數字

    // Pattern 1: 阿拉伯數字（可能帶小數點）
    final arabicMatch = RegExp(r'(\d+\.?\d*)[\s]*(元|塊|圓|NT\$?|NTD)?').firstMatch(text);

    // Pattern 2: 中文數字
    final cnPattern = RegExp(r'([零〇一壹二貳兩三參四肆五伍六陸七柒八捌九玖十拾百佰千仟萬万]+)[\s]*(元|塊|圓)?');
    final cnMatch = cnPattern.firstMatch(text);

    double amount = 0;
    String remaining = text;

    if (arabicMatch != null && cnMatch != null) {
      // 兩個都有，取位置靠後的（通常金額在描述後面）
      // 但如果阿拉伯數字更大或更可能是金額，優先用
      final arabicAmount = double.tryParse(arabicMatch.group(1)!) ?? 0;
      final cnAmount = _chineseToNumber(cnMatch.group(1)!);

      if (arabicAmount > 0 && (cnAmount == 0 || arabicMatch.start >= cnMatch.start)) {
        amount = arabicAmount;
        remaining = text.replaceFirst(arabicMatch.group(0)!, ' ');
      } else if (cnAmount > 0) {
        amount = cnAmount;
        remaining = text.replaceFirst(cnMatch.group(0)!, ' ');
      }
    } else if (arabicMatch != null) {
      amount = double.tryParse(arabicMatch.group(1)!) ?? 0;
      remaining = text.replaceFirst(arabicMatch.group(0)!, ' ');
    } else if (cnMatch != null) {
      amount = _chineseToNumber(cnMatch.group(1)!);
      remaining = text.replaceFirst(cnMatch.group(0)!, ' ');
    }

    return (amount: amount, remaining: remaining);
  }

  // ─── 日期提取 ───

  static ({String? date, String remaining}) _extractDate(String text, DateTime now) {
    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    // 今天/昨天/前天/大前天
    final relativeDays = {
      '今天': 0, '今日': 0,
      '昨天': -1, '昨日': -1,
      '前天': -2, '前日': -2,
      '大前天': -3, '大前日': -3,
    };
    for (final entry in relativeDays.entries) {
      if (text.contains(entry.key)) {
        final d = now.add(Duration(days: entry.value));
        return (date: fmt(d), remaining: text.replaceFirst(entry.key, ' '));
      }
    }

    // 上禮拜X / 上週X / 上星期X
    final lastWeekMatch = RegExp(r'上[個]?(?:禮拜|週|星期)([一二三四五六日天])').firstMatch(text);
    if (lastWeekMatch != null) {
      final dayMap = {'一': 1, '二': 2, '三': 3, '四': 4, '五': 5, '六': 6, '日': 7, '天': 7};
      final targetDay = dayMap[lastWeekMatch.group(1)] ?? 1;
      var d = now.subtract(Duration(days: now.weekday - targetDay));
      if (d.isAfter(now) || d.isAtSameMomentAs(now)) {
        d = d.subtract(const Duration(days: 7));
      }
      // 確保是上週
      if (now.difference(d).inDays < 7) {
        d = d.subtract(const Duration(days: 7));
      }
      return (date: fmt(d), remaining: text.replaceFirst(lastWeekMatch.group(0)!, ' '));
    }

    // 這禮拜X / 這週X / 這星期X / 禮拜X / 週X / 星期X
    final thisWeekMatch = RegExp(r'[這]?(?:禮拜|週|星期)([一二三四五六日天])').firstMatch(text);
    if (thisWeekMatch != null) {
      final dayMap = {'一': 1, '二': 2, '三': 3, '四': 4, '五': 5, '六': 6, '日': 7, '天': 7};
      final targetDay = dayMap[thisWeekMatch.group(1)] ?? 1;
      var d = now.subtract(Duration(days: now.weekday - targetDay));
      if (d.isAfter(now)) {
        d = d.subtract(const Duration(days: 7));
      }
      return (date: fmt(d), remaining: text.replaceFirst(thisWeekMatch.group(0)!, ' '));
    }

    // MM/DD 或 M月D日 或 M月D號
    final mdSlash = RegExp(r'(\d{1,2})/(\d{1,2})').firstMatch(text);
    if (mdSlash != null) {
      final m = int.parse(mdSlash.group(1)!);
      final d = int.parse(mdSlash.group(2)!);
      if (m >= 1 && m <= 12 && d >= 1 && d <= 31) {
        var year = now.year;
        final candidate = DateTime(year, m, d);
        if (candidate.isAfter(now)) year--;
        return (date: fmt(DateTime(year, m, d)), remaining: text.replaceFirst(mdSlash.group(0)!, ' '));
      }
    }

    final mdChinese = RegExp(r'(\d{1,2})月(\d{1,2})[日號]?').firstMatch(text);
    if (mdChinese != null) {
      final m = int.parse(mdChinese.group(1)!);
      final d = int.parse(mdChinese.group(2)!);
      if (m >= 1 && m <= 12 && d >= 1 && d <= 31) {
        var year = now.year;
        final candidate = DateTime(year, m, d);
        if (candidate.isAfter(now)) year--;
        return (date: fmt(DateTime(year, m, d)), remaining: text.replaceFirst(mdChinese.group(0)!, ' '));
      }
    }

    return (date: null, remaining: text);
  }

  // ─── 描述提取 ───

  static String _extractDescription(String remaining, String original) {
    // 清理常見動詞和虛詞
    var desc = remaining
        .replaceAll(RegExp(r'[花了用了付了繳了買了吃了搭了去了請了刷了]'), '')
        .replaceAll(RegExp(r'[花用付繳]了'), '')
        .replaceAll(RegExp(r'[的]$'), '')
        .replaceAll(RegExp(r'[\s]+'), ' ')
        .trim();

    // 移除尾部的 "元/塊/圓"
    desc = desc.replaceAll(RegExp(r'[元塊圓]$'), '').trim();

    // 如果清理後太短，嘗試從原文提取名詞性片段
    if (desc.length < 2) {
      // 取原文中非數字、非日期的部分
      desc = original
          .replaceAll(RegExp(r'\d+\.?\d*'), '')
          .replaceAll(RegExp(r'[零〇一壹二貳兩三參四肆五伍六陸七柒八捌九玖十拾百佰千仟萬万]+'), '')
          .replaceAll(RegExp(r'今天|昨天|前天|大前天|上[個]?(?:禮拜|週|星期).'), '')
          .replaceAll(RegExp(r'[這]?(?:禮拜|週|星期).'), '')
          .replaceAll(RegExp(r'\d{1,2}[/月]\d{1,2}[日號]?'), '')
          .replaceAll(RegExp(r'[花了用了付了繳了買了吃了搭了去了請了刷了元塊圓]'), '')
          .replaceAll(RegExp(r'[\s]+'), ' ')
          .trim();
    }

    return desc.isEmpty ? original.trim() : desc;
  }

  // ─── 類別推斷 ───

  static final _categoryKeywords = <String, List<String>>{
    '餐飲': [
      '早餐', '午餐', '晚餐', '宵夜', '吃飯', '便當', '麵', '飯', '餐',
      '咖啡', '奶茶', '飲料', '手搖', '飲品', '酒', '啤酒',
      '小吃', '火鍋', '燒烤', '壽司', '拉麵', '漢堡', '披薩',
      '滷味', '鹹酥雞', '雞排', '豆花', '甜點', '蛋糕', '麵包',
      '外送', '外賣', 'Uber', 'ubereats', 'foodpanda', '熊貓',
      '自助餐', '快餐', '速食', '麥當勞', '肯德基', '摩斯',
      '星巴克', '路易莎', '全聯', '超商', '7-11', '全家',
      '食材', '買菜', '市場', '超市', '生鮮', '水果', '蔬菜',
      '請客', '聚餐', '尾牙', '春酒', '喜酒',
    ],
    '交通': [
      '加油', '油錢', '油資', '汽油', '柴油', '95', '98',
      '停車', '停車費', '車位',
      '計程車', '小黃', 'taxi', 'Uber', '叫車',
      '捷運', '公車', '客運', '火車', '高鐵', '台鐵',
      '機票', '船票', '車票', '月票', '悠遊卡', 'iPass', '一卡通',
      'ETC', '過路費', '通行費', '國道',
      '修車', '保養', '洗車', '輪胎', '保險',
      '騎車', '腳踏車', 'YouBike', '機車',
    ],
    '購物': [
      '買', '購買', '網購', '蝦皮', 'momo', 'PChome', 'Amazon',
      '衣服', '褲子', '鞋', '包包', '配件', '飾品',
      '3C', '手機', '電腦', '耳機', '平板', '充電',
      '家電', '電器', '冰箱', '洗衣機', '冷氣',
      '百貨', '商場', 'outlet', '特賣',
      '禮物', '送禮', '生日禮',
    ],
    '房租': ['房租', '租金', '押金', '管理費', '大樓管理'],
    '水電': [
      '水費', '電費', '瓦斯', '天然氣', '水電',
      '網路', '網路費', '寬頻', '第四台', '有線電視',
      '電信', '電話費', '手機費', '月租',
    ],
    '醫療': [
      '看醫生', '看診', '掛號', '門診', '急診',
      '藥', '藥局', '藥房', '買藥',
      '牙醫', '眼科', '皮膚科', '中醫', '復健',
      '健檢', '體檢', '疫苗', '打針',
      '保健', '維他命', '保養品',
    ],
    '娛樂': [
      '電影', '看電影', '電影票', '影城',
      '唱歌', 'KTV', '卡拉OK',
      '遊戲', 'Steam', 'Switch', 'PS5', 'Xbox',
      '旅遊', '旅行', '出遊', '住宿', '飯店', '民宿', '旅館',
      '門票', '入場', '樂園', '展覽', '演唱會', '表演',
      '健身', '健身房', '瑜伽', '游泳', '運動',
      '按摩', 'SPA', '泡湯', '溫泉',
      '訂閱', 'Netflix', 'Spotify', 'YouTube', 'Disney',
      '書', '書店', '雜誌', '漫畫',
    ],
    '孝親': [
      '孝親', '給爸', '給媽', '給父母', '爸媽',
      '紅包', '包紅包', '過年', '壓歲錢',
      '安養', '看護', '照護',
    ],
    '子女教育': [
      '學費', '補習', '補習費', '才藝', '安親班',
      '教材', '課本', '文具', '書包',
      '學校', '幼兒園', '幼稒園', '托兒', '托嬰',
      '家教', '線上課', '課程',
    ],
    '日用品': [
      '日用', '日用品', '衛生紙', '洗衣精', '洗碗精',
      '牙膏', '牙刷', '洗髮', '沐浴', '肥皂',
      '清潔', '掃除', '拖把', '垃圾袋',
      '寵物', '貓', '狗', '飼料', '貓砂',
    ],
    '通訊': [
      '手機費', '電話費', '網路費', '月租費',
      '儲值', '點數', '流量',
    ],
    '其他': [],
  };

  static String _inferCategory(
      String fullText, String description, List<String> available) {
    final text = '$fullText $description'.toLowerCase();

    // 逐類別比對關鍵字，計算匹配分數
    String bestCategory = available.first;
    int bestScore = 0;

    for (final cat in available) {
      final keywords = _categoryKeywords[cat];
      if (keywords == null) continue;

      int score = 0;
      for (final kw in keywords) {
        if (text.contains(kw.toLowerCase())) {
          // 較長的關鍵字給更高分（更精確）
          score += kw.length;
        }
      }

      if (score > bestScore) {
        bestScore = score;
        bestCategory = cat;
      }
    }

    // 沒有匹配到任何關鍵字，回傳第一個（通常是「餐飲」或使用者最常用的）
    return bestCategory;
  }
}
