# 家計本 App - Flutter 專案結構說明

## 📁 專案目錄結構

```
family_ledger/
├── pubspec.yaml                          # 套件依賴定義
├── lib/
│   ├── main.dart                         # 程式進入點
│   ├── app.dart                          # App 主體 + Material 3 主題 + 底部導覽列
│   ├── models/                           # 資料模型（Isar）
│   │   ├── models.dart                   # Barrel export
│   │   ├── enums.dart                    # 列舉 & 常數（支出類型、分帳方式、預設類別）
│   │   ├── family_group.dart             # 家庭群組
│   │   ├── family_member.dart            # 家庭成員
│   │   ├── expense.dart                  # 支出記錄（核心）
│   │   ├── split_detail.dart             # 拆帳明細（嵌入 Expense）
│   │   ├── balance.dart                  # 兩人債務餘額（快取）
│   │   ├── category.dart                 # 自訂類別
│   │   └── settlement.dart               # 結算記錄（還錢）
│   ├── services/                         # 核心服務
│   │   ├── database_service.dart         # Isar 初始化 & 預設資料
│   │   └── split_calculator.dart         # ⭐ 拆帳核心演算法 & 簡化債務
│   ├── providers/                        # Riverpod 狀態管理（待建）
│   ├── screens/                          # 各頁面（待建）
│   │   ├── home/                         # 首頁儀表板
│   │   ├── expense/                      # 新增/編輯支出
│   │   ├── split/                        # 拆帳總覽
│   │   ├── records/                      # 歷史記錄
│   │   ├── statistics/                   # 統計報表
│   │   └── settings/                     # 設定
│   ├── widgets/                          # 共用元件（待建）
│   └── utils/                            # 工具函式（待建）
├── assets/                               # 靜態資源
└── test/                                 # 測試
```

## 🗃️ 資料模型總覽

| 模型           | 說明                         | 類型           |
|----------------|------------------------------|----------------|
| FamilyGroup    | 家庭群組                     | @collection    |
| FamilyMember   | 家庭成員                     | @collection    |
| Expense        | 支出記錄                     | @collection    |
| SplitDetail    | 拆帳明細                     | @embedded      |
| Balance        | 兩人債務餘額                 | @collection    |
| Category       | 自訂類別                     | @collection    |
| Settlement     | 結算記錄                     | @collection    |

## ⭐ 核心演算法（split_calculator.dart）

### 1. 拆帳計算
- `calculateEqual()` — 均分（自動處理除不盡尾數）
- `calculatePercentage()` — 比例分
- `calculateCustom()` — 自訂金額

### 2. 債務計算
- `calculateNetDebts()` — 從所有支出計算兩兩淨債務

### 3. 簡化債務（最小現金流）
- `simplifyDebts()` — 貪心演算法，最小化轉帳次數

## 🚀 下一步

第一步（✅ 已完成）：
- [x] pubspec.yaml 及套件定義
- [x] 所有 Isar 資料模型
- [x] 拆帳核心演算法
- [x] 資料庫初始化服務
- [x] App 殼（主題 + 導覽列）

第二步（即將開始）：
- [ ] 執行 `flutter pub get` 及 `build_runner` 產生 Isar schema
- [ ] 實作 Riverpod Providers（成員管理、支出 CRUD、餘額計算）
- [ ] 實作記帳表單頁（含動態拆帳 UI）
- [ ] 實作首頁儀表板
- [ ] 實作拆帳總覽頁

## 🔧 建置指令

```bash
# 1. 取得套件
flutter pub get

# 2. 產生 Isar schema（每次修改 model 後都要跑）
dart run build_runner build --delete-conflicting-outputs

# 3. 執行 App
flutter run
```
