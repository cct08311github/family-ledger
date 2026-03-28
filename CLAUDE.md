# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Development Commands

```bash
flutter pub get                                              # Install dependencies
dart run build_runner build --delete-conflicting-outputs     # Generate Isar .g.dart schemas (required after model changes)
flutter run                                                  # Run app (macOS default, add -d <device> for others)
flutter analyze                                              # Lint check
flutter test                                                 # Run tests
flutter test test/widget_test.dart                           # Run single test
```

**Important**: After ANY change to `@collection` or `@embedded` model classes, re-run `build_runner` before building. The `.g.dart` files are gitignored.

## Architecture

### Stack
- **Flutter 3.41+** / Dart 3.11+ with Material 3
- **Riverpod** (flutter_riverpod) — state management
- **Isar 3.1** — local embedded NoSQL database
- **image_picker** — receipt photo capture
- **fl_chart** — statistics charts
- **intl** — zh_TW locale formatting

### Data Flow
```
UI (ConsumerWidget) → ref.watch(provider) → StreamProvider/FutureProvider → Isar .watch()
UI mutation → ref.read(notifier) → AsyncNotifier → Isar writeTxn() → invalidate dependent providers
```

### Provider Pattern
- **StreamProvider**: Real-time Isar queries with `.watch(fireImmediately: true)` — used for lists (members, expenses, categories)
- **FutureProvider**: One-shot computed data (simplifiedDebts, netBalances) — invalidated manually after mutations
- **AsyncNotifier**: CRUD operations that write to Isar then trigger recalculation

After expense or settlement mutations, `balanceNotifierProvider.recalculate()` must be called to refresh the debt cache.

### Isar Collections (6 + 1 embedded)
| Collection | Purpose |
|------------|---------|
| FamilyGroup | Household group (isPrimary flag) |
| FamilyMember | Members with local user switching (isCurrentUser) |
| Expense | Core expense record with embedded SplitDetail[] |
| SplitDetail | @embedded — per-member share/paid amounts |
| Balance | Cached pairwise debt (cleared and rebuilt on recalc) |
| Category | Expense categories with emoji icons |
| Settlement | Payment records that reduce debt |

### Split Calculator (`lib/services/split_calculator.dart`)
Core business logic — three split methods (equal/percentage/custom), net debt calculation with settlement deduction, and greedy debt simplification (minimum cash flow algorithm). Amounts are rounded to integers (NT$).

### Navigation
`MainShell` in `app.dart` uses `IndexedStack` + `NavigationBar` (5 tabs). The FAB pushes `ExpenseFormPage` modally. `ExpenseFormPage` accepts optional `existingExpense` for edit mode.

## Conventions

- **Language**: All UI strings in Traditional Chinese (繁體中文)
- **Currency**: Always use `Formatters.currency()` / `Formatters.signedCurrency()` from `lib/utils/formatters.dart` — never inline `NumberFormat`
- **Deprecation**: Use `color.withValues(alpha: 0.5)` not `color.withOpacity(0.5)` (deprecated in Flutter 3.27+)
- **Widget types**: `ConsumerWidget` for stateless pages, `ConsumerStatefulWidget` for forms with controllers
- **Theme**: `CardThemeData` (not `CardTheme`) in Flutter 3.41+
- **DB writes**: Always wrap in `isar.writeTxn(() async { ... })`
- **IDs**: UUID v4 for all entity IDs, `Isar.autoIncrement` for isarId

## Known Constraints

- **Isar + Web**: Isar's generated code uses large integer literals that exceed JS precision — web builds fail. Target mobile/desktop only.
- **Isar experimental warnings**: `.g.dart` files produce ~48 `experimental_member_use` warnings — these are expected and cannot be suppressed.
- **`.g.dart` in gitignore**: Generated files are not committed. Always run `build_runner` after cloning.
