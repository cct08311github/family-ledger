import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'services/database_service.dart';
import 'services/local_notification_service.dart';
import 'services/firebase_sync_service.dart';
import 'services/auth_service.dart';
import 'package:firebase_core/firebase_core.dart';
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

  // 如果尚未登入，先匿名登入（使用者可稍後在設定升級為 Apple Sign-In）
  if (!AuthService.hasAnyAuth) {
    await AuthService.signInAnonymously();
  }

  // 將本地群組上傳到 Firestore（首次同步）
  await FirebaseSyncService.initialSync();

  // 初始化本地推播通知
  await LocalNotificationService.init();

  runApp(
    const ProviderScope(
      child: FamilyLedgerApp(),
    ),
  );
}
