import 'package:intl/intl.dart';

class Formatters {
  /// 新台幣格式：NT$ 1,234
  static String currency(double amount) {
    final formatter = NumberFormat('#,##0', 'zh_TW');
    return 'NT\$ ${formatter.format(amount.round())}';
  }

  /// 帶正負號的金額：+NT$ 1,234 / -NT$ 567
  static String signedCurrency(double amount) {
    final prefix = amount >= 0 ? '+' : '-';
    final formatter = NumberFormat('#,##0', 'zh_TW');
    return '$prefix NT\$ ${formatter.format(amount.abs().round())}';
  }

  /// 日期格式：2024/03/28
  static String date(DateTime dt) {
    return DateFormat('yyyy/MM/dd').format(dt);
  }

  /// 日期格式（短）：3/28
  static String dateShort(DateTime dt) {
    return DateFormat('M/d').format(dt);
  }

  /// 年月：2024年3月
  static String yearMonth(DateTime dt) {
    return DateFormat('yyyy年M月', 'zh_TW').format(dt);
  }

  /// 日期時間：2024/03/28 14:30
  static String dateTime(DateTime dt) {
    return DateFormat('yyyy/MM/dd HH:mm').format(dt);
  }

  /// 相對日期：今天、昨天、3/25
  static String relativeDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(target).inDays;

    if (diff == 0) return '今天';
    if (diff == 1) return '昨天';
    if (diff == 2) return '前天';
    if (diff < 7) return '$diff 天前';
    return dateShort(dt);
  }
}
