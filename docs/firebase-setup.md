# Firebase 設定指南

## 前置條件
- 安裝 Firebase CLI：`npm install -g firebase-tools`
- 安裝 FlutterFire CLI：`dart pub global activate flutterfire_cli`
- 有 Google 帳號

## 步驟

### 1. 建立 Firebase 專案

1. 前往 [Firebase Console](https://console.firebase.google.com/)
2. 點「新增專案」→ 輸入名稱（如 `family-ledger`）
3. 選擇是否啟用 Google Analytics（可跳過）
4. 等待專案建立完成

### 2. 啟用 Firestore

1. 在 Firebase Console 左側選單 → **Firestore Database**
2. 點「建立資料庫」
3. 選擇地區：`asia-east1`（台灣）或 `asia-northeast1`（東京）
4. 選「正式模式」（之後設定 Security Rules）

### 3. 啟用 Authentication

1. 左側選單 → **Authentication** → **開始使用**
2. 在「登入方式」分頁 → 啟用「匿名」登入
3. （未來可加入 Google Sign-In、Apple Sign-In）

### 4. 設定 FlutterFire

在專案根目錄執行：

```bash
# 登入 Firebase
firebase login

# 自動設定 Flutter 專案（會產生 firebase_options.dart）
flutterfire configure --project=你的專案ID
```

選擇平台時勾選：
- ✅ iOS
- ✅ macOS
- ✅ Android（如果需要）

### 5. iOS 額外設定

`flutterfire configure` 會自動處理大部分設定。確認：

- `ios/Runner/GoogleService-Info.plist` 已產生
- `macos/Runner/GoogleService-Info.plist` 已產生

### 6. 設定 Firestore Security Rules

在 Firebase Console → Firestore → 規則，貼上：

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // 群組：只有擁有者和成員可讀寫
    match /groups/{groupId} {
      allow read, write: if request.auth != null;

      match /members/{memberId} {
        allow read, write: if request.auth != null;
      }
      match /expenses/{expenseId} {
        allow read, write: if request.auth != null;
      }
      match /settlements/{settlementId} {
        allow read, write: if request.auth != null;
      }
    }
  }
}
```

> 注意：以上是基本規則。正式上線前應改為更嚴格的規則（按 groupId 成員驗證）。

### 7. 啟用同步

`flutterfire configure` 完成後，在 `lib/main.dart` 取消以下註解：

```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// 在 main() 中：
await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
```

### 驗證

執行 `flutter run`，如果沒有錯誤，Firebase 已成功連接。
