import 'package:intl/intl.dart';

/// 金額格式化工具
class CurrencyFormatter {
  static final _ntd = NumberFormat('#,##0', 'zh_TW');
  static final _ntdDecimal = NumberFormat('#,##0.##', 'zh_TW');

  static String format(double amount) => 'NT\$ ${_ntd.format(amount)}';

  static String formatDecimal(double amount) =>
      'NT\$ ${_ntdDecimal.format(amount)}';

  static String formatNumber(double amount) => _ntd.format(amount);

  static String formatDate(DateTime date) =>
      DateFormat('yyyy/MM/dd (E)', 'zh_TW').format(date);

  static String formatDateShort(DateTime date) =>
      DateFormat('MM/dd', 'zh_TW').format(date);

  static String formatMonth(DateTime date) =>
      DateFormat('yyyy年M月', 'zh_TW').format(date);
}
