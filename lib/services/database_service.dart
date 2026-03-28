import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/family_group.dart';
import '../models/family_member.dart';
import '../models/expense.dart';
import '../models/balance.dart';
import '../models/category.dart';
import '../models/settlement.dart';
import '../models/activity_log.dart';
import '../models/enums.dart';
import 'package:uuid/uuid.dart';

/// Isar 資料庫管理服務
class DatabaseService {
  static Isar? _isar;
  static const _uuid = Uuid();

  /// 取得 Isar 實例（單例）
  static Future<Isar> get instance async {
    if (_isar != null && _isar!.isOpen) return _isar!;
    return await _init();
  }

  /// 初始化資料庫
  static Future<Isar> _init() async {
    final dir = await getApplicationDocumentsDirectory();

    _isar = await Isar.open(
      [
        FamilyGroupSchema,
        FamilyMemberSchema,
        ExpenseSchema,
        BalanceSchema,
        CategorySchema,
        SettlementSchema,
        ActivityLogSchema,
      ],
      directory: dir.path,
      name: 'family_ledger',
    );

    // 首次啟動：建立預設群組和類別
    await _seedDefaultData();

    return _isar!;
  }

  /// 建立預設資料
  static Future<void> _seedDefaultData() async {
    final isar = _isar!;

    // 檢查是否已有群組
    final groupCount = await isar.familyGroups.count();
    if (groupCount > 0) return;

    final groupId = _uuid.v4();
    final now = DateTime.now();

    await isar.writeTxn(() async {
      // 建立預設群組
      final group = FamilyGroup()
        ..id = groupId
        ..name = '我的家庭'
        ..isPrimary = true
        ..createdAt = now
        ..updatedAt = now;
      await isar.familyGroups.put(group);

      // 建立預設類別
      for (var i = 0; i < DefaultCategories.all.length; i++) {
        final name = DefaultCategories.all[i];
        final cat = Category()
          ..groupId = groupId
          ..name = name
          ..icon = DefaultCategories.icons[name] ?? '📌'
          ..sortOrder = i
          ..isDefault = true
          ..isActive = true;
        await isar.categorys.put(cat);
      }
    });
  }

  /// 取得目前主要群組 ID
  static Future<String?> getPrimaryGroupId() async {
    final isar = await instance;
    final group = await isar.familyGroups
        .filter()
        .isPrimaryEqualTo(true)
        .findFirst();
    return group?.id;
  }

  /// 取得目前使用者（本地切換）
  static Future<FamilyMember?> getCurrentUser() async {
    final isar = await instance;
    return await isar.familyMembers
        .filter()
        .isCurrentUserEqualTo(true)
        .findFirst();
  }

  /// 關閉資料庫
  static Future<void> close() async {
    await _isar?.close();
    _isar = null;
  }
}
