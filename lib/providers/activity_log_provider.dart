import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/activity_log.dart';
import '../services/firestore_service.dart';
import 'member_provider.dart';

/// 最近 100 筆操作日誌
final activityLogsProvider = StreamProvider<List<ActivityLog>>((ref) async* {
  final group = await ref.watch(currentGroupProvider.future);
  if (group == null) {
    yield [];
    return;
  }
  yield* FirestoreService.watchActivityLogs(group.id, limit: 100);
});

/// 記錄操作日誌
class ActivityLogger {
  static Future<void> log({
    required String action,
    required String actorName,
    required String actorId,
    required String description,
    String? entityId,
    String? groupId,
  }) async {
    if (groupId == null) return;
    final entry = ActivityLog()
      ..action = action
      ..actorName = actorName
      ..actorId = actorId
      ..description = description
      ..entityId = entityId
      ..groupId = groupId
      ..createdAt = DateTime.now();
    await FirestoreService.addActivityLog(groupId, entry);
  }
}
