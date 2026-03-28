import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';
import '../models/family_group.dart';
import '../models/family_member.dart';
import '../services/database_service.dart';

const _uuid = Uuid();

final currentGroupProvider = FutureProvider<FamilyGroup?>((ref) async {
  final isar = await DatabaseService.instance;
  return isar.familyGroups.filter().isPrimaryEqualTo(true).findFirst();
});

final initGroupProvider = FutureProvider<void>((ref) async {
  final isar = await DatabaseService.instance;
  final count = await isar.familyGroups.count();
  if (count == 0) {
    await isar.writeTxn(() async {
      final now = DateTime.now();
      await isar.familyGroups.put(FamilyGroup()
        ..id = _uuid.v4()
        ..name = '我的家庭'
        ..isPrimary = true
        ..createdAt = now
        ..updatedAt = now);
    });
  }
});

final membersProvider = StreamProvider<List<FamilyMember>>((ref) async* {
  final isar = await DatabaseService.instance;
  yield* isar.familyMembers
      .where()
      .sortBySortOrder()
      .watch(fireImmediately: true);
});

final currentUserProvider = StreamProvider<FamilyMember?>((ref) async* {
  final isar = await DatabaseService.instance;
  yield* isar.familyMembers
      .filter()
      .isCurrentUserEqualTo(true)
      .watch(fireImmediately: true)
      .map((list) => list.isEmpty ? null : list.first);
});

final memberNotifierProvider =
    AsyncNotifierProvider<MemberNotifier, void>(MemberNotifier.new);

class MemberNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> addMember({required String name, bool isAdmin = false}) async {
    final isar = await DatabaseService.instance;
    final groupId = await DatabaseService.getPrimaryGroupId();
    if (groupId == null) return;
    final memberCount = await isar.familyMembers.count();
    await isar.writeTxn(() async {
      final member = FamilyMember()
        ..id = _uuid.v4()
        ..groupId = groupId
        ..name = name
        ..role = isAdmin ? MemberRole.admin : MemberRole.member
        ..sortOrder = memberCount
        ..isCurrentUser = memberCount == 0
        ..createdAt = DateTime.now();
      await isar.familyMembers.put(member);
    });
  }

  Future<void> updateMember(String memberId, String newName) async {
    final isar = await DatabaseService.instance;
    await isar.writeTxn(() async {
      final member = await isar.familyMembers.filter().idEqualTo(memberId).findFirst();
      if (member != null) {
        member.name = newName;
        await isar.familyMembers.put(member);
      }
    });
  }

  Future<void> deleteMember(String memberId) async {
    final isar = await DatabaseService.instance;
    await isar.writeTxn(() async {
      final member = await isar.familyMembers.filter().idEqualTo(memberId).findFirst();
      if (member != null) {
        await isar.familyMembers.delete(member.isarId);
      }
    });
  }

  Future<void> switchUser(String memberId) async {
    final isar = await DatabaseService.instance;
    await isar.writeTxn(() async {
      final all = await isar.familyMembers.where().findAll();
      for (final m in all) {
        m.isCurrentUser = (m.id == memberId);
        await isar.familyMembers.put(m);
      }
    });
  }
}
