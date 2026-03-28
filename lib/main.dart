import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'services/database_service.dart';
import 'services/local_notification_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化繁體中文日期格式
  await initializeDateFormatting('zh_TW', null);

  // 初始化 Isar 資料庫
  await DatabaseService.instance;

  // 初始化本地推播通知
  await LocalNotificationService.init();

  runApp(
    const ProviderScope(
      child: FamilyLedgerApp(),
    ),
  );
}
