import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'services/database_service.dart';
import 'services/local_notification_service.dart';
import 'services/firebase_sync_service.dart';
import 'services/auth_service.dart';
import 'package:firebase_core/firebase_core.dart';
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

  // 啟用 App Check 防止 API 濫用（僅合法 app 可存取 Firebase）
  await FirebaseAppCheck.instance.activate(
    appleProvider: AppleProvider.deviceCheck,
    androidProvider: AndroidProvider.playIntegrity,
  );

  // 如果尚未登入，先匿名登入（使用者可稍後在設定升級為 Google Sign-In）
  if (!AuthService.hasAnyAuth) {
    await AuthService.signInAnonymously();
  }

  // 僅在已登入（非匿名）時才同步到 Firestore（#59 M2）
  if (AuthService.isSignedIn) {
    await FirebaseSyncService.initialSync();
  }

  // 初始化本地推播通知
  await LocalNotificationService.init();

  runApp(
    const ProviderScope(
      child: FamilyLedgerApp(),
    ),
  );
}
