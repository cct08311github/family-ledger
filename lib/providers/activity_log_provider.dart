import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../models/activity_log.dart';
import '../services/database_service.dart';

/// 最近 100 筆操作日誌
final activityLogsProvider = StreamProvider<List<ActivityLog>>((ref) async* {
  final isar = await DatabaseService.instance;
  yield* isar.activityLogs
      .where()
      .sortByCreatedAtDesc()
      .limit(100)
      .watch(fireImmediately: true);
});

/// 記錄操作日誌
class ActivityLogger {
  static Future<void> log({
    required String action,
    required String actorName,
    required String actorId,
    required String description,
    String? entityId,
  }) async {
    final isar = await DatabaseService.instance;
    final entry = ActivityLog()
      ..action = action
      ..actorName = actorName
      ..actorId = actorId
      ..description = description
      ..entityId = entityId
      ..createdAt = DateTime.now();
    await isar.writeTxn(() async {
      await isar.activityLogs.put(entry);
    });
  }
}
