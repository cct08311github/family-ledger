import 'dart:io';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/family_group.dart';
import '../models/family_member.dart';
import '../models/expense.dart';
import '../models/balance.dart';
import '../models/category.dart';
import '../models/settlement.dart';
import '../models/activity_log.dart';
import '../models/app_notification.dart';
import '../models/enums.dart';
import 'package:uuid/uuid.dart';
import 'log_service.dart';

/// Isar 資料庫管理服務
class DatabaseService {
  static Isar? _isar;
  static const _uuid = Uuid();

  /// 取得 Isar 實例（單例）
  static Future<Isar> get instance async {
    if (_isar != null && _isar!.isOpen) return _isar!;
    return await _init();
  }

  static const _schemas = [
    FamilyGroupSchema,
    FamilyMemberSchema,
    ExpenseSchema,
    BalanceSchema,
    CategorySchema,
    SettlementSchema,
    ActivityLogSchema,
    AppNotificationSchema,
  ];

  /// 初始化資料庫（schema 不相容時自動重建）
  static Future<Isar> _init() async {
    final dir = await getApplicationDocumentsDirectory();

    try {
      _isar = await Isar.open(
        _schemas,
        directory: dir.path,
        name: 'family_ledger',
      );
      LogService.info(LogTag.DB, 'Isar opened at ${dir.path}');
    } catch (e) {
      // Schema 不相容 → 刪除舊 DB 重建（開發階段可接受）
      LogService.warning(LogTag.DB, 'Isar schema mismatch, rebuilding DB', e);
      await Isar.getInstance('family_ledger')?.close();
      final dbFile = File('${dir.path}/family_ledger.isar');
      if (await dbFile.exists()) await dbFile.delete();
      final lockFile = File('${dir.path}/family_ledger.isar.lock');
      if (await lockFile.exists()) await lockFile.delete();
      _isar = await Isar.open(
        _schemas,
        directory: dir.path,
        name: 'family_ledger',
      );
      LogService.info(LogTag.DB, 'Isar rebuilt successfully');
    }

    // 首次啟動：建立預設群組和類別
    await _seedDefaultData();

    return _isar!;
  }

  /// 建立預設資料
  static Future<void> _seedDefaultData() async {
    final isar = _isar!;

    // 檢查是否已有群組
    final groupCount = await isar.familyGroups.count();
    if (groupCount > 0) {
      LogService.debug(LogTag.DB, 'Existing data found ($groupCount groups)');
      return;
    }
    LogService.info(LogTag.DB, 'First launch, seeding default data');

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
