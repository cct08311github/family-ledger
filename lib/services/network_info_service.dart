// Network Info Service - 家庭記帳 App
//
// 網路連線檢測，支援 Firebase Sync 前先確認網路可用

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 網路連線狀態
enum NetworkStatus {
  online,    // 已連線
  offline,   // 離線
  unknown,   // 未知（檢測中）
}

/// Network Info Service
class NetworkInfoService {
  static final _connectivity = Connectivity();
  static StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// 當前網路狀態
  static NetworkStatus _status = NetworkStatus.unknown;
  static NetworkStatus get status => _status;

  /// 網路狀態變化串流
  static final _controller = StreamController<NetworkStatus>.broadcast();
  static Stream<NetworkStatus> get statusStream => _controller.stream;

  /// 初始化並開始監聽
  static Future<void> initialize() async {
    // 檢查當前狀態
    final results = await _connectivity.checkConnectivity();
    _updateStatus(results);

    // 監聽未來變化
    _subscription = _connectivity.onConnectivityChanged.listen(_updateStatus);
  }

  static void _updateStatus(List<ConnectivityResult> results) {
    final hasConnection = results.isNotEmpty &&
        !results.contains(ConnectivityResult.none);

    final newStatus = hasConnection ? NetworkStatus.online : NetworkStatus.offline;
    if (newStatus != _status) {
      _status = newStatus;
      _controller.add(_status);
    }
  }

  /// 停止監聽（dispose 時呼叫）
  static void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// 同步前檢查網路是否可用
  static Future<bool> isNetworkAvailable() async {
    if (_status == NetworkStatus.offline) return false;
    // 再次確認（避免狀態滯後）
    final results = await _connectivity.checkConnectivity();
    _updateStatus(results);
    return _status == NetworkStatus.online;
  }
}

/// Riverpod Provider for Network Status
final networkStatusProvider = StreamProvider<NetworkStatus>((ref) async* {
  // 先發射當前狀態
  yield NetworkInfoService.status;

  // 再監聽未來變化
  await for (final status in NetworkInfoService.statusStream) {
    yield status;
  }
});

/// 同步前網路檢查 Provider
final networkAvailableProvider = FutureProvider<bool>((ref) async {
  return await NetworkInfoService.isNetworkAvailable();
});
