# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Development Commands

```bash
flutter pub get                                              # Install dependencies
dart run build_runner build --delete-conflicting-outputs     # Generate Isar .g.dart schemas (required after model changes)
flutter run                                                  # Run app (macOS default, add -d <device> for others)
flutter run -d 00008140-00110D4C2082201C                     # Run on physical iPhone (Chunting iPhone 16)
flutter analyze                                              # Lint check
flutter test                                                 # Run all tests
flutter test test/local_parser_test.dart                     # Run single test file
firebase deploy --only firestore:rules                       # Deploy Firestore security rules
```

**Critical**: After ANY change to `@collection` or `@embedded` model classes, re-run `build_runner` before building. The `.g.dart` files are gitignored.

**Xcode install fallback**: `flutter run` to physical iPhone often times out. Use Xcode directly: `open ios/Runner.xcworkspace` → select device → Run (Cmd+R).

## Architecture

### Stack
- **Flutter 3.41+** / Dart 3.11+ with Material 3
- **Riverpod** (flutter_riverpod) — state management
- **Isar 3.1** — local embedded NoSQL database (source of truth)
- **Firebase** — Firestore sync + Auth (Apple Sign-In + anonymous)
- **speech_to_text** — on-device voice recognition (zh_TW)

### Data Flow (local-first with cloud sync)
```
UI (ConsumerWidget) → ref.watch(provider) → StreamProvider → Isar .watch()
UI mutation → AsyncNotifier → Isar writeTxn() → ActivityLogger → FirebaseSyncService (fire-and-forget)
Firestore listener → mergeFromRemote() → Isar writeTxn() (newer timestamp wins)
```

### Provider Pattern
- **StreamProvider**: Real-time Isar queries with `.watch(fireImmediately: true)` — lists (members, expenses, categories, notifications)
- **FutureProvider**: One-shot computed data (simplifiedDebts, netBalances, recentDescriptions) — invalidated manually
- **AsyncNotifier**: CRUD operations that write to Isar, log to ActivityLogger, sync to Firebase, then trigger recalculation
- **StateNotifier**: Theme settings with file-based persistence

**Important**: After expense or settlement mutations, `balanceNotifierProvider.recalculate()` must be called to refresh the debt cache.

### Isar Collections (8 + 1 embedded)
| Collection | Purpose |
|------------|---------|
| FamilyGroup | Household group (isPrimary flag) |
| FamilyMember | Members with local user switching (isCurrentUser) |
| Expense | Core expense record with embedded SplitDetail[], receiptPaths[], paymentMethod |
| SplitDetail | @embedded — per-member share/paid amounts |
| Balance | Cached pairwise debt (cleared and rebuilt on recalc) |
| Category | Expense categories with emoji icons, sortOrder, isActive |
| Settlement | Payment records that reduce debt |
| ActivityLog | Operation audit trail (action, actor, timestamp) |
| AppNotification | In-app notifications for split expense participants |

### Firebase Sync Architecture
```
Firestore: groups/{groupId}/[members|expenses|settlements]/{id}
Security: memberUids[] array on group doc — only listed UIDs can read/write
Auth: Apple Sign-In (primary) → same Apple ID = same UID across devices
      Anonymous (fallback) → single device only
Conflict: updatedAt/createdAt timestamp comparison, newer wins
```
- `FirebaseSyncService.initialSync()` — uploads all local data on startup
- `startRealtimeSync()` — Firestore snapshot listeners for expenses + settlements
- Sync is fire-and-forget: local write always succeeds, remote sync fails silently

### Voice Input Pipeline
```
speech_to_text (on-device, zh_TW) → raw text
  ├── Gemini API (if API key set) → structured JSON
  └── LocalExpenseParser (fallback) → regex + Chinese numeral conversion
      → {description, amount, category, date} → auto-fill form
```
LocalExpenseParser handles: Chinese numerals (三百五→350, 兩萬五→25000), relative dates (昨天/前天/上禮拜X), 200+ keyword category inference.

### Split Calculator (`lib/services/split_calculator.dart`)
Three split methods (equal/percentage/custom), net debt calculation with settlement deduction, and greedy debt simplification (minimum cash flow algorithm). Amounts are rounded to integers (NT$). Percentage split assigns remainder to last person.

### Navigation
`MainShell` in `app.dart` uses `IndexedStack` + `NavigationBar` (5 tabs: 首頁/拆帳/記錄/統計/設定). The FAB pushes `ExpenseFormPage` modally. `ExpenseFormPage` accepts optional `existingExpense` (edit) or `duplicateFrom` (copy).

## Conventions

- **Language**: All UI strings in Traditional Chinese (繁體中文)
- **Currency**: Always use `Formatters.currency()` / `Formatters.signedCurrency()` from `lib/utils/formatters.dart`
- **Deprecation**: Use `color.withValues(alpha: 0.5)` not `color.withOpacity(0.5)` (deprecated in Flutter 3.27+)
- **Widget types**: `ConsumerWidget` for stateless pages, `ConsumerStatefulWidget` for forms with controllers
- **Theme**: `CardThemeData` (not `CardTheme`) in Flutter 3.41+. Theme switching via `ThemeSettingsNotifier` with 6 color schemes.
- **DB writes**: Always wrap in `isar.writeTxn(() async { ... })`
- **IDs**: UUID v4 for all entity IDs, `Isar.autoIncrement` for isarId
- **Logging**: All CRUD operations must call `ActivityLogger.log()` after Isar write
- **Firebase sync**: All CRUD providers call `FirebaseSyncService.sync*Up()` after Isar write, wrapped in `.catchError((_) {})`
- **Photos**: Up to 10 receipt photos per expense (`receiptPaths` list), backward compatible with old `receiptPath` field

## Known Constraints

- **Isar + Web**: Isar's generated code uses large integer literals that exceed JS precision — web builds fail. Target mobile/desktop only.
- **Isar experimental warnings**: `.g.dart` files produce ~48 `experimental_member_use` warnings — expected, cannot be suppressed.
- **`.g.dart` in gitignore**: Generated files are not committed. Always run `build_runner` after cloning.
- **Apple Sign-In setup**: Requires Xcode capability "Sign In with Apple" on both iOS and macOS targets, plus Firebase Console Authentication → Apple enabled.
- **Firestore rules**: Production rules in `firestore.rules`, deploy with `firebase deploy --only firestore:rules`.
- **share_plus v12**: Upgraded from v9 due to Firebase dependency conflict. Uses `SharePlus.instance.share(ShareParams(...))` API.
