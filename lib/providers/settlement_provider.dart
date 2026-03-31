import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/settlement.dart';
import '../services/firestore_service.dart';
import 'balance_provider.dart';
import 'activity_log_provider.dart';
import 'member_provider.dart';

final allSettlementsProvider = StreamProvider<List<Settlement>>((ref) async* {
  final group = await ref.watch(currentGroupProvider.future);
  if (group == null) {
    yield [];
    return;
  }
  yield* FirestoreService.watchSettlements(group.id);
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
    final group = await ref.read(currentGroupProvider.future);
    if (group == null) return;
    final now = DateTime.now();
    final settlement = Settlement()
      ..groupId = group.id
      ..fromMemberId = fromMemberId
      ..fromMemberName = fromMemberName
      ..toMemberId = toMemberId
      ..toMemberName = toMemberName
      ..amount = amount
      ..note = note
      ..date = now
      ..createdAt = now;
    final id = await FirestoreService.addSettlement(settlement);
    await ActivityLogger.log(
      action: 'settlement_add',
      actorName: fromMemberName, actorId: fromMemberId,
      description: '$fromMemberName 付款給 $toMemberName NT\$ ${amount.toStringAsFixed(0)}',
      entityId: id,
      groupId: group.id,
    );
    await ref.read(balanceNotifierProvider.notifier).recalculate();
  }

  Future<void> deleteSettlement(Settlement settlement) async {
    await FirestoreService.deleteSettlement(settlement.groupId, settlement.id);
    await ActivityLogger.log(
      action: 'settlement_delete',
      actorName: settlement.fromMemberName, actorId: settlement.fromMemberId,
      description: '刪除付款記錄：${settlement.fromMemberName} → ${settlement.toMemberName} NT\$ ${settlement.amount.toStringAsFixed(0)}',
      entityId: settlement.id,
      groupId: settlement.groupId,
    );
    await ref.read(balanceNotifierProvider.notifier).recalculate();
  }
}
