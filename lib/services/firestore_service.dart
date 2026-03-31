import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../config/app_constants.dart';
import '../models/expense.dart';
import '../models/family_group.dart';
import '../models/family_member.dart';
import '../models/settlement.dart';
import '../models/category.dart';
import '../models/activity_log.dart';
import '../models/app_notification.dart';
import '../models/enums.dart';
import 'auth_service.dart';

const _uuid = Uuid();

/// Firestore 直接讀寫服務（取代 FirebaseSyncService 的雙向同步）
///
/// Firestore 路徑：
///   groups/{groupId}
///   groups/{groupId}/members/{memberId}
///   groups/{groupId}/expenses/{expenseId}
///   groups/{groupId}/settlements/{settlementId}
///   groups/{groupId}/categories/{categoryId}
///   groups/{groupId}/balances/{balanceId}
///   groups/{groupId}/activityLogs/{logId}
///   groups/{groupId}/notifications/{notifId}
class FirestoreService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static User? get _user => AuthService.currentUser;

  FirestoreService._();

  // ═══════════════════════════════════════════════════════
  // 啟用 Firestore 離線持久化（在 main() 初始化 Firebase 後呼叫一次）
  // ═══════════════════════════════════════════════════════

  static Future<void> enableOfflinePersistence() async {
    // Firestore SDK 預設已啟用 persistence，無需額外設定
    // 如需自訂可使用：
    // await _db.settings;
    // _db.settings = Settings(persistenceEnabled: true);
  }

  // ═══════════════════════════════════════════════════════
  // 查詢目前使用者的主要群組
  // ═══════════════════════════════════════════════════════

  /// 查詢成員所屬的主要群組（memberUids 包含 uid）
  static Future<FamilyGroup?> getPrimaryGroup(String uid) async {
    // 查詢 ownerUid = uid 的群組（自己建立的群組）
    final ownerSnap = await _groupRef()
        .where('ownerUid', isEqualTo: uid)
        .where('isPrimary', isEqualTo: true)
        .limit(1)
        .get();
    if (ownerSnap.docs.isNotEmpty) {
      final d = ownerSnap.docs.first;
      return FamilyGroup.fromFirestore(d.data(), d.id);
    }
    // 查詢 memberUids 包含 uid 的群組（被邀請加入的群組）
    final memberSnap = await _groupRef()
        .where('memberUids', arrayContains: uid)
        .where('isPrimary', isEqualTo: true)
        .limit(1)
        .get();
    if (memberSnap.docs.isNotEmpty) {
      final d = memberSnap.docs.first;
      return FamilyGroup.fromFirestore(d.data(), d.id);
    }
    return null;
  }

  /// 監聽目前使用者的主要群組（需傳入 groupId）
  static Stream<FamilyGroup?> watchPrimaryGroup(String groupId) {
    return _groupDoc(groupId).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return FamilyGroup.fromFirestore(snap.data()!, snap.id);
    });
  }

  /// 監聽成員所屬群組（memberUids 包含 uid）— 即時更新
  static Stream<List<FamilyGroup>> watchGroups(String uid) {
    // 監聽所有自己建立的群組
    final ownerStream = _groupRef()
        .where('ownerUid', isEqualTo: uid)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => FamilyGroup.fromFirestore(d.data(), d.id))
            .toList());
    // 合併兩個 stream
    return ownerStream.asyncMap((ownerGroups) async {
      final memberSnap = await _groupRef()
          .where('memberUids', arrayContains: uid)
          .get();
      final memberGroups = memberSnap.docs
          .map((d) => FamilyGroup.fromFirestore(d.data(), d.id))
          .toList();
      return [...ownerGroups, ...memberGroups];
    });
  }

  // ═══════════════════════════════════════════════════════
  // Collection 參照
  // ═══════════════════════════════════════════════════════

  static CollectionReference<Map<String, dynamic>> _groupRef() =>
      _db.collection('groups');

  static DocumentReference<Map<String, dynamic>> _groupDoc(String groupId) =>
      _groupRef().doc(groupId);

  static CollectionReference<Map<String, dynamic>> _membersRef(String groupId) =>
      _groupDoc(groupId).collection('members');

  static CollectionReference<Map<String, dynamic>> _expensesRef(String groupId) =>
      _groupDoc(groupId).collection('expenses');

  static CollectionReference<Map<String, dynamic>> _settlementsRef(String groupId) =>
      _groupDoc(groupId).collection('settlements');

  static CollectionReference<Map<String, dynamic>> _categoriesRef(String groupId) =>
      _groupDoc(groupId).collection('categories');

  static CollectionReference<Map<String, dynamic>> _activityLogsRef(String groupId) =>
      _groupDoc(groupId).collection('activityLogs');

  static CollectionReference<Map<String, dynamic>> _notificationsRef(String groupId) =>
      _groupDoc(groupId).collection('notifications');

  // ═══════════════════════════════════════════════════════
  // 群組
  // ═══════════════════════════════════════════════════════

  /// 建立新群組
  static Future<String> createGroup(String name) async {
    final uid = _user?.uid;
    if (uid == null) throw Exception('未登入');
    final ref = _groupRef().doc();
    await ref.set({
      'name': name,
      'isPrimary': true,
      'ownerUid': uid,
      'memberUids': [uid],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// 更新群組
  static Future<void> updateGroup(String groupId, {String? name, List<String>? memberUids}) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (name != null) updates['name'] = name;
    if (memberUids != null) updates['memberUids'] = memberUids;
    await _groupDoc(groupId).update(updates);
  }

  // ═══════════════════════════════════════════════════════
  // 成員
  // ═══════════════════════════════════════════════════════

  /// 監聽群組成員
  static Stream<List<FamilyMember>> watchMembers(String groupId) {
    return _membersRef(groupId)
        .orderBy('sortOrder')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => FamilyMember.fromFirestore(d.data(), d.id))
            .toList());
  }

  /// 新增成員
  static Future<String> addMember({
    required String groupId,
    required String name,
    required MemberRole role,
    required bool isCurrentUser,
    required int sortOrder,
  }) async {
    final ref = _membersRef(groupId).doc();
    await ref.set({
      'groupId': groupId,
      'name': name,
      'role': role.name,
      'isCurrentUser': isCurrentUser,
      'sortOrder': sortOrder,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// 更新成員
  static Future<void> updateMember(String groupId, FamilyMember member) async {
    await _membersRef(groupId).doc(member.id).update(member.toFirestore());
  }

  /// 刪除成員
  static Future<void> deleteMember(String groupId, String memberId) async {
    await _membersRef(groupId).doc(memberId).delete();
  }

  // ═══════════════════════════════════════════════════════
  // 支出
  // ═══════════════════════════════════════════════════════

  /// 監聽所有支出（依日期排序，最新在前）
  static Stream<List<Expense>> watchExpenses(String groupId) {
    return _expensesRef(groupId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Expense.fromFirestore(d.data(), d.id))
            .toList());
  }

  /// 監聽當月支出
  static Stream<List<Expense>> watchMonthlyExpenses(String groupId, int year, int month) {
    final startOfMonth = DateTime(year, month, 1);
    final endOfMonth = DateTime(year, month + 1, 0, 23, 59, 59);
    return _expensesRef(groupId)
        .orderBy('date', descending: true)
        .startAt([Timestamp.fromDate(startOfMonth)])
        .endAt([Timestamp.fromDate(endOfMonth)])
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Expense.fromFirestore(d.data(), d.id))
            .toList());
  }

  /// 新增支出
  static Future<String> addExpense(Expense expense) async {
    expense.id = _uuid.v4();
    expense.createdAt = DateTime.now();
    expense.updatedAt = DateTime.now();
    await _expensesRef(expense.groupId).doc(expense.id).set(expense.toFirestore());
    return expense.id;
  }

  /// 更新支出
  static Future<void> updateExpense(Expense expense) async {
    expense.updatedAt = DateTime.now();
    await _expensesRef(expense.groupId).doc(expense.id).update(expense.toFirestore());
  }

  /// 刪除支出
  static Future<void> deleteExpense(String groupId, String expenseId) async {
    await _expensesRef(groupId).doc(expenseId).delete();
  }

  // ═══════════════════════════════════════════════════════
  // 結算
  // ═══════════════════════════════════════════════════════

  /// 監聽所有結算（依日期排序，最新在前）
  static Stream<List<Settlement>> watchSettlements(String groupId) {
    return _settlementsRef(groupId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Settlement.fromFirestore(d.data(), d.id))
            .toList());
  }

  /// 新增結算
  static Future<String> addSettlement(Settlement settlement) async {
    settlement.id = _uuid.v4();
    settlement.createdAt = DateTime.now();
    await _settlementsRef(settlement.groupId).doc(settlement.id).set(settlement.toFirestore());
    return settlement.id;
  }

  /// 刪除結算
  static Future<void> deleteSettlement(String groupId, String settlementId) async {
    await _settlementsRef(groupId).doc(settlementId).delete();
  }

  // ═══════════════════════════════════════════════════════
  // 類別
  // ═══════════════════════════════════════════════════════

  /// 監聽啟用的類別（排序）
  static Stream<List<Category>> watchActiveCategories(String groupId) {
    return _categoriesRef(groupId)
        .where('isActive', isEqualTo: true)
        .orderBy('sortOrder')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Category.fromFirestore(d.data(), d.id))
            .toList());
  }

  /// 監聽所有類別
  static Stream<List<Category>> watchAllCategories(String groupId) {
    return _categoriesRef(groupId)
        .orderBy('sortOrder')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Category.fromFirestore(d.data(), d.id))
            .toList());
  }

  /// 新增類別
  static Future<String> addCategory(Category category) async {
    category.id = _uuid.v4();
    await _categoriesRef(category.groupId).doc(category.id).set(category.toFirestore());
    return category.id;
  }

  /// 更新類別
  static Future<void> updateCategory(Category category) async {
    await _categoriesRef(category.groupId).doc(category.id).update(category.toFirestore());
  }

  /// 刪除類別
  static Future<void> deleteCategory(String groupId, String categoryId) async {
    await _categoriesRef(groupId).doc(categoryId).delete();
  }

  // ═══════════════════════════════════════════════════════
  // 活動日誌（append-only）
  // ═══════════════════════════════════════════════════════

  /// 監聽最近日誌
  static Stream<List<ActivityLog>> watchActivityLogs(String groupId, {int limit = 100}) {
    return _activityLogsRef(groupId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ActivityLog.fromFirestore(d.data(), d.id))
            .toList());
  }

  /// 新增日誌
  static Future<void> addActivityLog(String groupId, ActivityLog log) async {
    log.id = _uuid.v4();
    await _activityLogsRef(groupId).doc(log.id).set(log.toFirestore());
  }

  // ═══════════════════════════════════════════════════════
  // 通知
  // ═══════════════════════════════════════════════════════

  /// 監聽目前使用者的通知
  static Stream<List<AppNotification>> watchNotifications(String groupId, String recipientId) {
    return _notificationsRef(groupId)
        .where('recipientId', isEqualTo: recipientId)
        .orderBy('createdAt', descending: true)
        .limit(AppConstants.notificationLimit)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AppNotification.fromFirestore(d.data(), d.id))
            .toList());
  }

  /// 新增通知
  static Future<String> addNotification(String groupId, AppNotification notif) async {
    notif.id = _uuid.v4();
    notif.createdAt = DateTime.now();
    await _notificationsRef(groupId).doc(notif.id).set(notif.toFirestore());
    return notif.id;
  }

  /// 標記已讀
  static Future<void> markNotificationRead(String groupId, String notifId) async {
    await _notificationsRef(groupId).doc(notifId).update({'isRead': true});
  }

  /// 標記全部已讀
  static Future<void> markAllNotificationsRead(String groupId, String recipientId) async {
    final snap = await _notificationsRef(groupId)
        .where('recipientId', isEqualTo: recipientId)
        .where('isRead', isEqualTo: false)
        .get();
    if (snap.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }
}
