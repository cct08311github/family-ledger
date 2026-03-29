import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    LogService.info(LogTag.APP, 'App starting...');
    FlutterError.onError = (details) {
      LogService.error(LogTag.APP, 'Flutter error', details.exception, details.stack);
      FlutterError.presentError(details);
    };
    await initializeDateFormatting('zh_TW', null);
    LogService.info(LogTag.DB, 'Initializing Isar database');
    await DatabaseService.instance;
    LogService.info(LogTag.APP, 'Initializing Firebase');
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    LogService.info(LogTag.APP, 'Firebase initialized');
    if (Platform.isMacOS) {
      try {
        const channel = MethodChannel('com.familyledger/auth_config');
        await channel.invokeMethod('configureKeychainAccess');
        LogService.info(LogTag.AUTH, 'macOS keychain configured');
      } catch (e) {
        LogService.warning(LogTag.AUTH, 'macOS keychain config failed (non-fatal)', e);
      }
    }
    try {
      await FirebaseAppCheck.instance.activate(
        appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
        androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      );
      LogService.info(LogTag.APP, 'App Check activated (${kDebugMode ? "debug" : "release"} mode)');
    } catch (e, st) {
      LogService.error(LogTag.APP, 'App Check activation failed', e, st);
    }
    try {
      LogService.info(LogTag.AUTH, 'Waiting for auth session restore');
      final user = await AuthService.authStateChanges.first;
      if (user != null && !user.isAnonymous) {
        LogService.info(LogTag.AUTH, 'Session restored: \${user.email ?? user.uid}');
        await FirebaseSyncService.initialSync();
      } else {
        LogService.info(LogTag.AUTH, 'No active session');
      }
    } catch (e, st) {
      LogService.error(LogTag.SYNC, 'Initial sync failed', e, st);
    }
    await LocalNotificationService.init();
    LogService.info(LogTag.APP, 'App startup complete');
    runApp(const ProviderScope(child: FamilyLedgerApp()));
  }, (error, stack) {
    LogService.error(LogTag.APP, 'Uncaught async error', error, stack);
    if (kDebugMode) debugPrint('Uncaught async error: \$error\n\$stack');
  });
}
