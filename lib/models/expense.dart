import 'enums.dart';
import 'split_detail.dart';

/// 支出記錄
class Expense {
  late String id;
  late String groupId;
  late DateTime date;
  late String description;
  late double amount;
  late String category;
  late bool isShared;
  late SplitMethod splitMethod;
  late String payerId;
  late String payerName;
  late List<SplitDetail> splits;
  late PaymentMethod paymentMethod;
  String? receiptPath;
  List<String> receiptPaths = [];
  String? note;
  late String createdBy;
  late DateTime createdAt;
  late DateTime updatedAt;

  Expense();

  Expense.fromFirestore(Map<String, dynamic> map, this.id) {
    groupId = map['groupId'] as String? ?? '';
    date = _toDateTime(map['date']);
    description = map['description'] as String? ?? '';
    amount = (map['amount'] as num?)?.toDouble() ?? 0;
    category = map['category'] as String? ?? '其他';
    isShared = map['isShared'] as bool? ?? false;
    splitMethod = SplitMethod.values.firstWhere(
      (e) => e.name == map['splitMethod'],
      orElse: () => SplitMethod.equal,
    );
    payerId = map['payerId'] as String? ?? '';
    payerName = map['payerName'] as String? ?? '';
    splits = (map['splits'] as List?)
            ?.map((s) => SplitDetail.fromMap(Map<String, dynamic>.from(s as Map)))
            .toList() ??
        [];
    paymentMethod = PaymentMethod.values.firstWhere(
      (e) => e.name == (map['paymentMethod'] ?? 'cash'),
      orElse: () => PaymentMethod.cash,
    );
    receiptPath = map['receiptPath'] as String?;
    receiptPaths = (map['receiptPaths'] as List?)?.cast<String>() ?? [];
    note = map['note'] as String?;
    createdBy = map['createdBy'] as String? ?? '';
    createdAt = _toDateTime(map['createdAt']);
    updatedAt = _toDateTime(map['updatedAt']);
  }

  Map<String, dynamic> toFirestore() {
    return {
      'groupId': groupId,
      'date': date,
      'description': description,
      'amount': amount,
      'category': category,
      'isShared': isShared,
      'splitMethod': splitMethod.name,
      'payerId': payerId,
      'payerName': payerName,
      'splits': splits.map((s) => s.toMap()).toList(),
      'paymentMethod': paymentMethod.name,
      if (receiptPath != null) 'receiptPath': receiptPath,
      'receiptPaths': receiptPaths,
      if (note != null) 'note': note,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  DateTime _toDateTime(dynamic value) {
    if (value is DateTime) return value;
    return DateTime.now();
  }
}
