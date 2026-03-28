# Firebase 設定指南

## 前置條件
- 安裝 Firebase CLI：`npm install -g firebase-tools`
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
4. 選「正式模式」

### 3. 啟用 Authentication

1. 左側選單 → **Authentication** → **開始使用**
2. 在「登入方式」分頁 → 啟用 **Google**（必要）
3. 填入支援電子郵件 → 儲存

### 4. 啟用 Storage

1. 左側選單 → **Storage** → **Get Started**
2. 選擇地區：`asia-east1`

### 5. 下載 GoogleService-Info.plist

1. Firebase Console → ⚙️ **專案設定** → 你的 iOS app
2. 下載 `GoogleService-Info.plist`
3. 複製到 `ios/Runner/GoogleService-Info.plist` 和 `macos/Runner/GoogleService-Info.plist`
4. 確認 plist 內有 `CLIENT_ID` 和 `REVERSED_CLIENT_ID`（啟用 Google 登入後才會有）

### 6. 更新 firebase_options.dart

從 plist 取出以下值更新 `lib/firebase_options.dart`：
- `apiKey` (API_KEY)
- `appId` (GOOGLE_APP_ID)
- `messagingSenderId` (GCM_SENDER_ID)
- `projectId` (PROJECT_ID)
- `storageBucket` (STORAGE_BUCKET)
- `iosClientId` (CLIENT_ID)

### 7. 更新 Info.plist URL Scheme

在 `ios/Runner/Info.plist` 和 `macos/Runner/Info.plist` 的 `CFBundleURLSchemes` 中填入 plist 的 `REVERSED_CLIENT_ID` 值。

### 8. 部署 Security Rules

```bash
firebase deploy --only firestore:rules
firebase deploy --only storage
```

正式環境規則包含：
- **群組成員驗證**：只有 `memberUids[]` 內的 UID 可讀寫
- **擁有者特權**：僅 `ownerUid` 可刪除群組或轉移擁有權
- **欄位型別驗證**：金額必須為正數且 < 1 億，描述 ≤ 200 字
- **預設拒絕**：未定義的路徑全部拒絕存取
- **Storage**：需登入、檔案 < 10MB、僅圖片類型

### 驗證

1. 用 Xcode 開啟 `ios/Runner.xcworkspace` 或 `macos/Runner.xcworkspace`
2. 按 ▶ Run
3. 應顯示 Google 登入頁面
4. 登入後資料自動同步到 Firestore
