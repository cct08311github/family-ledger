# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Development Commands

```bash
flutter pub get                                              # Install dependencies
flutter run                                                  # Run app (macOS default, add -d <device> for others)
flutter run -d 00008140-00110D4C2082201C                     # Run on physical iPhone (Chunting iPhone 16)
flutter analyze                                              # Lint check
flutter test                                                 # Run all tests
flutter test test/local_parser_test.dart                     # Run single test file
firebase deploy --only firestore:rules                       # Deploy Firestore security rules
firebase deploy --only storage                               # Deploy Storage security rules
```

**Xcode install fallback**: `flutter run` to physical iPhone often times out. Use Xcode directly: `open ios/Runner.xcworkspace` → select device → Run (Cmd+R).

**macOS build**: Must use Xcode (`open macos/Runner.xcworkspace` → Run) for proper code signing. `flutter build macos` produces unsigned app that fails Keychain access.

## Architecture

### Stack
- **Flutter 3.41+** / Dart 3.11+ with Material 3
- **Riverpod** (flutter_riverpod) — state management
- **Cloud Firestore** — source of truth (with built-in offline persistence)
- **Firebase Auth** — Google Sign-In mandatory
- **Firebase Storage** — receipt photo uploads
- **speech_to_text** — on-device voice recognition (zh_TW)

### Data Flow (Firestore-first)
```
UI (ConsumerWidget) → ref.watch(provider) → StreamProvider → Firestore snapshots
UI mutation → AsyncNotifier → FirestoreService CRUD → ActivityLogger
Firestore offline persistence → automatic sync when back online
Receipt photos → ReceiptStorageService → Firebase Storage (URL replaces local path)
```

### Auth Flow
```
App launch → _AuthGate checks AuthService.isSignedIn
  ├── Not signed in → LoginPage (Google Sign-In required)
  └── Signed in → MainShell (all features accessible)
      → FirebaseSyncService.initialSync() → Firestore realtime listeners
```
- Google Sign-In is mandatory — no anonymous mode, no data visible before login
- Same Google account across devices = same Firebase UID = auto-sync
- Invite code feature hidden in UI (code preserved for future use)

### Provider Pattern
- **StreamProvider**: Real-time Firestore snapshot listeners — lists (members, expenses, categories, notifications)
- **FutureProvider**: One-shot computed data (simplifiedDebts, netBalances, recentDescriptions) — invalidated manually
- **AsyncNotifier**: CRUD operations via `FirestoreService`, log to ActivityLogger, then trigger recalculation
- **StateNotifier**: Theme settings with file-based persistence

**Important**: After expense or settlement mutations, `balanceNotifierProvider.recalculate()` must be called to refresh the debt cache.

### Firestore Collections
| Subcollection | Path | Purpose |
|---------------|------|---------|
| groups | `groups/{groupId}` | Household group (isPrimary flag) |
| members | `groups/{groupId}/members/{id}` | Members with isCurrentUser switching |
| expenses | `groups/{groupId}/expenses/{id}` | Core expense record with splits[], receiptPaths[] |
| settlements | `groups/{groupId}/settlements/{id}` | Payment records that reduce debt |
| categories | `groups/{groupId}/categories/{id}` | Expense categories with emoji icons, sortOrder |
| balances | `groups/{groupId}/balances/{id}` | Cached pairwise debt |
| activityLogs | `groups/{groupId}/activityLogs/{id}` | Operation audit trail |
| notifications | `groups/{groupId}/notifications/{id}` | In-app notifications |

### Firebase Architecture
```
Auth: Google Sign-In (mandatory) → Firebase UID shared across devices
Firestore: groups/{groupId}/[members|expenses|settlements|categories|balances|activityLogs|notifications]/{id}
Storage: receipts/{groupId}/{expenseId}/{uuid}.jpg
Security: memberUids[] on group doc — only listed UIDs can read/write
Offline: Firestore SDK built-in persistence — reads from cache, syncs when online
```
- `FirestoreService` — unified CRUD for all subcollections, replaces Isar + FirebaseSyncService
- `ReceiptStorageService` — uploads receipt photos to Firebase Storage, replaces local paths with URLs
- No manual sync logic — Firestore SDK handles offline/online transitions automatically

### Voice Input Pipeline
```
speech_to_text (on-device, zh_TW) → raw text
  ├── Gemini API (if API key set) → structured JSON (x-goog-api-key header)
  └── LocalExpenseParser (fallback) → regex + Chinese numeral conversion
      → {description, amount, category, date} → auto-fill form
```
LocalExpenseParser handles: Chinese numerals (三百五→350, 兩萬五→25000), relative dates (昨天/前天/上禮拜X), 200+ keyword category inference.

### Split Calculator (`lib/services/split_calculator.dart`)
Three split methods (equal/percentage/custom), net debt calculation with settlement deduction, and greedy debt simplification (minimum cash flow algorithm). Amounts are rounded to integers (NT$). Percentage split assigns remainder to last person.

### Navigation
`_AuthGate` in `app.dart` gates all access behind Google login. `MainShell` uses `IndexedStack` + `NavigationBar` (5 tabs: 首頁/拆帳/記錄/統計/設定). The FAB pushes `ExpenseFormPage` modally. `ExpenseFormPage` accepts optional `existingExpense` (edit) or `duplicateFrom` (copy).

## Conventions

- **Language**: All UI strings in Traditional Chinese (繁體中文)
- **Currency**: Always use `Formatters.currency()` / `Formatters.signedCurrency()` from `lib/utils/formatters.dart`
- **Deprecation**: Use `color.withValues(alpha: 0.5)` not `color.withOpacity(0.5)` (deprecated in Flutter 3.27+)
- **Widget types**: `ConsumerWidget` for stateless pages, `ConsumerStatefulWidget` for forms with controllers
- **Theme**: `CardThemeData` (not `CardTheme`) in Flutter 3.41+. Theme switching via `ThemeSettingsNotifier` with 6 color schemes.
- **DB writes**: All mutations go through `FirestoreService` methods
- **IDs**: UUID v4 for all entity IDs
- **Logging**: All CRUD operations must call `ActivityLogger.log()` (from
  `lib/providers/activity_log_provider.dart`) after Firestore write
- **Photos**: Up to 10 receipt photos per expense (`receiptPaths` list), backward compatible with old `receiptPath` field
- **API Key storage**: Sensitive keys (Gemini) stored via `flutter_secure_storage` (Keychain), never in plain JSON
- **API Key transmission**: Use HTTP headers (`x-goog-api-key`), never URL query parameters

## Security

- **Firebase App Check**: Enabled with `AppleProvider.debug` in kDebugMode, `deviceCheck` in release
- **Firestore Rules**: `firestore.rules` — member-only access, owner-only delete, field validation, default-deny
- **Storage Rules**: `storage.rules` — auth required, 10MB limit, image types only
- **Invite code**: 8-char cryptographic random (Random.secure()), 24h expiry, max 5 uses
- **`google-services.json`**: Firebase API key config — **never commit** (已從 Git history 移除，若重新取得需手動放置於 `android/app/` 並確認已 gitignore)
- **Deserialization**: Defensive null checks + try-catch on all Firestore document parsing
- **macOS sandbox**: Disabled (`com.apple.security.app-sandbox: false`) for Keychain access compatibility

## Known Constraints

- **Web builds**: A separate Next.js web app exists at `shared/projects/family-ledger-web/` sharing the same Firebase project.
- **Google Sign-In on macOS**: Requires `CFBundleURLSchemes` with REVERSED_CLIENT_ID in `macos/Runner/Info.plist`.
- **macOS code signing**: `flutter build macos` does not properly sign for Keychain. Use Xcode build instead.
- **Firestore rules**: Production rules in `firestore.rules`, deploy with `firebase deploy --only firestore:rules`.
- **Storage rules**: Production rules in `storage.rules`, deploy with `firebase deploy --only storage`.
- **share_plus v12**: Upgraded from v9 due to Firebase dependency conflict. Uses `SharePlus.instance.share(ShareParams(...))` API.
- **Apple Sign-In**: Code exists in `AuthService` but UI hidden (requires paid Apple Developer Program $99/yr).
