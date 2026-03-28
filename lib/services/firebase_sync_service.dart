import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:isar/isar.dart';
import '../models/expense.dart';
import '../models/family_member.dart';
import '../models/family_group.dart';
import '../models/settlement.dart';
import '../models/enums.dart';
import '../models/split_detail.dart';
import 'database_service.dart';

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
  static FirebaseAuth get _auth => FirebaseAuth.instance;

  /// 目前登入的 Firebase 使用者
  static User? get currentUser => _auth.currentUser;

  /// 是否已登入
  static bool get isSignedIn => currentUser != null;

  // ── 匿名登入（最簡方案，可後續升級為 Google Sign-In） ──

  static Future<User?> signInAnonymously() async {
    final credential = await _auth.signInAnonymously();
    return credential.user;
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

  /// 監聽遠端支出變更，即時同步到本地
  static Stream<QuerySnapshot<Map<String, dynamic>>> watchExpenses(String groupId) {
    return _expensesRef(groupId).orderBy('updatedAt', descending: true).snapshots();
  }

  /// 將遠端支出寫入本地 Isar（merge 邏輯：以 updatedAt 較新者為準）
  static Future<void> mergeExpenseFromRemote(
      Map<String, dynamic> data, String expenseId) async {
    final isar = await DatabaseService.instance;
    final local = await isar.expenses.filter().idEqualTo(expenseId).findFirst();

    final remoteUpdatedAt = (data['updatedAt'] as Timestamp).toDate();

    // 如果本地已有且較新，跳過
    if (local != null && local.updatedAt.isAfter(remoteUpdatedAt)) return;

    final expense = Expense()
      ..id = expenseId
      ..groupId = (await DatabaseService.getPrimaryGroupId()) ?? ''
      ..date = (data['date'] as Timestamp).toDate()
      ..description = data['description'] as String
      ..amount = (data['amount'] as num).toDouble()
      ..category = data['category'] as String
      ..isShared = data['isShared'] as bool
      ..splitMethod = SplitMethod.values.firstWhere(
          (e) => e.name == data['splitMethod'],
          orElse: () => SplitMethod.equal)
      ..payerId = data['payerId'] as String
      ..payerName = data['payerName'] as String
      ..paymentMethod = PaymentMethod.values.firstWhere(
          (e) => e.name == (data['paymentMethod'] ?? 'cash'),
          orElse: () => PaymentMethod.cash)
      ..splits = ((data['splits'] as List?) ?? []).map((s) {
        final map = s as Map<String, dynamic>;
        return SplitDetail()
          ..memberId = map['memberId'] as String
          ..memberName = map['memberName'] as String
          ..shareAmount = (map['shareAmount'] as num).toDouble()
          ..paidAmount = (map['paidAmount'] as num).toDouble()
          ..isParticipant = map['isParticipant'] as bool;
      }).toList()
      ..receiptPath = data['receiptPath'] as String?
      ..note = data['note'] as String?
      ..createdBy = data['createdBy'] as String
      ..createdAt = (data['createdAt'] as Timestamp).toDate()
      ..updatedAt = remoteUpdatedAt;

    // 保留本地 isarId
    if (local != null) expense.isarId = local.isarId;

    await isar.writeTxn(() async {
      await isar.expenses.put(expense);
    });
  }

  // ── 邀請碼加入群組 ──

  /// 產生 6 碼邀請碼（存在群組 doc 上）
  static Future<String> generateInviteCode(String groupId) async {
    final code = DateTime.now().millisecondsSinceEpoch.toRadixString(36).substring(2, 8).toUpperCase();
    await _groupDoc(groupId).update({
      'inviteCode': code,
      'inviteExpiry': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24))),
    });
    return code;
  }

  /// 用邀請碼加入群組（同時將 UID 加入 memberUids）
  static Future<String?> joinGroupByCode(String code) async {
    final snap = await _groupsRef()
        .where('inviteCode', isEqualTo: code)
        .where('inviteExpiry', isGreaterThan: Timestamp.now())
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final groupId = snap.docs.first.id;
    final uid = currentUser?.uid;
    if (uid != null) {
      await addMemberUid(groupId, uid);
    }
    return groupId;
  }
}
