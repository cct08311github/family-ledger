import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/enums.dart';
import '../models/family_group.dart';
import '../models/family_member.dart';
import '../services/firestore_service.dart';

/// 目前登入使用者的 Firebase UID
final currentUidProvider = Provider<String?>((ref) {
  return FirebaseAuth.instance.currentUser?.uid;
});

/// 目前群組（從 Firestore 取得）
final currentGroupProvider = StreamProvider<FamilyGroup?>((ref) async* {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) {
    yield null;
    return;
  }

  // 先嘗試一次查詢取得 groupId
  final group = await FirestoreService.getPrimaryGroup(uid);
  if (group == null) {
    yield null;
    return;
  }

  // 然後監聽該群組的變化
  yield* FirestoreService.watchPrimaryGroup(group.id);
});

/// 初始化群組（若不存在則建立）
final initGroupProvider = FutureProvider<void>((ref) async {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return;

  final existing = await FirestoreService.getPrimaryGroup(uid);
  if (existing != null) return;

  // 建立新群組
  final groupId = await FirestoreService.createGroup('我的家庭');
  // 新群組建立後自動加入自己為成員
  await FirestoreService.addMember(
    groupId: groupId,
    name: '我',
    role: MemberRole.admin,
    isCurrentUser: true,
    sortOrder: 0,
  );
});

/// 監聽群組成員
final membersProvider = StreamProvider<List<FamilyMember>>((ref) async* {
  final group = await ref.watch(currentGroupProvider.future);
  if (group == null) {
    yield [];
    return;
  }
  yield* FirestoreService.watchMembers(group.id);
});

/// 監聽目前登入成員
final currentUserProvider = StreamProvider<FamilyMember?>((ref) async* {
  final members = await ref.watch(membersProvider.future);
  yield* Stream.value(
    members.where((m) => m.isCurrentUser).firstOrNull,
  );
});

final memberNotifierProvider =
    AsyncNotifierProvider<MemberNotifier, void>(MemberNotifier.new);

class MemberNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> addMember({required String name, bool isAdmin = false}) async {
    final group = await ref.read(currentGroupProvider.future);
    if (group == null) return;
    final members = await ref.read(membersProvider.future);
    final memberCount = members.length;
    await FirestoreService.addMember(
      groupId: group.id,
      name: name,
      role: isAdmin ? MemberRole.admin : MemberRole.member,
      isCurrentUser: memberCount == 0,
      sortOrder: memberCount,
    );
  }

  Future<void> updateMember(String memberId, String newName) async {
    final group = await ref.read(currentGroupProvider.future);
    if (group == null) return;
    final members = await ref.read(membersProvider.future);
    final member = members.where((m) => m.id == memberId).firstOrNull;
    if (member == null) return;
    member.name = newName;
    await FirestoreService.updateMember(group.id, member);
  }

  Future<void> deleteMember(String memberId) async {
    final group = await ref.read(currentGroupProvider.future);
    if (group == null) return;
    await FirestoreService.deleteMember(group.id, memberId);
  }

  Future<void> switchUser(String memberId) async {
    final group = await ref.read(currentGroupProvider.future);
    if (group == null) return;
    final members = await ref.read(membersProvider.future);
    final batch = FirebaseFirestore.instance.batch();
    for (final m in members) {
      final updated = FamilyMember()
        ..id = m.id
        ..groupId = m.groupId
        ..name = m.name
        ..role = m.role
        ..sortOrder = m.sortOrder
        ..isCurrentUser = (m.id == memberId)
        ..createdAt = m.createdAt
        ..updatedAt = DateTime.now();
      batch.update(
        FirebaseFirestore.instance.collection('groups').doc(group.id).collection('members').doc(m.id),
        updated.toFirestore(),
      );
    }
    await batch.commit();
    ref.invalidate(membersProvider);
  }
}
