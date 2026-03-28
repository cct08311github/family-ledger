# 家計本 App — Cowork 接續開發指引

## ✅ 已完成

### 第一步：基礎架構
- `pubspec.yaml` — 所有套件依賴
- 7 個 Isar 資料模型（FamilyGroup, FamilyMember, Expense, SplitDetail, Balance, Category, Settlement）
- 拆帳核心演算法 `split_calculator.dart`（均分/比例分/自訂 + 最小現金流簡化債務）
- 資料庫初始化服務 `database_service.dart`
- App 殼（Material 3 主題 + 底部導覽列）

### 第二步：Providers + 全部 6 個頁面
- `member_provider.dart` — 成員管理 + 群組 + 使用者切換
- `expense_provider.dart` — 支出 CRUD + 本月統計
- `balance_provider.dart` — 債務餘額 + 簡化債務
- `category_provider.dart` — 類別管理
- `home_page.dart` — 首頁儀表板（總覽卡、類別花費、最近記錄、使用者切換）
- `expense_form_page.dart` — 記帳表單（含動態拆帳 UI：均分/比例/自訂 + 即時預覽）
- `split_overview_page.dart` — 拆帳總覽（每人淨餘額 + 詳細債務 + 一鍵簡化）
- `records_page.dart` — 所有記錄（含篩選）
- `statistics_page.dart` — 統計報表（類別排行 + 百分比長條）
- `settings_page.dart` — 設定（成員增刪改 + 群組名稱 + 匯出預留）

## 🔲 待完成（第三步以後）

### 優先
- [ ] 執行 `flutter pub get` + `build_runner` 確認編譯
- [ ] 修復任何編譯錯誤（import 路徑、缺少的 .g.dart）
- [ ] 加入 fl_chart 圓餅圖/柱狀圖到統計頁
- [ ] 結算功能（Settlement CRUD + 債務扣抵）
- [ ] CSV / PDF 匯出功能
- [ ] 發票照片拍照上傳

### 進階
- [ ] 多群組切換
- [ ] 每月 1 號通知提醒結算
- [ ] Firebase Auth（Email / Google / Apple 登入）
- [ ] Firestore 雲端同步
- [ ] 邀請連結加入家庭群

## 🔧 建置步驟
```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

## 📂 專案結構
```
lib/
├── main.dart
├── app.dart
├── models/          ← 7 個 Isar 資料模型
├── providers/       ← 4 個 Riverpod Providers
├── services/        ← 資料庫 + 拆帳演算法
├── screens/         ← 6 個完整頁面
├── utils/           ← 格式化工具
└── widgets/         ← 共用元件
```
