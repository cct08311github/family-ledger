import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';
import '../models/settlement.dart';
import '../services/database_service.dart';
import 'balance_provider.dart';
import 'activity_log_provider.dart';

const _uuid = Uuid();

final allSettlementsProvider = StreamProvider<List<Settlement>>((ref) async* {
  final isar = await DatabaseService.instance;
  yield* isar.settlements.where().sortByDateDesc().watch(fireImmediately: true);
});

final settlementNotifierProvider =
    AsyncNotifierProvider<SettlementNotifier, void>(SettlementNotifier.new);

class SettlementNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> addSettlement({
    required String fromMemberId,
    required String fromMemberName,
    required String toMemberId,
    required String toMemberName,
    required double amount,
    String? note,
  }) async {
    final isar = await DatabaseService.instance;
    final groupId = await DatabaseService.getPrimaryGroupId();
    if (groupId == null) return;
    final now = DateTime.now();
    final settlement = Settlement()
      ..id = _uuid.v4()
      ..groupId = groupId
      ..fromMemberId = fromMemberId
      ..fromMemberName = fromMemberName
      ..toMemberId = toMemberId
      ..toMemberName = toMemberName
      ..amount = amount
      ..note = note
      ..date = now
      ..createdAt = now;
    await isar.writeTxn(() async {
      await isar.settlements.put(settlement);
    });
    await ActivityLogger.log(
      action: 'settlement_add',
      actorName: fromMemberName, actorId: fromMemberId,
      description: '$fromMemberName 付款給 $toMemberName NT\$ ${amount.toStringAsFixed(0)}',
      entityId: settlement.id,
    );
    await ref.read(balanceNotifierProvider.notifier).recalculate();
  }

  Future<void> deleteSettlement(Settlement settlement) async {
    final isar = await DatabaseService.instance;
    await isar.writeTxn(() async {
      await isar.settlements.delete(settlement.isarId);
    });
    await ActivityLogger.log(
      action: 'settlement_delete',
      actorName: settlement.fromMemberName, actorId: settlement.fromMemberId,
      description: '刪除付款記錄：${settlement.fromMemberName} → ${settlement.toMemberName} NT\$ ${settlement.amount.toStringAsFixed(0)}',
      entityId: settlement.id,
    );
    await ref.read(balanceNotifierProvider.notifier).recalculate();
  }
}
