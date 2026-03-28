import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firebase_sync_service.dart';

/// 同步狀態
enum SyncStatus { idle, syncing, error, disabled }

/// 同步狀態 provider
final syncStatusProvider = StateProvider<SyncStatus>((ref) => SyncStatus.disabled);

/// 同步錯誤訊息
final syncErrorProvider = StateProvider<String?>((ref) => null);

/// 是否已啟用 Firebase
final firebaseEnabledProvider = StateProvider<bool>((ref) => false);

/// Firebase 登入狀態
final firebaseUserProvider = Provider<bool>((ref) {
  return FirebaseSyncService.isSignedIn;
});
