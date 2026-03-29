import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'services/database_service.dart';
import 'services/local_notification_service.dart';
import 'services/firebase_sync_service.dart';
import 'services/auth_service.dart';
import 'services/log_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LogService.info(LogTag.APP, 'App starting...');

  // 初始化繁體中文日期格式
  await initializeDateFormatting('zh_TW', null);

  // 初始化 Isar 資料庫
  LogService.info(LogTag.DB, 'Initializing Isar database');
  await DatabaseService.instance;

  // 初始化 Firebase
  LogService.info(LogTag.APP, 'Initializing Firebase');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  LogService.info(LogTag.APP, 'Firebase initialized');

  // 啟用 App Check 防止 API 濫用
  // Debug/本機 build 使用 debug provider，App Store release 才用 deviceCheck
  try {
    await FirebaseAppCheck.instance.activate(
      appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
      androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    );
    LogService.info(LogTag.APP, 'App Check activated (${kDebugMode ? "debug" : "release"} mode)');
  } catch (e, st) {
    LogService.error(LogTag.APP, 'App Check activation failed', e, st);
  }

  // 等待 Firebase Auth 恢復 session，然後同步
  try {
    LogService.info(LogTag.AUTH, 'Waiting for auth session restore');
    final user = await AuthService.authStateChanges.first;
    if (user != null && !user.isAnonymous) {
      LogService.info(LogTag.AUTH, 'Session restored: ${user.email ?? user.uid}');
      await FirebaseSyncService.initialSync();
    } else {
      LogService.info(LogTag.AUTH, 'No active session');
    }
  } catch (e, st) {
    LogService.error(LogTag.SYNC, 'Initial sync failed', e, st);
  }

  // 初始化本地推播通知
  await LocalNotificationService.init();
  LogService.info(LogTag.APP, 'App startup complete');

  runApp(
    const ProviderScope(
      child: FamilyLedgerApp(),
    ),
  );
}
