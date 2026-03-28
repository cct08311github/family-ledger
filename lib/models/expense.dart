import 'package:isar/isar.dart';
import 'enums.dart';
import 'split_detail.dart';

part 'expense.g.dart';

/// 支出記錄
@collection
class Expense {
  Id isarId = Isar.autoIncrement;

  /// 唯一識別碼（UUID）
  @Index(unique: true)
  late String id;

  /// 所屬群組 ID
  @Index()
  late String groupId;

  /// 日期
  @Index()
  late DateTime date;

  /// 描述
  late String description;

  /// 金額（NT$）
  late double amount;

  /// 類別（餐飲、交通、購物…）
  @Index()
  late String category;

  /// 是否為共同支出（true = 需拆帳）
  @Index()
  late bool isShared;

  /// 分帳方式：equal / percentage / custom
  @Enumerated(EnumType.name)
  late SplitMethod splitMethod;

  /// 付款人 ID
  @Index()
  late String payerId;

  /// 付款人名稱（冗餘儲存）
  late String payerName;

  /// 拆帳明細（嵌入式）
  late List<SplitDetail> splits;

  /// 付款方式：cash / creditCard / transfer
  @Enumerated(EnumType.name)
  PaymentMethod paymentMethod = PaymentMethod.cash;

  /// 發票照片本地路徑
  String? receiptPath;

  /// 備註
  String? note;

  /// 新增者 ID
  late String createdBy;

  /// 建立時間
  late DateTime createdAt;

  /// 更新時間
  late DateTime updatedAt;
}

