// 由 GoogleService-Info.plist 手動產生
// 如需更新，重新執行 flutterfire configure 或手動修改

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        throw UnsupportedError('此平台尚未設定 Firebase：$defaultTargetPlatform');
    }
  }

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD9FyDSM4-acovBVfMvf_2kLW1IaJcVsMQ',
    appId: '1:137558877215:ios:7101807b49be145b96a12a',
    messagingSenderId: '137558877215',
    projectId: 'family-ledger-784ed',
    storageBucket: 'family-ledger-784ed.firebasestorage.app',
    iosBundleId: 'com.familyledger.familyLedger',
  );

  // macOS 共用 iOS 的配置（同一個 Apple app）
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyD9FyDSM4-acovBVfMvf_2kLW1IaJcVsMQ',
    appId: '1:137558877215:ios:7101807b49be145b96a12a',
    messagingSenderId: '137558877215',
    projectId: 'family-ledger-784ed',
    storageBucket: 'family-ledger-784ed.firebasestorage.app',
    iosBundleId: 'com.familyledger.familyLedger',
  );
}
