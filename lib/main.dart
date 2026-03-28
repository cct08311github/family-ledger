import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'services/database_service.dart';
import 'services/local_notification_service.dart';
import 'services/firebase_sync_service.dart';
import 'services/auth_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化繁體中文日期格式
  await initializeDateFormatting('zh_TW', null);

  // 初始化 Isar 資料庫
  await DatabaseService.instance;

  // 初始化 Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 啟用 App Check 防止 API 濫用
  // Debug/本機 build 使用 debug provider，App Store release 才用 deviceCheck
  try {
    await FirebaseAppCheck.instance.activate(
      appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
      androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    );
  } catch (_) {
    // App Check 啟用失敗不阻擋 app 啟動
  }

  // 已登入 Google → 自動同步
  try {
    if (AuthService.isSignedIn) {
      await FirebaseSyncService.initialSync();
    }
  } catch (_) {
    // 同步失敗不阻擋 app 啟動
  }

  // 初始化本地推播通知
  await LocalNotificationService.init();

  runApp(
    const ProviderScope(
      child: FamilyLedgerApp(),
    ),
  );
}
