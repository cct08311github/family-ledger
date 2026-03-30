import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';
import 'package:isar/isar.dart';
import '../models/expense.dart';
import '../models/family_member.dart';
import '../models/family_group.dart';
import '../models/settlement.dart';
import '../models/enums.dart';
import '../models/split_detail.dart';
import 'database_service.dart';
import 'network_info_service.dart';

/// 同步狀態枚舉
enum SyncStatus {
  idle,       // 閒置
  syncing,    // 同步中
  error,       // 同步錯誤
  offline,     // 離線
}

/// Firebase Firestore 雙向同步服務
///
/// 資料結構：
///   groups/{groupId}
///   groups/{groupId}/members/{memberId}
///   groups/{groupId}/expenses/{expenseId}
///   groups/{groupId}/settlements/{settlementId}
///
/// 使用前必須：
/// 1. 在 Firebase Console 建立專案
/// 2. 執行 `flutterfire configure` 產生 firebase_options.dart
/// 3. 在 main.dart 呼叫 `Firebase.initializeApp()`
/// 4. 設定 Firestore Security Rules
class FirebaseSyncService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// 目前登入的 Firebase 使用者
  static User? get currentUser => AuthService.currentUser;

  /// 是否已登入（需同時網路連線）
  static bool get isSignedIn =>
      AuthService.hasAnyAuth &&
      NetworkInfoService.status == NetworkStatus.online;

  /// 是否已登入（不含網路檢查，用於本地操作）
  static bool get isAuthed => AuthService.hasAnyAuth;

  /// 同步狀態
  static SyncStatus syncStatus = SyncStatus.idle;
  static StreamSubscription? _expenseListener;
  static StreamSubscription? _settlementListener;
  static StreamSubscription? _memberListener;
  static StreamSubscription? _groupListener;
  static String? _syncedGroupId;

  /// 匿名登入（舊方法，保留向下相容）
  static Future<User?> signInAnonymously() async {
    return await AuthService.signInAnonymously();
  }

  /// 首次同步：把本地群組、成員、支出、結算上傳到 Firestore
  static Future<void> initialSync() async {
    if (!isAuthed) return;

    // 檢查網路連線
    final isOnline = await NetworkInfoService.isNetworkAvailable();
    if (!isOnline) {
      syncStatus = SyncStatus.offline;
      return;
    }

    syncStatus = SyncStatus.syncing;
    final isar = await DatabaseService.instance;
    final groupId = await DatabaseService.getPrimaryGroupId();
    if (groupId == null) {
      syncStatus = SyncStatus.idle;
      return;
    }

    // 上傳群組
    final group = await isar.familyGroups.filter().idEqualTo(groupId).findFirst();
    if (group != null) await syncGroupUp(group);

    // 上傳所有成員
    final members = await isar.familyMembers.filter().groupIdEqualTo(groupId).findAll();
    for (final m in members) {
      await syncMemberUp(groupId, m);
    }

    // 上傳所有支出
    final expenses = await isar.expenses.filter().groupIdEqualTo(groupId).findAll();
    for (final e in expenses) {
      await syncExpenseUp(groupId, e);
    }

    // 上傳所有結算
    final settlements = await isar.settlements.filter().groupIdEqualTo(groupId).findAll();
    for (final s in settlements) {
      await syncSettlementUp(groupId, s);
    }

    // 開始即時監聽
    startRealtimeSync(groupId);
    syncStatus = SyncStatus.idle;
  }

  /// 開始即時監聽 Firestore 變更（支出 + 結算）
  static void startRealtimeSync(String groupId) {
    if (_syncedGroupId == groupId) return; // 已在監聽
    stopRealtimeSync();
    _syncedGroupId = groupId;

    // 監聽遠端支出變更
    _expenseListener = _expensesRef(groupId)
        .snapshots()
        .listen((snapshot) async {
      for (final change in snapshot.docChanges) {
        try {
          if (change.type == DocumentChangeType.removed) {
            // 遠端刪除 → 本地刪除
            final isar = await DatabaseService.instance;
            final local = await isar.expenses.filter().idEqualTo(change.doc.id).findFirst();
            if (local != null) {
              await isar.writeTxn(() async {
                await isar.expenses.delete(local.isarId);
              });
            }
          } else {
            // 新增或修改 → merge 到本地
            final data = change.doc.data();
            if (data != null) {
              await mergeExpenseFromRemote(data, change.doc.id);
            }
          }
        } catch (e, st) {
          // 防禦性：單筆同步失敗不影響其他文件
          if (kDebugMode) debugPrint('Expense sync error: $e\n$st');
        }
      }
    }, onError: (e) {
      // Firestore 監聽錯誤（如 permission denied）靜默忽略，不導致閃退
      if (kDebugMode) debugPrint('Expense listener error: $e');
    });

    // 監聽遠端結算變更
    _settlementListener = _settlementsRef(groupId)
        .snapshots()
        .listen((snapshot) async {
      for (final change in snapshot.docChanges) {
        try {
          if (change.type == DocumentChangeType.removed) {
            final isar = await DatabaseService.instance;
            final local = await isar.settlements.filter().idEqualTo(change.doc.id).findFirst();
            if (local != null) {
              await isar.writeTxn(() async {
                await isar.settlements.delete(local.isarId);
              });
            }
          } else {
            final data = change.doc.data();
            if (data != null) {
              await _mergeSettlementFromRemote(data, change.doc.id);
            }
          }
        } catch (e, st) {
          // 防禦性：單筆同步失敗不影響其他文件
          if (kDebugMode) debugPrint('Settlement sync error: $e\n$st');
        }
      }
    }, onError: (e) {
      // Firestore 監聽錯誤（如 permission denied）靜默忽略，不導致閃退
      if (kDebugMode) debugPrint('Settlement listener error: $e');
      syncStatus = SyncStatus.error;
    });

    // 監聽遠端成員變更
    _memberListener = _membersRef(groupId)
        .snapshots()
        .listen((snapshot) async {
      for (final change in snapshot.docChanges) {
        try {
          if (change.type == DocumentChangeType.removed) {
            final isar = await DatabaseService.instance;
            final local = await isar.familyMembers.filter().idEqualTo(change.doc.id).findFirst();
            if (local != null) {
              await isar.writeTxn(() async {
                await isar.familyMembers.delete(local.isarId);
              });
            }
          } else {
            final data = change.doc.data();
            if (data != null) {
              await _mergeMemberFromRemote(data, change.doc.id);
            }
          }
        } catch (e, st) {
          if (kDebugMode) debugPrint('Member sync error: $e\n$st');
        }
      }
    }, onError: (e) {
      if (kDebugMode) debugPrint('Member listener error: $e');
      syncStatus = SyncStatus.error;
    });

    // 監聽遠端群組變更（如邀請加入、邀請碼更新等）
    _groupListener = _groupDoc(groupId)
        .snapshots()
        .listen((snapshot) async {
      try {
        final data = snapshot.data();
        if (data == null) return;
        await _mergeGroupFromRemote(data, groupId);
      } catch (e, st) {
        if (kDebugMode) debugPrint('Group sync error: $e\n$st');
      }
    }, onError: (e) {
      if (kDebugMode) debugPrint('Group listener error: $e');
      syncStatus = SyncStatus.error;
    });
  }

  /// 停止即時監聽
  static void stopRealtimeSync() {
    _expenseListener?.cancel();
    _settlementListener?.cancel();
    _memberListener?.cancel();
    _groupListener?.cancel();
    _expenseListener = null;
    _settlementListener = null;
    _memberListener = null;
    _groupListener = null;
    _syncedGroupId = null;
  }

  /// 將遠端結算寫入本地 Isar
  /// 含防禦性型別檢查，避免格式錯誤的資料 crash app
  static Future<void> _mergeSettlementFromRemote(
      Map<String, dynamic> data, String settlementId) async {
    try {
      final isar = await DatabaseService.instance;
      final local = await isar.settlements.filter().idEqualTo(settlementId).findFirst();

      final createdAtRaw = data['createdAt'];
      if (createdAtRaw is! Timestamp) return; // 缺少必要欄位，跳過
      final remoteCreatedAt = createdAtRaw.toDate();

      // 如果本地已有且較新，跳過
      if (local != null && local.createdAt.isAfter(remoteCreatedAt)) return;

      final settlement = Settlement()
        ..id = settlementId
        ..groupId = (await DatabaseService.getPrimaryGroupId()) ?? ''
        ..fromMemberId = (data['fromMemberId'] as String?) ?? ''
        ..fromMemberName = (data['fromMemberName'] as String?) ?? ''
        ..toMemberId = (data['toMemberId'] as String?) ?? ''
        ..toMemberName = (data['toMemberName'] as String?) ?? ''
        ..amount = (data['amount'] as num?)?.toDouble() ?? 0
        ..note = data['note'] as String?
        ..date = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now()
        ..createdAt = remoteCreatedAt;

      if (local != null) settlement.isarId = local.isarId;

      await isar.writeTxn(() async {
        await isar.settlements.put(settlement);
      });
    } catch (e, st) {
      // 防禦性：任何反序列化錯誤靜默忽略，不影響 app 運行
      if (kDebugMode) debugPrint('Settlement deserialize error: $e\n$st');
    }
  }

  /// 將遠端成員寫入本地 Isar
  static Future<void> _mergeMemberFromRemote(
      Map<String, dynamic> data, String memberId) async {
    try {
      final isar = await DatabaseService.instance;
      final local = await isar.familyMembers.filter().idEqualTo(memberId).findFirst();

      final createdAtRaw = data['createdAt'];
      if (createdAtRaw is! Timestamp) return;

      final member = FamilyMember()
        ..id = memberId
        ..groupId = (await DatabaseService.getPrimaryGroupId()) ?? ''
        ..name = (data['name'] as String?) ?? ''
        ..isCurrentUser = (data['isCurrentUser'] as bool?) ?? false
        ..createdAt = createdAtRaw.toDate();

      if (local != null) member.isarId = local.isarId;

      await isar.writeTxn(() async {
        await isar.familyMembers.put(member);
      });
    } catch (e, st) {
      if (kDebugMode) debugPrint('Member deserialize error: $e\n$st');
    }
  }

  /// 將遠端群組寫入本地 Isar
  /// 成員名單（memberUids）僅存於 Firestore，不同步至 Isar
  static Future<void> _mergeGroupFromRemote(
      Map<String, dynamic> data, String groupId) async {
    // FamilyGroup Isar 模型不儲存 memberUids（僅用於 Firestore 安全規則）
    // 目前群組層級無需同步至 Isar
  }

  // ── 群組同步 ──

  static CollectionReference<Map<String, dynamic>> _groupsRef() =>
      _db.collection('groups');

  static DocumentReference<Map<String, dynamic>> _groupDoc(String groupId) =>
      _groupsRef().doc(groupId);

  /// 將本地群組上傳到 Firestore
  static Future<void> syncGroupUp(FamilyGroup group) async {
    final uid = currentUser?.uid;
    await _groupDoc(group.id).set({
      'name': group.name,
      'isPrimary': group.isPrimary,
      'createdAt': Timestamp.fromDate(group.createdAt),
      'updatedAt': Timestamp.fromDate(group.updatedAt),
      'ownerUid': uid,
      // memberUids 用於 Security Rules 驗證成員身份
      if (uid != null) 'memberUids': FieldValue.arrayUnion([uid]),
    }, SetOptions(merge: true));
  }

  /// 將 Firebase UID 加入群組成員清單（邀請加入時呼叫）
  static Future<void> addMemberUid(String groupId, String uid) async {
    await _groupDoc(groupId).update({
      'memberUids': FieldValue.arrayUnion([uid]),
    });
  }

  /// 將 Firebase UID 從群組移除
  static Future<void> removeMemberUid(String groupId, String uid) async {
    await _groupDoc(groupId).update({
      'memberUids': FieldValue.arrayRemove([uid]),
    });
  }

  // ── 成員同步 ──

  static CollectionReference<Map<String, dynamic>> _membersRef(String groupId) =>
      _groupDoc(groupId).collection('members');

  static Future<void> syncMemberUp(String groupId, FamilyMember member) async {
    await _membersRef(groupId).doc(member.id).set({
      'name': member.name,
      'isCurrentUser': member.isCurrentUser,
      'createdAt': Timestamp.fromDate(member.createdAt),
    }, SetOptions(merge: true));
  }

  static Future<void> deleteMemberRemote(String groupId, String memberId) async {
    await _membersRef(groupId).doc(memberId).delete();
  }

  // ── 支出同步 ──

  static CollectionReference<Map<String, dynamic>> _expensesRef(String groupId) =>
      _groupDoc(groupId).collection('expenses');

  static Future<void> syncExpenseUp(String groupId, Expense expense) async {
    await _expensesRef(groupId).doc(expense.id).set({
      'date': Timestamp.fromDate(expense.date),
      'description': expense.description,
      'amount': expense.amount,
      'category': expense.category,
      'isShared': expense.isShared,
      'splitMethod': expense.splitMethod.name,
      'payerId': expense.payerId,
      'payerName': expense.payerName,
      'paymentMethod': expense.paymentMethod.name,
      'splits': expense.splits.map((s) => {
        'memberId': s.memberId,
        'memberName': s.memberName,
        'shareAmount': s.shareAmount,
        'paidAmount': s.paidAmount,
        'isParticipant': s.isParticipant,
      }).toList(),
      'receiptPath': expense.receiptPath,
      'receiptPaths': expense.receiptPaths,
      'note': expense.note,
      'createdBy': expense.createdBy,
      'createdAt': Timestamp.fromDate(expense.createdAt),
      'updatedAt': Timestamp.fromDate(expense.updatedAt),
    }, SetOptions(merge: true));
  }

  static Future<void> deleteExpenseRemote(String groupId, String expenseId) async {
    await _expensesRef(groupId).doc(expenseId).delete();
  }

  // ── 結算同步 ──

  static CollectionReference<Map<String, dynamic>> _settlementsRef(String groupId) =>
      _groupDoc(groupId).collection('settlements');

  static Future<void> syncSettlementUp(String groupId, Settlement settlement) async {
    await _settlementsRef(groupId).doc(settlement.id).set({
      'fromMemberId': settlement.fromMemberId,
      'fromMemberName': settlement.fromMemberName,
      'toMemberId': settlement.toMemberId,
      'toMemberName': settlement.toMemberName,
      'amount': settlement.amount,
      'note': settlement.note,
      'date': Timestamp.fromDate(settlement.date),
      'createdAt': Timestamp.fromDate(settlement.createdAt),
    }, SetOptions(merge: true));
  }

  static Future<void> deleteSettlementRemote(String groupId, String settlementId) async {
    await _settlementsRef(groupId).doc(settlementId).delete();
  }

  // ── 下載同步（Firestore → 本地 Isar） ──

  /// 將遠端支出寫入本地 Isar（merge 邏輯：以 updatedAt 較新者為準）
  /// 含防禦性型別檢查，避免惡意或格式錯誤的資料 crash app
  static Future<void> mergeExpenseFromRemote(
      Map<String, dynamic> data, String expenseId) async {
    try {
      final isar = await DatabaseService.instance;
      final local = await isar.expenses.filter().idEqualTo(expenseId).findFirst();

      final updatedAtRaw = data['updatedAt'];
      if (updatedAtRaw is! Timestamp) return; // 缺少必要欄位，跳過
      final remoteUpdatedAt = updatedAtRaw.toDate();

      if (local != null && local.updatedAt.isAfter(remoteUpdatedAt)) return;

      // 防禦性解析：每個欄位都有 fallback
      final description = (data['description'] as String?) ?? '';
      if (description.isEmpty) return; // 無效資料

      final amount = (data['amount'] as num?)?.toDouble() ?? 0;
      if (amount <= 0 || amount >= 100000000) return; // 金額不合理

      final expense = Expense()
        ..id = expenseId
        ..groupId = (await DatabaseService.getPrimaryGroupId()) ?? ''
        ..date = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now()
        ..description = description.length > 200 ? description.substring(0, 200) : description
        ..amount = amount
        ..category = (data['category'] as String?) ?? '其他'
        ..isShared = (data['isShared'] as bool?) ?? false
        ..splitMethod = SplitMethod.values.firstWhere(
            (e) => e.name == data['splitMethod'],
            orElse: () => SplitMethod.equal)
        ..payerId = (data['payerId'] as String?) ?? ''
        ..payerName = (data['payerName'] as String?) ?? ''
        ..paymentMethod = PaymentMethod.values.firstWhere(
            (e) => e.name == (data['paymentMethod'] ?? 'cash'),
            orElse: () => PaymentMethod.cash)
        ..splits = ((data['splits'] as List?) ?? []).whereType<Map>().map((s) {
          final map = s as Map<String, dynamic>;
          return SplitDetail()
            ..memberId = (map['memberId'] as String?) ?? ''
            ..memberName = (map['memberName'] as String?) ?? ''
            ..shareAmount = (map['shareAmount'] as num?)?.toDouble() ?? 0
            ..paidAmount = (map['paidAmount'] as num?)?.toDouble() ?? 0
            ..isParticipant = (map['isParticipant'] as bool?) ?? false;
        }).toList()
        ..receiptPath = data['receiptPath'] as String?
        ..receiptPaths = ((data['receiptPaths'] as List?) ?? []).whereType<String>().toList()
        ..note = data['note'] as String?
        ..createdBy = (data['createdBy'] as String?) ?? ''
        ..createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now()
        ..updatedAt = remoteUpdatedAt;

    // 保留本地 isarId
    if (local != null) expense.isarId = local.isarId;

      await isar.writeTxn(() async {
        await isar.expenses.put(expense);
      });
    } catch (e, st) {
      // 防禦性：任何反序列化錯誤靜默忽略，不影響 app 運行
      if (kDebugMode) debugPrint('Expense deserialize error: $e\n$st');
    }
  }

  // ── 邀請碼加入群組 ──

  /// 產生 8 碼加密安全邀請碼（24 小時有效，最多使用 5 次）
  static Future<String> generateInviteCode(String groupId) async {
    const charset = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // 去除易混淆字元 0OI1
    final random = Random.secure();
    final code = List.generate(8, (_) => charset[random.nextInt(charset.length)]).join();
    await _groupDoc(groupId).update({
      'inviteCode': code,
      'inviteExpiry': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24))),
      'inviteUsedCount': 0,
      'inviteMaxUses': 5,
    });
    return code;
  }

  /// 用邀請碼加入群組（同時將 UID 加入 memberUids，含使用次數限制）
  static Future<String?> joinGroupByCode(String code) async {
    final snap = await _groupsRef()
        .where('inviteCode', isEqualTo: code)
        .where('inviteExpiry', isGreaterThan: Timestamp.now())
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;

    final doc = snap.docs.first;
    final data = doc.data();
    final usedCount = (data['inviteUsedCount'] as num?) ?? 0;
    final maxUses = (data['inviteMaxUses'] as num?) ?? 5;
    if (usedCount >= maxUses) return null; // 已達使用上限

    final groupId = doc.id;
    final uid = currentUser?.uid;
    if (uid != null) {
      await _groupDoc(groupId).update({
        'memberUids': FieldValue.arrayUnion([uid]),
        'inviteUsedCount': FieldValue.increment(1),
      });
    }
    return groupId;
  }
}
