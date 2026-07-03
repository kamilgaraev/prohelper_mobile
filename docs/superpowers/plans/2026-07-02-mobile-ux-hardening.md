# МОСТ Mobile UI/UX Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the МОСТ Flutter mobile app closer to a 10/10 operational B2B field-work experience by fixing visible light-theme hierarchy, navigation density, action clarity, and reliability issues found on the Android emulator.

**Architecture:** Keep the current feature-first Flutter structure. Shared visual behavior belongs in `lib/core/widgets` or `lib/core/design`; screen-specific hierarchy and copy stay inside the relevant `lib/features/*/presentation` widgets. Every change must preserve Riverpod providers, selected-project behavior, module gating, and accessibility semantics.

**Tech Stack:** Flutter, Dart, Material 3, hooks_riverpod, widget tests with `flutter_test`, Android emulator smoke checks, Context7 Flutter docs for current accessibility/testing guidance.

---

## Current Evidence

- Emulator account and selected project are working against the production mobile API.
- Current UI direction from `ui-ux-pro-max`: data-dense operations dashboard, professional light theme, clear surface hierarchy, no decorative UI, touch-safe controls.
- Context7 Flutter docs confirm using `androidTapTargetGuideline`, `iOSTapTargetGuideline`, `labeledTapTargetGuideline`, and `textContrastGuideline` in widget tests for accessibility checks.
- Existing code already has shared UI primitives: `ProPageScaffold`, `ProSurface`, `ProStatusBanner`, `ProSearchFilterBar`, `ProSectionHeader`, app empty/loading/error states.
- Runtime attendance walkthrough found a system localization defect: `showDatePicker` opened with English labels in an otherwise Russian app.
- After localization hardening, the Android emulator date picker shows `Выберите дату`, `июль 2026 г.`, `Отмена`, and `ОК`; the UI tree no longer contains `Select date` or `Cancel`.
- Runtime `Ещё -> Договоры` walkthrough found amount metrics rendered with English decimal separators, for example `33 500.00` and `123 123 123.00`.
- After amount-format hardening, the Android emulator and UI tree show `33 500,00`, `123 123 123,00`, and `10 500 000,00`; old plain literals with `.00` are absent.
- Runtime/device smoke is currently unstable after repeated Android ANR dialogs during login (`Process system isn't responding`, then `МОСТ isn't responding`). Code-level checks continue while emulator smoke remains pending.

## File Map

- `lib/core/widgets/pro_surface.dart`: shared card/surface visual model.
- `lib/core/widgets/pro_search_filter_bar.dart`: shared search/filter component used by work/actions/catalog screens.
- `lib/core/widgets/pro_status_banner.dart`: shared status banner for operational signals.
- `lib/core/localization/most_localizations.dart`: shared Material/Cupertino localization configuration.
- `lib/features/home/presentation/*`: Overview command-center UI.
- `lib/features/navigation/presentation/mobile_work_hub_screen.dart`: Work tab catalog.
- `lib/features/actions/presentation/mobile_action_center_screen.dart`: Action center catalog.
- `lib/features/module_companions/presentation/companion_module_screen.dart`: shared companion-module list and metric cards.
- `lib/features/notifications/presentation/*`: Notification list and cards.
- `lib/features/warehouse/presentation/warehouse_tasks_screen.dart`: warehouse task queue and execution entry point.
- `pubspec.yaml` / `pubspec.lock`: Flutter SDK localization dependency and compatible `intl` constraint.
- `test/core/widgets/pro_components_test.dart`: shared component regression coverage.
- `test/features/home/mobile_overview_screen_test.dart`: Overview UI/semantics coverage.
- `test/features/navigation/mobile_work_hub_screen_test.dart`: Work tab UI/accessibility coverage.
- `test/features/actions/mobile_action_center_screen_test.dart`: Action center UI coverage.
- `test/features/module_companions/presentation/companion_module_screen_test.dart`: companion-module metric formatting coverage.
- `test/features/notifications/notifications_screen_test.dart`: Notification action-copy coverage.
- `test/features/warehouse/presentation/warehouse_tasks_screen_test.dart`: warehouse task queue accessibility coverage.
- `test/features/workforce/self_attendance_screen_test.dart`: attendance date-picker localization coverage.
- `test/widget_test.dart`: app-level Material localization coverage.

---

### Task 1: Runtime UI Audit Baseline

**Files:**
- Read: `lib/main.dart`
- Read: `lib/core/widgets/mobile_app_shell.dart`
- Read: `lib/features/home/presentation/mobile_overview_screen.dart`
- Read: `lib/features/navigation/presentation/mobile_work_hub_screen.dart`
- Read: `lib/features/actions/presentation/mobile_action_center_screen.dart`
- Artifact: `build/prohelper_*_current.png`

- [ ] **Step 1: Install and launch the current app on the Android emulator**

Run:

```powershell
C:\flutter\bin\flutter.bat run -d emulator-5554 --debug --no-resident
```

Expected: the debug APK builds, installs, and launches without a Flutter runtime error.

- [ ] **Step 2: Capture primary tab screenshots**

Run:

```powershell
adb -s emulator-5554 shell screencap -p /sdcard/prohelper_overview_current.png
adb -s emulator-5554 pull /sdcard/prohelper_overview_current.png build\prohelper_overview_current.png
adb -s emulator-5554 shell input tap 420 2205
adb -s emulator-5554 shell screencap -p /sdcard/prohelper_work_current.png
adb -s emulator-5554 pull /sdcard/prohelper_work_current.png build\prohelper_work_current.png
adb -s emulator-5554 shell input tap 675 2205
adb -s emulator-5554 shell screencap -p /sdcard/prohelper_actions_current.png
adb -s emulator-5554 pull /sdcard/prohelper_actions_current.png build\prohelper_actions_current.png
adb -s emulator-5554 shell input tap 910 2205
adb -s emulator-5554 shell screencap -p /sdcard/prohelper_more_current.png
adb -s emulator-5554 pull /sdcard/prohelper_more_current.png build\prohelper_more_current.png
```

Expected: all screenshots show loaded authenticated app screens, not splash/login.

- [ ] **Step 3: Record the next defect**

Pick the highest-impact issue that is visible in screenshots and can be fixed without changing backend contracts. Prioritize:

```text
1. Missing or weak card/surface hierarchy on light theme.
2. Oversized controls or headings that reduce operational density.
3. Ambiguous action copy.
4. Missing recovery path for empty/error/loading states.
5. Touch target, label, or contrast accessibility gaps.
```

Expected: one clearly scoped defect is selected before code edits.

---

### Task 2: Notification Action Clarity

**Files:**
- Modify: `lib/features/notifications/presentation/notifications_screen.dart`
- Modify: `lib/features/notifications/presentation/widgets/notification_card.dart`
- Test: `test/features/notifications/notifications_screen_test.dart`

- [ ] **Step 1: Write the failing widget test**

Add a test that renders one unread security notification and asserts:

```dart
expect(find.text('Отметить все'), findsOneWidget);
expect(find.text('Все прочитаны'), findsNothing);
expect(find.text('Отметить прочитанным'), findsOneWidget);
expect(find.text('Прочитано'), findsNothing);
```

Run:

```powershell
C:\flutter\bin\flutter.bat test test\features\notifications\notifications_screen_test.dart --reporter compact
```

Expected before implementation: FAIL because the old state-like copy is still visible.

- [ ] **Step 2: Implement action-oriented copy**

Set the app bar bulk action visible label to:

```dart
label: const Text('Отметить все'),
```

Wrap it with a semantic label:

```dart
Semantics(
  button: true,
  label: 'Отметить все уведомления прочитанными',
  child: TextButton.icon(...),
)
```

Set unread card action to:

```dart
label: const Text('Отметить прочитанным'),
```

Expected: visible copy reads as an action, not a completed state.

- [ ] **Step 3: Verify notification flow**

Run:

```powershell
C:\flutter\bin\flutter.bat test test\features\notifications\notifications_screen_test.dart --reporter compact
C:\flutter\bin\flutter.bat test test\features\notifications\notifications_screen_test.dart test\features\notifications\notifications_provider_test.dart test\features\notifications\notifications_repository_test.dart test\features\notifications\notification_navigation_target_test.dart --reporter compact
```

Expected: all notification tests pass.

- [ ] **Step 4: Emulator smoke**

Open notifications from Overview and confirm the list shows:

```text
Отметить все
Отметить прочитанным
```

Expected: no old `Все прочитаны` action label remains in the list screen.

---

### Task 3: Overview Surface Hierarchy

**Files:**
- Modify: `lib/core/widgets/pro_status_banner.dart`
- Modify: `lib/features/home/presentation/widgets/overview_today_status.dart`
- Test: `test/features/home/mobile_overview_screen_test.dart`

- [ ] **Step 1: Write the regression test**

In the notification-only Overview status test, assert the banner uses an elevated surface:

```dart
final banner = tester.widget<ProStatusBanner>(
  find.byType(ProStatusBanner),
);

expect(banner.surfaceTone, ProSurfaceTone.elevated);
```

Run:

```powershell
C:\flutter\bin\flutter.bat test test\features\home\mobile_overview_screen_test.dart --reporter compact
```

Expected before implementation: FAIL because `surfaceTone` does not exist or defaults to subtle.

- [ ] **Step 2: Add a safe surface tone parameter**

In `ProStatusBanner`, add:

```dart
this.surfaceTone = ProSurfaceTone.subtle,
final ProSurfaceTone surfaceTone;
```

Use it in `ProSurface`:

```dart
tone: surfaceTone,
```

Expected: existing banners keep the old subtle style unless explicitly changed.

- [ ] **Step 3: Elevate Overview status only**

In `OverviewTodayStatus`, pass:

```dart
surfaceTone: ProSurfaceTone.elevated,
```

Expected: the main command-center signal reads as a real card on light theme.

- [ ] **Step 4: Verify Overview**

Run:

```powershell
C:\flutter\bin\flutter.bat test test\core\widgets\pro_components_test.dart test\features\home\mobile_overview_screen_test.dart --reporter compact
C:\flutter\bin\flutter.bat analyze
```

Expected: tests and analyzer pass.

---

### Task 4: Compact Operational Search

**Files:**
- Modify: `lib/core/widgets/pro_search_filter_bar.dart`
- Modify: `lib/features/navigation/presentation/mobile_work_hub_screen.dart`
- Modify: `lib/features/actions/presentation/mobile_action_center_screen.dart`
- Test: `test/core/widgets/pro_components_test.dart`
- Test: `test/features/navigation/mobile_work_hub_screen_test.dart`
- Test: `test/features/actions/mobile_action_center_screen_test.dart`

- [ ] **Step 1: Write component coverage**

Add a widget test that renders `ProSearchFilterBar` with compact density:

```dart
ProSearchFilterBar<String>(
  controller: controller,
  hintText: 'Найти раздел',
  options: const [],
  selectedValue: 'all',
  onFilterChanged: (_) {},
  resultLabel: 'Доступно разделов: 2',
  density: ProSearchFilterDensity.compact,
)
```

Assert:

```dart
expect(searchField.decoration?.isDense, isTrue);
expect(
  searchField.decoration?.prefixIconConstraints?.minHeight,
  ProTouchTarget.comfortable,
);
```

Expected: compact mode keeps a touch-safe 48dp+ target.

- [ ] **Step 2: Implement compact density**

Add:

```dart
enum ProSearchFilterDensity { comfortable, compact }
```

Add parameter:

```dart
this.density = ProSearchFilterDensity.comfortable,
final ProSearchFilterDensity density;
```

When compact, render `resultLabel` above the `TextField` and use smaller surface padding while preserving:

```dart
prefixIconConstraints: const BoxConstraints(
  minWidth: ProTouchTarget.comfortable,
  minHeight: ProTouchTarget.comfortable,
)
```

Expected: Work and Actions search blocks become denser without failing tap target guidelines.

- [ ] **Step 3: Enable compact mode in Work and Actions**

In `MobileWorkHubScreen` and `MobileActionCenterContent`, pass:

```dart
density: ProSearchFilterDensity.compact,
```

Expected: top-level operational catalogs show the compact search layout.

- [ ] **Step 4: Verify search and accessibility**

Run:

```powershell
C:\flutter\bin\flutter.bat test test\core\widgets\pro_components_test.dart test\features\actions\mobile_action_center_screen_test.dart test\features\navigation\mobile_work_hub_screen_test.dart --reporter compact
```

Expected: all tests pass, including accessibility guidelines in `mobile_work_hub_screen_test.dart`.

---

### Task 5: Continue Runtime-Driven Hardening

**Files:**
- Modify only the files required by the selected defect.
- Add or update the narrowest tests that prove the selected defect stays fixed.

- [ ] **Step 1: Re-run emulator audit after every completed defect**

Run the app and capture at least the affected screen:

```powershell
C:\flutter\bin\flutter.bat run -d emulator-5554 --debug --no-resident
adb -s emulator-5554 shell screencap -p /sdcard/prohelper_after_fix.png
adb -s emulator-5554 pull /sdcard/prohelper_after_fix.png build\prohelper_after_fix.png
```

Expected: the affected screen is visually improved and still functional.

- [ ] **Step 2: Required verification after each Flutter UI change**

Run:

```powershell
C:\flutter\bin\flutter.bat analyze
C:\flutter\bin\flutter.bat test --reporter compact
```

Expected: analyzer passes and the full widget/unit suite passes.

- [ ] **Step 3: Do not mark the goal complete until the completion audit passes**

Completion requires evidence for:

```text
1. Emulator walkthrough of login, Overview, Work, Actions, More, Notifications, and at least one work-flow detail screen.
2. Light theme surface hierarchy verified visually.
3. Touch/accessibility checks passing for changed screens.
4. Risky UI changes covered by tests.
5. `flutter analyze` clean.
6. Full `flutter test` clean.
7. No unresolved severe UX defects found in the final walkthrough.
```

Expected: if any item is missing or only partially verified, keep the goal active and continue.

#### Task 5A: Russian Material Date Picker

**Files:**
- Add: `lib/core/localization/most_localizations.dart`
- Modify: `lib/main.dart`
- Modify: `pubspec.yaml`
- Modify: `pubspec.lock`
- Modify: `test/helpers/mobile_integration_test_helpers.dart`
- Modify: `test/widget_test.dart`
- Modify: `test/features/workforce/self_attendance_screen_test.dart`

- [x] **Step 1: Reproduce the defect on emulator**

Open:

```text
Работа -> Явка -> Отметить мою явку -> Выберите дату явки
```

Expected before fix: date picker incorrectly shows `Select date`, `July 2026`, `Cancel`, `OK`.

- [x] **Step 2: Configure app-level localization**

Add Flutter SDK localizations:

```yaml
flutter_localizations:
  sdk: flutter
```

Configure `MaterialApp` with:

```dart
locale: MostLocalizations.ru,
localizationsDelegates: MostLocalizations.delegates,
supportedLocales: MostLocalizations.supportedLocales,
```

Expected: all Material/Cupertino system widgets follow the app's Russian UI language.

- [x] **Step 3: Keep dependencies compatible with the installed Flutter SDK**

Use `intl: ^0.19.0`, because Flutter 3.29.3 pins `intl 0.19.0` through `flutter_localizations`.

Expected: `flutter pub get` resolves without upgrading the local Flutter SDK.

- [x] **Step 4: Verify tests and emulator**

Run:

```powershell
C:\flutter\bin\flutter.bat test test\widget_test.dart test\features\workforce\self_attendance_screen_test.dart --reporter compact
C:\flutter\bin\flutter.bat analyze
C:\flutter\bin\flutter.bat test --reporter compact
C:\flutter\bin\flutter.bat run -d emulator-5554 --debug --no-resident
```

Expected: app-level localization test passes, self-attendance date picker test passes, analyzer is clean, full suite passes, and emulator date picker shows Russian labels.

---

#### Task 5B: Locale-Aware Companion Amount Metrics

**Files:**
- Modify: `lib/features/module_companions/presentation/companion_module_screen.dart`
- Modify: `test/features/module_companions/presentation/companion_module_screen_test.dart`

- [x] **Step 1: Reproduce the defect on emulator**

Open:

```text
Ещё -> Договоры
```

Expected before fix: contract amount metrics show English decimal formatting such as `33 500.00`, `123 123 123.00`, and `10 500 000.00`.

- [x] **Step 2: Format only amount-like metrics with Russian locale**

Use `intl` `NumberFormat.decimalPattern('ru_RU')` only when the metric label is amount-related, for example `Сумма`, `Стоимость`, `Цена`, or `Бюджет`.

Expected: amount metrics use grouping spaces and comma decimals, while counters such as `Акты: 0` remain unchanged.

- [x] **Step 3: Add regression coverage**

Assert that companion cards render:

```dart
expect(find.text('100 000,00'), findsOneWidget);
expect(find.text('100000.00'), findsNothing);
expect(find.text('2'), findsOneWidget);
```

Expected: old API-style amount strings are not shown in the UI, and non-amount counters are not reformatted as money.

- [x] **Step 4: Verify tests, analyzer, and emulator**

Run:

```powershell
C:\flutter\bin\flutter.bat test test\features\module_companions\presentation\companion_module_screen_test.dart --reporter compact
C:\flutter\bin\flutter.bat test test\features\module_companions\presentation\companion_module_screen_test.dart test\features\module_companions\domain\companion_module_provider_test.dart test\features\module_companions\data\companion_module_model_test.dart test\features\module_companions\data\companion_module_repository_test.dart --reporter compact
C:\flutter\bin\flutter.bat analyze
C:\flutter\bin\flutter.bat test --reporter compact
C:\flutter\bin\flutter.bat run -d emulator-5554 --debug --no-resident
```

Expected: targeted module companion tests pass, analyzer is clean, the full suite passes, and emulator `Ещё -> Договоры` shows comma-decimal Russian amount metrics.

---

#### Task 5C: Companion Refresh Button Accessibility Label

**Files:**
- Modify: `lib/features/module_companions/presentation/companion_module_screen.dart`
- Modify: `test/features/module_companions/presentation/companion_module_screen_test.dart`

- [x] **Step 1: Reproduce the defect in Android accessibility tree**

Open:

```text
Ещё -> Договоры
```

Expected before fix: the top-right refresh `IconButton` appears in UIAutomator as a clickable `NAF` node with empty `content-desc`.

- [x] **Step 2: Add an explicit accessible label**

Set both the visible tooltip and icon semantic label to:

```dart
Обновить список
```

Expected: the icon-only refresh action has a stable Russian accessible name.

- [x] **Step 3: Add regression coverage**

Assert:

```dart
expect(find.bySemanticsLabel('Обновить список'), findsOneWidget);
```

Expected: widget semantics coverage fails if the icon-only action loses its accessible label.

- [x] **Step 4: Verify code checks**

Run:

```powershell
C:\flutter\bin\flutter.bat test test\features\module_companions\presentation\companion_module_screen_test.dart --reporter compact
C:\flutter\bin\flutter.bat analyze
C:\flutter\bin\flutter.bat test --reporter compact
```

Expected: targeted companion screen test passes, analyzer is clean, and the full suite passes.

- [x] **Step 5: Resume emulator dump after device recovery**

The Android emulator showed `Process system isn't responding` during login/device smoke and did not return to a stable focused activity after `adb reboot`.

Verified after recovery: installed the current debug build, logged in with the test account, opened `Ещё -> Договоры`, dumped UIAutomator tree, and confirmed the refresh node exposes `Обновить список`. Amount metrics also rendered as `33 500,00`, `123 123 123,00`, and `123,00`.

---

#### Task 5D: Warehouse Tasks Refresh Accessibility Label

**Files:**
- Modify: `lib/features/warehouse/presentation/warehouse_tasks_screen.dart`
- Add: `test/features/warehouse/presentation/warehouse_tasks_screen_test.dart`

- [x] **Step 1: Find the defect in code audit**

Inspect `WarehouseTasksScreen` AppBar.

Expected before fix: the refresh `IconButton` has no `tooltip` and the refresh icon has no `semanticLabel`.

- [x] **Step 2: Add explicit Russian accessible copy**

Set:

```dart
tooltip: 'Обновить список'
semanticLabel: 'Обновить список'
```

Expected: the icon-only action is named consistently with the companion module refresh action.

- [x] **Step 3: Add regression coverage with a fake warehouse repository**

Add a widget test that renders `WarehouseTasksScreen` without network access and asserts:

```dart
expect(find.bySemanticsLabel('Обновить список'), findsOneWidget);
```

Expected: the test fails if the warehouse task queue refresh button loses its accessible label.

- [x] **Step 4: Verify code checks**

Run:

```powershell
C:\flutter\bin\flutter.bat test test\features\warehouse\presentation\warehouse_tasks_screen_test.dart --reporter compact
C:\flutter\bin\flutter.bat analyze
C:\flutter\bin\flutter.bat test --reporter compact
```

Expected: the targeted test passes, analyzer is clean, and the full suite passes.

- [x] **Step 5: Resume emulator smoke after login/device stability is restored**

During the follow-up device smoke, Android showed ANR dialogs while entering the test account and did not complete the login flow reliably.

Verified after recovery: opened `Обзор -> Склад -> Очередь складских задач` on the emulator and confirmed the refresh button exposes `Обновить список` in UIAutomator.

---

#### Task 5E: Login Credential Field IME Hardening

**Files:**
- Modify: `lib/features/auth/presentation/login_screen.dart`
- Modify: `test/features/auth/presentation/login_screen_test.dart`

- [x] **Step 1: Gather root-cause evidence for login ANR**

Fresh logcat and dropbox evidence showed input dispatch timeouts around МОСТ while the emulator and Google Keyboard were also overloaded. The app code did not run network or storage work on every character, but the email field was reported by Android IME as an autocorrect-enabled email input.

Expected: avoid treating the valid test credentials as the issue and fix only the confirmed credential-input configuration problem.

- [x] **Step 2: Disable text correction helpers on credential fields**

Set email and password fields to disable autocorrect, suggestions, personalized IME learning, smart dashes, and smart quotes.

Expected: Android IME receives credential fields as no-suggestion inputs and does not learn the test account/password.

- [x] **Step 3: Add regression coverage**

Add a widget test that asserts both login fields keep:

```dart
autocorrect == false
enableSuggestions == false
enableIMEPersonalizedLearning == false
smartDashesType == SmartDashesType.disabled
smartQuotesType == SmartQuotesType.disabled
```

Expected: future regressions in credential-field configuration fail in tests.

- [x] **Step 4: Verify runtime login on emulator**

Using the provided test account, the app logged in successfully and reached `Обзор`. Fresh logcat showed no new ANR, and Android IME reported:

```text
Email: Filter[NoSuggestion], enableLearning=false, autoCorrection=false
Password: Password[NoSuggestion], enableLearning=false, autoCorrection=false
```

Expected: login is usable on the current emulator and the main overview loads dashboard, projects, notifications, and modules.

- [x] **Step 5: Verify code checks**

Run:

```powershell
C:\flutter\bin\flutter.bat test test\features\auth\presentation\login_screen_test.dart --reporter compact
C:\flutter\bin\flutter.bat analyze
C:\flutter\bin\flutter.bat test --reporter compact
```

Expected: targeted login test passes, analyzer is clean, and the full suite passes.

---

#### Task 5F: Warehouse Tasks Empty State And Search Clear Accessibility

**Files:**
- Modify: `lib/features/warehouse/presentation/warehouse_tasks_screen.dart`
- Modify: `test/features/warehouse/presentation/warehouse_tasks_screen_test.dart`

- [x] **Step 1: Inspect the live screen and code**

Open:

```text
Обзор -> Склад -> Очередь складских задач
```

Expected before fix: the empty state says `Задач не найдено`, and the search clear icon is visually present only after input but has no stable accessible name.

- [x] **Step 2: Improve the user-facing empty state copy**

Set the empty state title to:

```dart
Задач пока нет
```

Expected: the empty state reads as a normal operational state, not as a failed search result.

- [x] **Step 3: Add explicit clear-search accessibility copy**

Set both tooltip and icon semantic label to:

```dart
Очистить поиск
```

Expected: the icon-only clear action is available to accessibility services and UI automation.

- [x] **Step 4: Add regression coverage**

Assert:

```dart
expect(find.text('Задач пока нет'), findsOneWidget);
expect(find.bySemanticsLabel('Очистить поиск'), findsOneWidget);
```

Expected: the test fails if empty-state copy regresses or the clear-search action loses its accessible label.

- [x] **Step 5: Verify on emulator**

Verified through Android UIAutomator:

```text
Задач пока нет
Очистить поиск
```

Expected: after entering `test` into search, `Очистить поиск` appears in the accessibility tree.

---

#### Task 5G: Transient Network Retry For Safe Mobile API Reads

**Files:**
- Modify: `lib/core/network/dio_client.dart`
- Add: `lib/core/network/network_retry_interceptor.dart`
- Modify: `test/core/network/dio_client_test.dart`

- [x] **Step 1: Gather root-cause evidence**

The emulator opened `Задачи склада`, but the first task request failed before any HTTP response:

```text
GET /mobile/warehouse/warehouses/9/tasks?limit=60
HandshakeException: Connection terminated during handshake
```

Manual `Повторить` on the same endpoint succeeded with a normal response.

Expected: treat this as a transient network failure, not an API contract, permission, or parsing defect.

- [x] **Step 2: Check current Dio retry API**

Context7 confirmed the Dio 5 interceptor pattern: retry the original `RequestOptions` through `dio.fetch(...)` and finish with `handler.resolve(...)`.

Expected: use current Dio API instead of hand-rolling a separate HTTP path.

- [x] **Step 3: Add scoped retry behavior**

Add one automatic retry only when all conditions are true:

```text
method is GET or HEAD
response is absent
error is timeout, connection error, SocketException, HandshakeException, HttpException, or TimeoutException
```

Expected: transient read failures are retried once, while mutating requests are never duplicated.

- [x] **Step 4: Add regression coverage**

Assert:

```dart
GET transient failure -> retried once and succeeds
POST transient failure -> not retried
```

Expected: safe reads become more resilient without risking duplicate warehouse operations.

- [x] **Step 5: Verify code checks**

Run:

```powershell
C:\flutter\bin\flutter.bat test test\core\network\dio_client_test.dart --reporter compact
C:\flutter\bin\flutter.bat test test\features\warehouse\presentation\warehouse_tasks_screen_test.dart --reporter compact
C:\flutter\bin\flutter.bat analyze
C:\flutter\bin\flutter.bat test --reporter compact
```

Expected: network and warehouse targeted tests pass, analyzer is clean, and the full mobile test suite passes.

---

#### Task 5H: Warehouse Primary Receipt Action Without Content Overlap

**Files:**
- Modify: `lib/features/warehouse/presentation/warehouse_screen.dart`
- Modify: `test/features/warehouse/presentation/warehouse_screen_test.dart`

- [x] **Step 1: Reproduce the visual defect on emulator**

Open:

```text
Обзор -> Склад
```

Expected before fix: the extended `Оприходовать` FAB floats above the scroll content and partially covers the lower warehouse action card.

- [x] **Step 2: Replace the overlapping FAB with an in-flow operation card**

Remove the scaffold FAB and add `Оприходовать` as the first `ProActionTile` in the warehouse operation list.

Expected: the primary receipt action remains prominent, but it no longer covers cards or text.

- [x] **Step 3: Add regression coverage**

Assert:

```dart
expect(find.byType(FloatingActionButton), findsNothing);
expect(find.text('Оприходовать'), findsOneWidget);
```

Expected: future changes do not bring back the overlapping FAB.

- [x] **Step 4: Verify on emulator**

Verified through screenshot and UIAutomator:

```text
Оприходовать
Принять материалы на склад с фото и документом.
```

Expected: the action appears as a normal card button before `Сканирование склада`, and no floating receipt button overlaps the screen.

- [x] **Step 5: Verify code checks**

Run:

```powershell
C:\flutter\bin\flutter.bat test test\features\warehouse\presentation\warehouse_screen_test.dart --reporter compact
C:\flutter\bin\flutter.bat analyze
C:\flutter\bin\flutter.bat test --reporter compact
```

Expected: targeted warehouse screen test passes, analyzer is clean, and the full mobile test suite passes.

---

#### Task 5I: Light Theme System Status Bar Readability

**Files:**
- Modify: `lib/core/theme/pro_theme.dart`
- Modify: `lib/main.dart`
- Modify: `test/core/design/pro_design_tokens_test.dart`
- Modify: `test/widget_test.dart`

- [x] **Step 1: Reproduce the visual defect on emulator**

Open:

```text
Обзор -> Рабочие процессы -> Подробнее
```

Expected before fix: on transparent AppBar screens the Android status-bar time and system icons can render white on a very light surface, making the top system area unreadable.

- [x] **Step 2: Add a failing theme regression**

Assert that both app themes define an AppBar `SystemUiOverlayStyle`:

```dart
light theme -> dark Android status icons, light iOS status brightness
dark theme -> light Android status icons, dark iOS status brightness
```

Expected: the test fails while the theme leaves `systemOverlayStyle` unset.

- [x] **Step 3: Set overlay style at theme and app-root level**

Configure the light and dark `AppBarTheme` values with transparent status-bar color and matching icon brightness. Reuse the same overlay styles in the `MaterialApp.builder` root `AnnotatedRegion<SystemUiOverlayStyle>` so screens without AppBar, including splash and session-loading states, also get readable system icons.

Expected: all legacy and modern AppBar screens inherit readable system status icons without patching individual screens, and AppBar-less states no longer fall back to unreadable white status icons on light surfaces.

- [x] **Step 4: Verify on emulator**

Verified through screenshots and UIAutomator on:

```text
Обзор
Согласования
Детали согласования
```

Expected: the Android status-bar time/icons are dark on light surfaces, `Детали согласования` is present, and no `NAF="true"` nodes are reported on the checked screen.

- [x] **Step 5: Verify code checks**

Run:

```powershell
C:\flutter\bin\flutter.bat test test\core\design\pro_design_tokens_test.dart --reporter compact
C:\flutter\bin\flutter.bat test test\widget_test.dart --reporter compact
C:\flutter\bin\flutter.bat analyze
C:\flutter\bin\flutter.bat test --reporter compact
git diff --check -- prohelpers_mobile/lib/core/theme/pro_theme.dart prohelpers_mobile/lib/main.dart prohelpers_mobile/test/core/design/pro_design_tokens_test.dart prohelpers_mobile/test/widget_test.dart
```

Expected: targeted design-token tests pass, analyzer is clean, the full mobile test suite passes, and diff-check reports no whitespace errors.

---

#### Task 5J: Workflow List Comment Action Visibility

**Files:**
- Modify: `lib/features/workflow_management/presentation/workflow_management_screen.dart`
- Modify: `test/features/workflow_management/presentation/workflow_management_screen_test.dart`

- [x] **Step 1: Reproduce the visual defect on emulator**

Open:

```text
Обзор -> Рабочие процессы
```

Expected before fix: the workflow-card comment action appears as a lone chat icon without visible text, even though accessibility exposes `Добавить комментарий`.

- [x] **Step 2: Add a failing widget regression**

Update the workflow screen test to require a visible `Комментарий` command inside a Material button after scrolling to the lower card actions.

Expected: the test fails while the list card uses an icon-only `IconButton`.

- [x] **Step 3: Replace the icon-only action**

Use `OutlinedButton.icon` with the existing chat icon and visible `Комментарий` label, matching the detail action panel pattern.

Expected: the command is understandable visually and remains touch-friendly.

- [x] **Step 4: Verify on emulator**

Verified through screenshot and UIAutomator:

```text
Согласования
Комментарий
NAF="true" absent on the checked screen
```

Expected: the workflow list card shows a visible `Комментарий` button without overlapping adjacent actions or the next card.

- [x] **Step 5: Verify code checks**

Run:

```powershell
C:\flutter\bin\flutter.bat test test\features\workflow_management\presentation\workflow_management_screen_test.dart --reporter compact
C:\flutter\bin\flutter.bat analyze
C:\flutter\bin\flutter.bat test --reporter compact
```

Expected: workflow screen tests pass, analyzer is clean, and the full mobile test suite passes.

---

#### Task 5K: Login Field Semantics Hardening

**Files:**
- Modify: `lib/features/auth/presentation/login_screen.dart`
- Modify: `test/features/auth/presentation/login_screen_test.dart`

- [x] **Step 1: Reproduce the accessibility evidence on emulator**

Open a clean login form after clearing only the debug app data on the emulator.

Expected before fix: UIAutomator reports nested `NAF="true"` email `EditText` nodes even though Flutter semantics exposes `Поле ввода: Email`.

- [x] **Step 2: Add a widget regression**

Assert that the login fields expose explicit screen-reader labels, are text-field semantics nodes, support `SemanticsAction.setText`, and that the email node has no child semantics nodes.

Expected: the test fails while the named wrapper does not provide `setText`.

- [x] **Step 3: Harden field semantics without hiding password controls**

Use a controller-driven `ValueListenableBuilder` and `Semantics.onSetText`. Collapse child semantics only for fields without suffix controls, so the email field becomes a single named text-field node while the password visibility button remains separately accessible.

Expected: email field semantics are simpler and named; password field keeps `Показать пароль` / `Скрыть пароль`.

- [x] **Step 4: Verify on emulator**

Verified through UIAutomator:

```text
Поле ввода: Email
Поле ввода: Пароль
Показать пароль
```

Note: Android UIAutomator still marks the empty email `EditText` as `NAF="true"` because the native node exposes the Flutter label as `hint`, not `content-desc`. We intentionally did not fake a non-empty value such as `Email`, because that would make assistive tech announce placeholder text as user-entered content.

- [x] **Step 5: Verify code checks**

Run:

```powershell
C:\flutter\bin\flutter.bat test test\features\auth\presentation\login_screen_test.dart --reporter compact
C:\flutter\bin\flutter.bat analyze
```

Expected: auth presentation tests pass and analyzer is clean.

---

#### Task 5L: Login Keyboard Spacing And Persistent Field Labels

**Files:**
- Modify: `lib/features/auth/presentation/login_screen.dart`
- Modify: `test/features/auth/presentation/login_screen_test.dart`

- [x] **Step 1: Reproduce the visual defect on emulator**

Open the clean login screen and focus the credential fields.

Expected before fix: empty fields rely on auto-floating labels that read as placeholder-only at rest, and with the keyboard open the submit button sits directly against the keyboard edge with no breathing room.

- [x] **Step 2: Add failing widget regressions**

Assert that both credential fields use persistent floating labels and that the login scroll container adds extra bottom spacing when `MediaQuery.viewInsets.bottom` is non-zero.

Expected before implementation: the auth presentation test fails with `FloatingLabelBehavior.auto` and bottom padding `28.0`.

- [x] **Step 3: Implement the login form UX hardening**

Set credential field decorations to:

```dart
floatingLabelBehavior: FloatingLabelBehavior.always
```

Set the login scroll view to dismiss the keyboard on drag and add a 24dp bottom breathing-room increment while the keyboard is visible.

Expected: field purpose remains visible even when empty or filled, and the submit action no longer visually collides with the software keyboard.

- [x] **Step 4: Verify code checks**

Run:

```powershell
C:\flutter\bin\flutter.bat test test\features\auth\presentation\login_screen_test.dart --reporter compact
```

Expected: auth presentation tests pass.

- [x] **Step 5: Resume emulator smoke after device recovery**

Fresh APK install initially hit Android framework ANR dialogs:

```text
Pixel Launcher isn't responding
System UI isn't responding
```

After choosing `Wait`, focus returned to `ru.prohelper.prohelpers_mobile.MainActivity`. Verified by screenshot:

```text
Email
Пароль
Войти
```

Expected: clean login screen shows persistent field labels, and the keyboard-open state keeps visible space between the submit button and keyboard.

---

#### Task 5M: Search Clear Action Accessibility

**Files:**
- Modify: `lib/core/widgets/pro_search_filter_bar.dart`
- Modify: `test/core/widgets/pro_components_test.dart`

- [x] **Step 1: Reproduce the runtime accessibility defect**

Open the Work tab, enter a search query that produces an empty state, and dump UIAutomator hierarchy.

Expected before fix: the inline clear icon is visible in the search field but not exposed as a separate `Очистить поиск` button in the Android accessibility tree.

- [x] **Step 2: Add a failing component regression**

Render `ProSearchFilterBar` with a non-empty controller and `onClearSearch`, then assert that `Очистить поиск` is a semantic button with a tap action.

Expected before implementation: `find.bySemanticsLabel('Очистить поиск')` finds no widget.

- [x] **Step 3: Expose clear action as a stable semantic button**

Reserve suffix-icon space inside the text field and overlay a dedicated `Semantics(button: true, label: 'Очистить поиск')` tap target for the clear action.

Expected: the text field keeps its compact layout, and assistive tech can focus and activate the clear action independently.

- [x] **Step 4: Verify tests and emulator smoke**

Run:

```powershell
C:\flutter\bin\flutter.bat test test\core\widgets\pro_components_test.dart --reporter compact
C:\flutter\bin\flutter.bat test test\core\widgets\pro_components_test.dart test\features\navigation\mobile_work_hub_screen_test.dart test\features\actions\mobile_action_center_screen_test.dart --reporter compact
```

Expected: tests pass. On the emulator, UIAutomator reports `content-desc="Очистить поиск"` as a clickable button, and tapping it clears the field and restores the available Work sections.

- [x] **Step 5: Record startup reliability signal**

Fresh debug reinstall triggered an Android ANR dialog and first display took about 70 seconds. A clean app relaunch without reinstall did not ANR, but still took about 26 seconds to display.

Expected: keep this as the next performance/reliability investigation candidate instead of treating it as a completed UX polish item.

---

#### Task 5N: First-Frame Auth Bootstrap Hardening

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/features/auth/domain/auth_provider.dart`
- Modify: `test/features/auth/auth_provider_test.dart`

- [x] **Step 1: Reproduce and separate startup phases**

Measure cold relaunch with `adb shell am start -W` and logcat.

Evidence:

```text
debug relaunch: Displayed after about 29s; /auth/me starts after Displayed.
debug reinstall relaunch: Displayed after about 24s; /auth/me starts after Displayed.
release first launch after reinstall: Displayed after about 24s.
release repeat relaunch: TotalTime about 9.3s.
```

Expected: do not blame API/network for the first-frame delay; the first user-visible frame is delayed before authenticated API requests begin.

- [x] **Step 2: Add a regression for delayed auth checking**

Add a test that constructs `AuthNotifier` with `autoCheckAuth: false` and verifies that secure storage is not read until `checkAuth()` is called explicitly.

Expected before implementation: the test fails to compile because `autoCheckAuth` does not exist.

- [x] **Step 3: Move production auth check after the first app frame**

Create the production `authProvider` with `autoCheckAuth: false`, convert `MostApp` to `ConsumerStatefulWidget`, and call `checkAuth()` from a post-frame callback.

Expected: the app can render the session-checking surface before token storage/profile validation starts.

- [x] **Step 4: Verify code behavior**

Run:

```powershell
C:\flutter\bin\flutter.bat test test\features\auth\auth_provider_test.dart test\widget_test.dart --reporter compact
```

Expected: auth provider and app-level startup tests pass.

- [ ] **Step 5: Continue startup performance investigation**

Residual evidence: even release repeat relaunch still reports about `9.3s` first display on the current emulator. This iteration removes auth/bootstrap coupling but does not fully solve the startup performance issue.

Expected next: profile native/Flutter first-frame work separately from authenticated data loading before changing more code.

---

#### Task 5O: Overview Work Summary Density

**Files:**
- Modify: `lib/features/home/presentation/widgets/overview_work_summary.dart`
- Modify: `test/features/home/mobile_overview_screen_test.dart`

- [x] **Step 1: Reproduce the viewport defect**

Open Overview on the emulator.

Expected before fix: the `Склад` row in `Рабочая сводка` is partially cut at the bottom of the first viewport, making the main screen look unfinished near the bottom navigation.

- [x] **Step 2: Add a compact-row regression**

Extend the existing work-summary test to assert that the row semantic button height is at most `60` logical pixels.

Expected before implementation: the test fails with actual row height `68.0`.

- [x] **Step 3: Tighten the row presentation**

Reduce vertical padding, icon box size, icon size, and title typography from `bodyLarge` to `bodyMedium` while keeping a row height above the minimum touch target.

Expected: rows remain tappable and readable but fit more operational content in the first viewport.

- [x] **Step 4: Verify code and emulator**

Run:

```powershell
C:\flutter\bin\flutter.bat test test\features\home\mobile_overview_screen_test.dart --plain-name "work summary uses compact status rows without empty KPI tiles" --reporter compact
C:\flutter\bin\flutter.bat test test\features\home\mobile_overview_screen_test.dart test\features\mobile_visual\mobile_viewport_audit_test.dart --reporter compact
```

Expected: tests pass. On emulator, the `Склад` row is visible with icon, text, status pill, and chevron in the first viewport.

---

#### Task 5P: Compact Search Surface Contrast

**Files:**
- Modify: `lib/core/widgets/pro_search_filter_bar.dart`
- Modify: `test/core/widgets/pro_components_test.dart`

- [x] **Step 1: Reproduce the light-theme surface weakness**

Open `Работа` and `Действия` on the emulator.

Expected before fix: the compact search block uses a subtle surface that visually blends into the page canvas, making the first screen feel less structured than the card sections below it.

- [x] **Step 2: Add a surface-tone regression**

Extend the compact search filter component test to assert that the compact `ProSearchFilterBar` uses `ProSurfaceTone.elevated`.

Expected before implementation: the test fails because the compact search surface is `ProSurfaceTone.subtle`.

- [x] **Step 3: Promote only compact search to elevated surface**

Use `ProSurfaceTone.elevated` when `density == ProSearchFilterDensity.compact`, while preserving `ProSurfaceTone.subtle` for the comfortable variant.

Expected: top search panels gain clear card separation in light theme without changing dense form/list search controls elsewhere.

- [x] **Step 4: Verify code and emulator**

Run:

```powershell
C:\flutter\bin\flutter.bat test test\core\widgets\pro_components_test.dart test\features\navigation\mobile_work_hub_screen_test.dart test\features\actions\mobile_action_center_screen_test.dart --reporter compact
C:\flutter\bin\flutter.bat analyze
C:\flutter\bin\flutter.bat test --reporter compact
```

Expected: tests and analyzer pass. On emulator, `Работа` and `Действия` search blocks read as real cards against the light canvas.

---

#### Task 5Q: Android First-Frame Renderer Hardening

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`
- Add: `test/android/android_manifest_startup_test.dart`

- [x] **Step 1: Reproduce and localize startup delay**

Run profile startup traces with the real app and a temporary minimal entrypoint.

Evidence before fix:

```text
real app with default renderer: Time to first frame 23307ms
minimal probe with default renderer: Time to first frame 21327ms
start_up_info: timeToFrameworkInitMicros 21736061
```

Expected: the delay is not caused by auth, API, Overview widgets, Riverpod state, or selected-project logic; most of the delay happens before Flutter framework init.

- [x] **Step 2: Test renderer hypothesis**

Run the same profile startup trace with `--no-enable-impeller`.

Evidence:

```text
minimal probe with --no-enable-impeller: Time to first frame 8889ms
real app with --no-enable-impeller: Time to first frame 16464ms
```

Expected: disabling Impeller materially reduces startup time on the current Android x86_64 emulator and removes the repeated OpenGLES `libEGL called unimplemented OpenGL ES API` errors.

- [x] **Step 3: Add a failing manifest regression**

Add a test that reads `android/app/src/main/AndroidManifest.xml` and asserts the Flutter Android embedding meta-data contains:

```xml
android:name="io.flutter.embedding.android.EnableImpeller"
android:value="false"
```

Expected before implementation: the test fails because the manifest has no explicit renderer override.

- [x] **Step 4: Disable Impeller through the official Android embedding meta-data**

Add application-level meta-data:

```xml
<meta-data
    android:name="io.flutter.embedding.android.EnableImpeller"
    android:value="false" />
```

Expected: APKs built normally carry the same renderer setting as the measured `--no-enable-impeller` runs.

- [x] **Step 5: Verify code and startup trace**

Run:

```powershell
C:\flutter\bin\flutter.bat test test\android\android_manifest_startup_test.dart --reporter compact
C:\flutter\bin\flutter.bat analyze
C:\flutter\bin\flutter.bat test --reporter compact
C:\flutter\bin\flutter.bat run --profile --trace-startup -d emulator-5554 --no-resident
```

Expected: manifest test, analyzer, and full suite pass. Profile startup trace no longer logs Impeller/OpenGLES backend initialization, and first-frame time improves against the default-renderer baseline. Residual startup delay remains a separate optimization candidate.

Evidence after fix:

```text
real app with manifest renderer override: Time to first frame 17043ms
start_up_info: timeToFrameworkInitMicros 16492510
start_up_info: timeAfterFrameworkInitMicros 550568
```

---

#### Task 5R: Full-Screen Gesture Safe Areas

**Files:**
- Modify: `lib/features/notifications/presentation/notifications_screen.dart`
- Modify: `lib/features/workflow_management/presentation/workflow_management_screen.dart`
- Modify: `test/features/notifications/notifications_screen_test.dart`
- Modify: `test/features/workflow_management/presentation/workflow_management_screen_test.dart`

- [x] **Step 1: Reproduce bottom gesture overlap**

Open `Уведомления`, `Согласования`, and `Детали согласования` on the Android emulator.

Evidence before fix:

```text
Notifications scroll/body bottom: 2400, Android gesture bar overlays visible list text.
Workflow list scroll/body bottom: 2400, second card text sits under the gesture bar.
Workflow detail body also used the full 2400px viewport.
```

Expected: full-screen routes must end above the Android gesture area, while tabbed root screens continue to use the bottom navigation shell.

- [x] **Step 2: Add regression tests**

Add widget tests that simulate a 390x844 phone with `viewPadding.bottom = 34` and assert that the full-screen scroll viewport ends at or above `810`.

Expected before implementation:

```text
Notifications CustomScrollView bottom: 844.0
Workflow ListView bottom: 844.0
```

- [x] **Step 3: Apply SafeArea to full-screen bodies**

Wrap notification and workflow full-screen bodies in bottom-aware `SafeArea`, preserving existing list padding and leaving root tab screens unchanged.

Expected: content and actions remain scrollable and visible without being hidden behind Android gesture navigation.

- [x] **Step 4: Verify tests, analyzer, suite, and emulator**

Run:

```powershell
C:\flutter\bin\flutter.bat test test\features\notifications\notifications_screen_test.dart test\features\workflow_management\presentation\workflow_management_screen_test.dart --reporter compact
C:\flutter\bin\flutter.bat analyze
C:\flutter\bin\flutter.bat test --reporter compact
C:\flutter\bin\flutter.bat run --release -d emulator-5554 --no-resident
```

Evidence after fix:

```text
Notifications ScrollView bottom: 2337
Workflow list ScrollView bottom: 2337
Workflow detail body bottom: 2337
flutter analyze: No issues found
flutter test: 387 tests passed
```

---

#### Task 5S: Transient HTTP Status Retry For Safe Mobile API Reads

**Files:**
- Modify: `lib/core/network/network_retry_interceptor.dart`
- Modify: `test/core/network/dio_client_test.dart`

- [x] **Step 1: Reproduce the missing retry branch**

Add a failing regression test for a safe `GET` that receives a transient HTTP response status first and succeeds on the second attempt.

Evidence before fix:

```text
GET /mobile/notifications
first response: 503
expected retry count: 2
actual retry count: 1
DioException [bad response]
```

Expected: transient server-side read failures are handled like transient transport read failures, while auth, validation, and mutating requests remain single-attempt.

- [x] **Step 2: Check current Dio error handling API**

Context7 confirmed that Dio 5 exposes `DioException.response?.statusCode` in `onError`, and the existing retry path can re-run the original request with `dio.fetch(error.requestOptions)` and resolve through `handler.resolve(response)`.

Expected: extend the existing interceptor instead of adding a parallel API path.

- [x] **Step 3: Add scoped HTTP status retry behavior**

Retry once only when all conditions are true:

```text
method is GET or HEAD
status is 408, 429, 500, 502, 503, or 504
retry count is below maxRetries
request is not cancelled
request did not opt out through skip_network_retry
```

Expected: safe startup reads recover from short backend/proxy interruptions; `401`, validation/client errors, and `POST`/mutating requests are not duplicated.

- [x] **Step 4: Add regression coverage**

Assert:

```dart
GET 503 -> GET 200
GET 401 -> no retry
POST 503 -> no retry
```

Expected: retry behavior remains conservative and auditable.

- [x] **Step 5: Verify code checks and release smoke**

Run:

```powershell
C:\flutter\bin\flutter.bat test test\core\network\dio_client_test.dart --reporter compact
C:\flutter\bin\flutter.bat analyze
C:\flutter\bin\flutter.bat test --reporter compact
C:\flutter\bin\flutter.bat run --release -d emulator-5554 --no-resident
```

Evidence after fix:

```text
dio_client_test.dart: 6 tests passed
flutter analyze: No issues found
flutter test: 390 tests passed
release APK: build\app\outputs\flutter-apk\app-release.apk, 21.0MB
release cold-start UIAutomator: Overview loaded with notifications count, no load error
release Notifications screen: real notification list loaded, no load error
release Work tab: sections loaded, no load error
release Workflow approvals: summary and real items loaded, no load error
release logcat: no app crash, Flutter exception, or DioException found
```

---

#### Task 5T: Dynamic Type App Bar Resilience

**Files:**
- Modify: `lib/core/widgets/pro_page_scaffold.dart`
- Modify: `test/core/widgets/pro_components_test.dart`

- [x] **Step 1: Reproduce fixed-height header behavior**

Add a widget test for a 390x844 phone with `TextScaler.linear(1.6)` and a `ProPageScaffold` title plus subtitle.

Evidence before fix:

```text
Expected: a value greater than <56.0>
Actual: <null>
```

Expected: the shared operational scaffold must reserve enough app-bar height for large system text instead of relying on the default 56dp toolbar.

- [x] **Step 2: Check current Flutter API**

Context7 confirmed the current Flutter direction: use `MediaQuery.textScaler` for text scaling and `AppBar.toolbarHeight` to customize the toolbar height.

Expected: implement this through the shared scaffold, not per-screen overrides.

- [x] **Step 3: Add adaptive toolbar height**

Compute the toolbar height from the active `TextScaler`, the title/caption text styles, and the presence of a subtitle. Clamp the result between the normal Material toolbar height and a conservative mobile maximum.

Expected: normal font scale keeps the familiar compact header; large font scale gets more vertical space without breaking the rest of the screen.

- [x] **Step 4: Verify code checks**

Run:

```powershell
C:\flutter\bin\flutter.bat test test\core\widgets\pro_components_test.dart --plain-name "pro page scaffold keeps header readable with large text" --reporter compact
C:\flutter\bin\flutter.bat test test\core\widgets\pro_components_test.dart --reporter compact
C:\flutter\bin\flutter.bat analyze
C:\flutter\bin\flutter.bat test test\features\mobile_visual\mobile_viewport_audit_test.dart --reporter compact
C:\flutter\bin\flutter.bat test --reporter compact
```

Evidence after fix:

```text
target dynamic type test: passed
pro_components_test.dart: 15 tests passed
flutter analyze: No issues found
mobile_viewport_audit_test.dart: 4 tests passed
flutter test: 391 tests passed
```

- [x] **Step 5: Release smoke and residual finding**

Run:

```powershell
C:\flutter\bin\flutter.bat run --release -d emulator-5554 --no-resident
adb shell settings put system font_scale 1.6
adb shell am force-stop ru.prohelper.prohelpers_mobile
adb shell am start -n ru.prohelper.prohelpers_mobile/.MainActivity
```

Evidence:

```text
release APK: build\app\outputs\flutter-apk\app-release.apk, 21.0MB
large-font login screen captured at build\qa\prohelper_large_text_work.png
large-font auth screen stayed visually readable
cold start without input for 35 seconds: no ANR, login screen available
```

Residual reliability finding:

```text
dumpsys window lastanr:
Reason: Input dispatching timed out ... Waited 5018ms for KeyEvent
Trigger observed during aggressive adb text input / IME automation after release reinstall.
Authenticated large-font Work screen smoke was not completed because adb input was unreliable on this emulator session.
```

Expected next hardening task: investigate release-start input readiness and replace arbitrary automation sleeps with condition-based readiness checks before injecting credentials.

---

#### Task 5U: Login Keyboard Layout With Large Text

**Files:**
- Modify: `lib/features/auth/presentation/login_screen.dart`
- Modify: `test/features/auth/presentation/login_screen_test.dart`

- [x] **Step 1: Reproduce keyboard-mode brand collision**

Add a widget test for a 390x844 phone with `TextScaler.linear(1.6)` and `viewInsets.bottom = 380`.

Evidence before fix:

```text
Expected: no matching candidates
Actual: Found 1 widget with text "Industrial management"
```

Expected: when the keyboard is open, the login screen prioritizes credentials and the submit action over the full brand block.

- [x] **Step 2: Compact the login layout only while the keyboard is open**

When `MediaQuery.viewInsetsOf(context).bottom > 0`, the screen now:

```text
hides the full brand header
hides the administrator help footer
top-aligns the form instead of centering it
uses compact form padding
preserves a 52dp bottom breathing room above the keyboard
```

Expected: the normal logged-out brand presentation remains unchanged with the keyboard closed, while focused credential entry stays usable with large text and the software keyboard.

- [x] **Step 3: Add regression coverage**

Assert:

```dart
find.text('Industrial management') == findsNothing
AppPrimaryActionButton.top < keyboardTop
```

Expected: future visual refactors cannot reintroduce a large nonessential header above focused credential entry.

- [x] **Step 4: Verify code checks**

Run:

```powershell
C:\flutter\bin\flutter.bat test test\features\auth\presentation\login_screen_test.dart --plain-name "login form compacts brand area above keyboard with large text" --reporter compact
C:\flutter\bin\flutter.bat test test\features\auth\presentation\login_screen_test.dart --reporter compact
C:\flutter\bin\flutter.bat analyze
C:\flutter\bin\flutter.bat test test\features\mobile_visual\mobile_viewport_audit_test.dart --reporter compact
C:\flutter\bin\flutter.bat test --reporter compact
```

Evidence after fix:

```text
target login keyboard large-text test: passed
login_screen_test.dart: 10 tests passed
flutter analyze: No issues found
mobile_viewport_audit_test.dart: 4 tests passed
flutter test: 392 tests passed
```

- [x] **Step 5: Release smoke**

Run:

```powershell
C:\flutter\bin\flutter.bat run --release -d emulator-5554 --no-resident
adb shell settings put system font_scale 1.6
adb shell settings put secure show_ime_with_hard_keyboard 1
adb shell pm clear ru.prohelper.prohelpers_mobile
adb shell am start -n ru.prohelper.prohelpers_mobile/.MainActivity
```

Evidence:

```text
release APK: build\app\outputs\flutter-apk\app-release.apk, 21.0MB
condition-based XML wait found the Email field
focused Email field via XML bounds: TapX=540, TapY=1370
HasIndustrialManagement: False
HasEmailNode: True
FocusedEmail: True
HasButtonNode: True
BadLogMatches:
```

Artifacts:

```text
build\qa\prohelper_login_keyboard_compact_release.xml
build\qa\prohelper_login_keyboard_compact_release_cmd.png
```

Expected next hardening task: continue authenticated large-font Work/Overview smoke now that credential entry no longer wastes vertical space in keyboard mode.

---

#### Task 5V: Login Profile Authorization After Token Issue

**Files:**
- Modify: `lib/features/auth/data/auth_repository.dart`
- Modify: `test/features/auth/auth_repository_test.dart`
- Modify: `test/features/auth/auth_provider_test.dart`
- Modify: `test/helpers/mobile_integration_test_helpers.dart`

- [x] **Step 1: Reproduce the release login/profile mismatch**

Evidence before fix:

```text
Direct API login: 200, token returned
Direct API /auth/me with token: 200, profile returned
Release app after login: returned to auth screen with profile loading error
```

Expected: the mobile client should request `/auth/me` with the token received from `/auth/login` immediately after successful login.

- [x] **Step 2: Add a failing repository regression**

Extend `login success stores token and loads profile` to assert:

```dart
expect(adapter.requests[1].headers['Authorization'], 'Bearer token-1');
```

Evidence before implementation:

```text
Expected: 'Bearer token-1'
Actual: <null>
```

Expected: the second request in the login chain carries the fresh bearer token and does not depend on an immediate secure-storage read.

- [x] **Step 3: Pass the fresh token into the profile request**

After saving the login token, call:

```dart
return await getMe(token: token);
```

When a token is provided, pass it as a per-request Dio header through:

```dart
Options(headers: {'Authorization': 'Bearer $token'})
```

Expected: post-login profile loading is deterministic while normal session bootstrap still uses the existing auth interceptor and secure storage.

- [x] **Step 4: Update test doubles and verify code checks**

Run:

```powershell
C:\flutter\bin\dart.bat format lib\features\auth\data\auth_repository.dart test\features\auth\auth_repository_test.dart test\features\auth\auth_provider_test.dart test\helpers\mobile_integration_test_helpers.dart
C:\flutter\bin\flutter.bat test test\features\auth\auth_repository_test.dart --reporter compact
C:\flutter\bin\flutter.bat test test\features\auth\auth_provider_test.dart --reporter compact
C:\flutter\bin\flutter.bat test test\features\auth\presentation\login_screen_test.dart --reporter compact
C:\flutter\bin\flutter.bat analyze
C:\flutter\bin\flutter.bat test --reporter compact
```

Evidence after fix:

```text
auth_repository_test.dart: 4 tests passed
auth_provider_test.dart: 5 tests passed
login_screen_test.dart: 10 tests passed
flutter analyze: No issues found
flutter test: 392 tests passed
```

- [x] **Step 5: Verify on release APK with authenticated large text**

Run:

```powershell
C:\flutter\bin\flutter.bat run --release -d emulator-5554 --no-resident
adb shell pm clear ru.prohelper.prohelpers_mobile
adb shell monkey -p ru.prohelper.prohelpers_mobile -c android.intent.category.LAUNCHER 1
adb shell settings put system font_scale 1.6
adb shell am force-stop ru.prohelper.prohelpers_mobile
adb shell monkey -p ru.prohelper.prohelpers_mobile -c android.intent.category.LAUNCHER 1
```

Evidence after fix:

```text
release APK: build\app\outputs\flutter-apk\app-release.apk, 21.0MB
normal-font login submitted and loaded authenticated Overview
large-font restart stayed authenticated on Overview
large-font Work tab opened with selected Work tab, search, sections, and action cards visible
release logcat: no app crash, ANR, Flutter exception, or DioException found
```

Artifacts:

```text
build\qa\prohelper_release_after_login_authfix.xml
build\qa\prohelper_release_after_login_authfix.png
build\qa\prohelper_release_large_text_overview_authfix.xml
build\qa\prohelper_release_large_text_overview_authfix.png
build\qa\prohelper_release_large_text_work_authfix.xml
build\qa\prohelper_release_large_text_work_authfix.png
```

Expected: the login button remains normal, the auth flow succeeds, and large-font authenticated Overview/Work smoke is no longer blocked by token propagation.

---

#### Task 5W: Notification Status Contrast Hardening

**Files:**
- Modify: `lib/features/notifications/presentation/widgets/notification_card.dart`
- Modify: `lib/features/notifications/presentation/notification_detail_screen.dart`
- Modify: `test/features/notifications/notifications_screen_test.dart`

- [x] **Step 1: Reproduce the light-theme contrast defect**

Runtime notification audit on the Android emulator showed unread security cards using the raw orange warning color for category pills and icons.

Evidence before fix:

```text
NotificationCard high/critical/low priority chip foregrounds used AppColors.warning/error/success.
Regression test against МОСТ light surface failed:
critical contrast: 3.55:1
expected: >= 4.5:1
```

Expected: status text inside notification pills must use contrast-safe foreground tokens, not raw accent colors that are too light on white cards.

- [x] **Step 2: Add failing contrast coverage**

Add a widget test that renders `NotificationCard` for:

```text
critical
high
low
normal
```

and asserts the category pill foreground contrast against the light theme surface is at least `4.5:1`.

Expected before implementation: test fails on raw status colors.

- [x] **Step 3: Use shared status color tokens**

Map notification priority to `ProStatusTone`:

```text
critical -> danger
high -> warning
low -> success
normal -> info
```

Use `proStatusStyle(context, tone).foreground` for chip/icon foregrounds and `ProStatusStyle.background` for unread status tinting.

Expected: notification list cards and notification detail badges follow the same contrast-tested status system as the rest of the app.

- [x] **Step 4: Verify tests and analyzer**

Run:

```powershell
C:\flutter\bin\flutter.bat test test\features\notifications\notifications_screen_test.dart --plain-name "notification priority pills keep readable light-theme contrast" --reporter compact
C:\flutter\bin\flutter.bat test test\features\notifications\notifications_screen_test.dart --reporter compact
C:\flutter\bin\flutter.bat test test\features\notifications\notifications_screen_test.dart test\features\notifications\notifications_provider_test.dart test\features\notifications\notifications_repository_test.dart test\features\notifications\notification_navigation_target_test.dart --reporter compact
C:\flutter\bin\flutter.bat analyze
C:\flutter\bin\flutter.bat test --reporter compact
```

Evidence after fix:

```text
notification contrast target test: passed
notifications_screen_test.dart: 3 tests passed
notification suite: 12 tests passed
flutter analyze: No issues found
flutter test: 393 tests passed
```

- [x] **Step 5: Verify on release APK**

Run:

```powershell
C:\flutter\bin\flutter.bat run --release -d emulator-5554 --no-resident
adb shell monkey -p ru.prohelper.prohelpers_mobile -c android.intent.category.LAUNCHER 1
adb shell input tap 135 2232
adb shell input tap 1000 150
```

Evidence after fix:

```text
release APK: build\app\outputs\flutter-apk\app-release.apk, 21.0MB
Notifications screen loaded with unread security cards
category pills, shield icons, and unread dots render with darker contrast-safe warning foreground
release logcat: no app crash, ANR, Flutter exception, or DioException found
```

Artifacts:

```text
build\qa\prohelper_notification_contrast_release.png
build\qa\prohelper_notification_contrast_release.xml
```

Expected: notification cards stay visually warm/status-coded, but status labels are readable in the light theme.

---

#### Task 5X: Landscape and Tablet Viewport Regression Coverage

**Files:**
- Modify: `test/features/mobile_visual/mobile_viewport_audit_test.dart`

- [x] **Step 1: Re-check the current evidence gap**

Dark-mode and release smoke covered real Overview/Work/Actions/More/Notifications surfaces, but the attempted emulator rotation did not produce a real landscape layout: `prohelper_landscape_overview.png` and `prohelper_landscape_work.png` both remained portrait Overview captures.

Expected: landscape and wide/tablet behavior should be proven by an automated viewport check, not inferred from inconclusive emulator screenshots.

- [x] **Step 2: Add landscape and tablet viewport sizes to the shared audit**

Extend the major-screen viewport matrix from portrait-only:

```text
360x640
390x844
430x932
768x1024
```

to include:

```text
640x360
844x390
1024x768
```

Expected: the audit now covers small-phone landscape, large-phone landscape, tablet portrait, and tablet landscape for the same critical mobile screens.

- [x] **Step 3: Verify the focused viewport audit**

Run:

```powershell
C:\flutter\bin\flutter.bat test test\features\mobile_visual\mobile_viewport_audit_test.dart --reporter compact
```

Evidence after change:

```text
mobile_viewport_audit_test.dart: 7 viewport tests passed
covered sizes: 360x640, 390x844, 430x932, 640x360, 844x390, 768x1024, 1024x768
```

- [x] **Step 4: Verify global gates and restore emulator state**

Run:

```powershell
C:\flutter\bin\dart.bat format test\features\mobile_visual\mobile_viewport_audit_test.dart
C:\flutter\bin\flutter.bat analyze
C:\flutter\bin\flutter.bat test --reporter compact
adb shell settings put system user_rotation 0
adb shell settings put system accelerometer_rotation 1
adb shell cmd uimode night no
adb shell am force-stop ru.prohelper.prohelpers_mobile
adb shell monkey -p ru.prohelper.prohelpers_mobile -c android.intent.category.LAUNCHER 1
```

Evidence after change:

```text
dart format: Formatted 1 file (0 changed)
flutter analyze: No issues found
flutter test: 396 tests passed
emulator restored to light mode: Night mode: no
release smoke after restore: Overview loaded, light card hierarchy visible
release logcat: no app crash, ANR, Flutter exception, or DioException found
```

Artifacts:

```text
build\qa\prohelper_restored_light_overview.png
build\qa\prohelper_restored_light_overview.xml
```

Expected: the app has automated regression coverage for landscape/wide viewport layout errors while the local emulator is left in a clean portrait/light state for the next smoke pass.

---

#### Task 5Y: Mojibake Guard Coverage for Test Fixtures

**Files:**
- Modify: `test/core/navigation/mojibake_guard_test.dart`
- Modify: `test/features/warehouse/data/project_material_delivery_model_test.dart`

- [x] **Step 1: Reproduce the uncovered encoding defect**

The existing mojibake guard only scanned `lib`, and the guard itself stored several broken marker strings literally. A warehouse model fixture still contained broken Russian text in a test name and payload fields.

Evidence before fix:

```text
mojibake_guard_test.dart red run after expanding coverage:
test/features/warehouse/data/project_material_delivery_model_test.dart:149 broken test name
test/features/warehouse/data/project_material_delivery_model_test.dart:151 broken project name
test/features/warehouse/data/project_material_delivery_model_test.dart:154 broken material name
test/features/warehouse/data/project_material_delivery_model_test.dart:155 broken measurement unit
test/features/warehouse/data/project_material_delivery_model_test.dart:166 broken status label
test/features/warehouse/data/project_material_delivery_model_test.dart:170 broken project warehouse name
```

Expected: fixture text must stay readable Russian because test data often becomes the source for UI snapshots and regression expectations.

- [x] **Step 2: Harden the guard without literal broken strings**

Replace the literal mojibake regex with codepoint-based detection and scan both `lib` and `test`.

Expected: real broken Russian strings in app code or test fixtures fail the suite, while normal uppercase abbreviations such as `ГСМ`, `СМР`, and `СТРОЙ-ТУР` are not flagged.

- [x] **Step 3: Fix the warehouse fixture**

Replace the broken fixture strings with readable Russian:

```text
Дом 300м
Цемент М500
меш.
Принято
Склад объекта
```

Expected: the stock model test keeps the same business behavior while using readable text fixtures.

- [x] **Step 4: Verify encoding guard and suite**

Run:

```powershell
C:\flutter\bin\flutter.bat test test\core\navigation\mojibake_guard_test.dart --reporter compact
C:\flutter\bin\flutter.bat test test\features\warehouse\data\project_material_delivery_model_test.dart --reporter compact
C:\flutter\bin\dart.bat format test\core\navigation\mojibake_guard_test.dart test\features\warehouse\data\project_material_delivery_model_test.dart
C:\flutter\bin\flutter.bat analyze
C:\flutter\bin\flutter.bat test --reporter compact
```

Evidence after fix:

```text
mojibake_guard_test.dart: 1 test passed
project_material_delivery_model_test.dart: 7 tests passed
custom scan over lib/test/docs: TOTAL=0
flutter analyze: No issues found
flutter test: 396 tests passed
```

Expected: mobile code, tests, and the active plan document are protected from broken Russian mojibake markers.

---

#### Task 5Z: User-Facing Error Message Sanitizer Guard

**Files:**
- Modify: `lib/core/error/user_message.dart`
- Modify: visible error paths in auth, dashboard, modules, notifications, AI assistant, companion modules, budget estimates, procurement, workflow, quality, safety, time tracking, construction journal, machinery, production labor, site requests, and warehouse presentation/domain layers
- Add: `test/core/error/user_message_test.dart`

- [x] **Step 1: Identify direct technical error exposure**

Scan `lib/features` and `lib/core` for direct `error.toString()`, `snapshot.error.toString()`, and manual `replaceFirst('ApiException: ', '')` in user-facing presentation/domain code.

Expected: these patterns are treated as UX defects because they can show `ApiException`, `FormatException`, `payload`, `constraint`, `SQL`, `endpoint`, `null`, or Dart type errors directly in banners, sheets, detail screens, and snackbars.

- [x] **Step 2: Harden `UserMessage` as the single UI sanitizer**

`UserMessage.fromError` now:
- preserves readable business messages, including cleaned `FormatException: <business text>`;
- sanitizes `ApiException` messages as well as generic exceptions;
- replaces technical diagnostics with `Не удалось выполнить действие. Попробуйте еще раз.`;
- detects broader technical fragments such as `statusCode`, `endpoint`, `stack trace`, `undefined`, `is not a subtype`, and `TypeError`.

Expected: user-facing screens get business-safe copy without leaking backend/Dart internals.

- [x] **Step 3: Replace direct UI error outputs**

Updated high-risk visible paths to call `UserMessage.fromError(...)` instead of `error.toString()` or ad-hoc prefix removal:

```text
auth profile switch organization snackbar
dashboard/module load errors
AI assistant home/chat errors
notification list/detail/action errors
companion module detail/action errors
budget/procurement summary/detail/action errors
workflow and quality detail errors
time tracking, safety, handover, machinery, production labor provider errors
construction journal form snackbars
site request status action snackbars
warehouse tasks, execution, scan result, action sheets, custody, deliveries, balances and photo snackbars
```

Expected: visible error states and snackbars remain human-readable even when repositories throw technical exceptions.

- [x] **Step 4: Add regression guard**

Added `test/core/error/user_message_test.dart` covering:
- business message preservation;
- technical diagnostic sanitization;
- a source scan that fails if presentation/domain/core-provider code reintroduces direct `error.toString()`, `snapshot.error.toString()`, or manual `ApiException`/`FormatException` string stripping.

Expected: future UX regressions around technical error text fail in automated tests.

- [x] **Step 5: Verify**

Run:

```powershell
C:\flutter\bin\dart.bat format <changed user message files>
C:\flutter\bin\flutter.bat test test\core\error\user_message_test.dart --reporter compact
C:\flutter\bin\flutter.bat test test\core\navigation\navigation_error_message_test.dart --reporter compact
rg -n 'error\.toString\(\)|snapshot\.error\?*\.toString\(\)|replaceFirst\(' lib\features lib\core | rg 'ApiException|FormatException|error\.toString|snapshot\.error'
C:\flutter\bin\flutter.bat analyze
C:\flutter\bin\flutter.bat test --reporter compact
```

Evidence after fix:

```text
dart format: Formatted 36 files (12 changed)
user_message_test.dart: 3 tests passed
navigation_error_message_test.dart: 1 test passed
post-fix direct-error scan: only lib/core/error/user_message.dart contains the intentional cleanup implementation
flutter analyze: No issues found
flutter test: 399 tests passed
```

Expected: the app has a shared human-readable error-message boundary and automated protection against technical UI text regressions.

---

#### Task 5AA: Anchored Bottom Navigation In Light Theme

**Files:**
- Modify: `lib/core/widgets/mobile_app_shell.dart`
- Modify: `test/core/widgets/mobile_app_shell_test.dart`

- [x] **Step 1: Re-check the real light Overview shell**

Captured the authenticated Overview screen on `emulator-5554` in light portrait mode and inspected the UIAutomator hierarchy before and after scrolling.

Evidence:

```text
build\qa\overview_after_login.png
build\qa\overview_after_login.xml
build\qa\overview_scrolled_valid.png
build\qa\overview_scrolled.xml
```

Expected: the `Рабочая сводка` content is scrollable and not hidden under the bottom navigation. The more visible UX issue is that the root navigation reads as a floating white slab without enough anchoring in light mode.

- [x] **Step 2: Anchor the shell navigation**

Updated `MobileAppShell` so the `NavigationBar` is wrapped in a surface container with:
- top divider using the active theme outline color;
- upward shadow from the navigation host, not from individual tabs;
- transparent inner Material shadow/tint;
- explicit comfortable height based on `ProTouchTarget.comfortable + ProSpacing.lg`;
- theme-derived indicator color with lower light-theme opacity.

Expected: the tab bar remains recognizably Material, but is visually attached to the app chrome and no longer looks like an unbounded block floating over the canvas.

- [x] **Step 3: Add regression coverage**

Extended `test/core/widgets/mobile_app_shell_test.dart` to assert the navigation shell contract: fixed comfortable height, transparent internal shadow/tint, themed background, and host shadow.

Expected: future shell/theme changes cannot silently revert the bottom navigation to an unanchored default surface.

- [x] **Step 4: Verify**

Run:

```powershell
C:\flutter\bin\dart.bat format lib\core\widgets\mobile_app_shell.dart test\core\widgets\mobile_app_shell_test.dart
C:\flutter\bin\flutter.bat test test\core\widgets\mobile_app_shell_test.dart --reporter compact
C:\flutter\bin\flutter.bat analyze
C:\flutter\bin\flutter.bat test test\features\mobile_visual\mobile_viewport_audit_test.dart --reporter compact
C:\flutter\bin\flutter.bat test test\core\navigation\mojibake_guard_test.dart --reporter compact
C:\flutter\bin\flutter.bat install --debug -d emulator-5554
adb shell monkey -p ru.prohelper.prohelpers_mobile -c android.intent.category.LAUNCHER 1
```

Evidence after fix:

```text
dart format: Formatted 2 files (1 changed)
mobile_app_shell_test.dart: 2 tests passed
flutter analyze: No issues found
mobile_viewport_audit_test.dart: 7 tests passed
mojibake_guard_test.dart: 1 test passed
flutter install --debug: installed build\app\outputs\flutter-apk\app-debug.apk
emulator login smoke: authenticated Overview opened with the updated bottom navigation
build\qa\after_relogin_2_later.png
build\qa\after_relogin_2.xml
```

Expected: the root mobile shell keeps a clearer visual boundary in light mode and still passes navigation/accessibility/viewport checks.

---

#### Task 5AB: Compact Overview Project Context Card

**Files:**
- Modify: `lib/features/home/presentation/widgets/overview_project_header.dart`
- Modify: `test/features/home/mobile_overview_screen_test.dart`

- [x] **Step 1: Identify first-screen density issue**

The authenticated Overview screen still spent too much first-viewport height on the current project card. The card used a large in-card title and a wide `Сменить объект` action, pushing operational content lower than necessary.

Expected: the current object remains visible and actionable, but should read as operational context rather than a hero block.

- [x] **Step 2: Compact the card without losing context**

Updated `OverviewProjectHeader` to:
- keep the entire card tappable with the existing full semantic label;
- combine `Текущий объект` and organization into one caption line;
- reduce the visible project title to a compact 17sp operational heading;
- shorten the visible action from `Сменить объект` to context-clear `Сменить`;
- keep the full address in semantics while allowing visible address truncation when needed;
- preserve minimum touch target on the action pill and the whole card tap target.

Expected: the project context remains readable, but consumes less vertical space on the Overview first screen.

- [x] **Step 3: Add regression coverage**

Extended `mobile_overview_screen_test.dart` so the project header:
- keeps the long object name readable on a 390px mobile viewport;
- keeps the project title at or below 18sp;
- keeps the actual interactive header surface at or below 128dp in the test fixture;
- exposes the whole card as the `Сменить текущий объект...` semantic button;
- still passes Android tap target guidance.

Expected: future changes cannot silently reintroduce an oversized project context card or break the switch-object semantic action.

- [x] **Step 4: Verify**

Run:

```powershell
C:\flutter\bin\dart.bat format lib\features\home\presentation\widgets\overview_project_header.dart test\features\home\mobile_overview_screen_test.dart
C:\flutter\bin\flutter.bat test test\features\home\mobile_overview_screen_test.dart --plain-name "project header" --reporter compact
C:\flutter\bin\flutter.bat test test\features\home\mobile_overview_screen_test.dart --reporter compact
C:\flutter\bin\flutter.bat analyze
C:\flutter\bin\flutter.bat test test\features\mobile_visual\mobile_viewport_audit_test.dart --reporter compact
C:\flutter\bin\flutter.bat test test\core\navigation\mojibake_guard_test.dart --reporter compact
C:\flutter\bin\flutter.bat test --reporter compact
C:\flutter\bin\flutter.bat build apk --debug
adb install -r build\app\outputs\flutter-apk\app-debug.apk
adb shell monkey -p ru.prohelper.prohelpers_mobile -c android.intent.category.LAUNCHER 1
```

Evidence after fix:

```text
project header targeted tests: 2 tests passed
mobile_overview_screen_test.dart: 14 tests passed
flutter analyze: No issues found
mobile_viewport_audit_test.dart: 7 tests passed
mojibake_guard_test.dart: 1 test passed
flutter build apk --debug: Built build\app\outputs\flutter-apk\app-debug.apk
adb install -r: Success
emulator Overview smoke: authenticated Overview shows compact project card
project card UIAutomator bounds after rebuild: [42,279][1038,613]
previous observed bounds before rebuild: [42,252][1038,656]
build\qa\overview_compact_project_rebuilt_ready.png
build\qa\overview_compact_project_rebuilt_ready.xml
```

Expected: the Overview first screen is denser and more operational while preserving project switch accessibility and context.

---

#### Task 5AC: Compact Overview Notification Status Banner

**Files:**
- Modify: `lib/core/widgets/pro_status_banner.dart`
- Modify: `lib/features/home/presentation/widgets/overview_today_status.dart`
- Modify: `test/features/home/mobile_overview_screen_test.dart`

- [x] **Step 1: Identify first-screen density issue**

The notification-only `Новые уведомления` state used the same roomy status banner layout as heavier warning/error states. On the authenticated Overview first screen, this consumed too much vertical space for one unread counter and one navigation action.

Expected: notification-only status should stay visible and actionable, but read as a compact operational prompt rather than a large alert block.

- [x] **Step 2: Add compact banner layout**

Extended `ProStatusBanner` with an opt-in `compact` mode:
- smaller padding and icon extent;
- one-line title and two-line description limits;
- top-row action placement for compact actionable states;
- unchanged default layout for existing non-compact banners.

Expected: shared banner behavior remains backwards-compatible while Overview can opt into a denser layout.

- [x] **Step 3: Make notification action compact and accessible**

Updated `OverviewTodayStatus` so notification-only status:
- passes `compact: true`;
- uses an icon-only tonal action instead of a text action that wraps in narrow space;
- exposes explicit semantics `Открыть уведомления`;
- keeps the banner content separate from the top app-bar notification action.

Expected: no text wrapping in the CTA, no NAF accessibility marker, and a clear screen-reader action label.

- [x] **Step 4: Add regression coverage**

Extended `mobile_overview_screen_test.dart` so notification-only status:
- remains actionable;
- uses `ProStatusBanner.compact`;
- keeps compact text line limits;
- exposes `Открыть уведомления` as a semantic action;
- does not render the broken visible text CTA.

Expected: future changes cannot silently reintroduce the oversized text button or lose accessibility.

- [x] **Step 5: Verify**

Run:

```powershell
C:\flutter\bin\dart.bat format lib\core\widgets\pro_status_banner.dart lib\features\home\presentation\widgets\overview_today_status.dart test\features\home\mobile_overview_screen_test.dart
C:\flutter\bin\flutter.bat test test\features\home\mobile_overview_screen_test.dart --plain-name "today status" --reporter compact
C:\flutter\bin\flutter.bat test test\features\home\mobile_overview_screen_test.dart --reporter compact
C:\flutter\bin\flutter.bat test test\features\auth\presentation\login_screen_test.dart --reporter compact
C:\flutter\bin\flutter.bat analyze
C:\flutter\bin\flutter.bat test test\features\mobile_visual\mobile_viewport_audit_test.dart --reporter compact
C:\flutter\bin\flutter.bat test test\core\navigation\mojibake_guard_test.dart --reporter compact
C:\flutter\bin\flutter.bat build apk --debug
adb install -r build\app\outputs\flutter-apk\app-debug.apk
adb shell monkey -p ru.prohelper.prohelpers_mobile -c android.intent.category.LAUNCHER 1
```

Evidence after fix:

```text
login_screen_test.dart: 10 tests passed
today status targeted tests: 2 tests passed
mobile_overview_screen_test.dart: 14 tests passed
flutter analyze: No issues found
mobile_viewport_audit_test.dart: 7 tests passed
mojibake_guard_test.dart: 1 test passed
flutter build apk --debug: Built build\app\outputs\flutter-apk\app-debug.apk
adb install -r: Success
emulator Overview smoke: notification status uses compact icon action without text wrapping
UIAutomator notification status bounds: [42,665][1038,970]
UIAutomator notification action content-desc: Открыть уведомления
UIAutomator NAF marker: not present for the compact notification action
build\qa\overview_compact_status_accessible.png
build\qa\overview_compact_status_accessible.xml
```

Expected: Overview first screen is denser, notification action is clear and accessible, and the light-theme card hierarchy remains stable.

---

#### Task 5AD: Overview Notification Title Without Ellipsis

**Files:**
- Modify: `lib/features/home/presentation/widgets/overview_today_status.dart`
- Modify: `test/features/home/mobile_overview_screen_test.dart`

- [x] **Step 1: Identify emulator-only polish defect**

After Task 5AC, the compact notification card was functionally correct but the real emulator screenshot still showed the title as `Новые уведомле...` beside the icon-only action.

Expected: primary first-screen card text must not rely on ellipsis for a short operational status.

- [x] **Step 2: Tighten notification-only copy**

Changed the notification-only status title from `Новые уведомления` to `Новые события`.

Expected: the title keeps the same operational meaning, fits the compact card next to the icon action, and avoids wrapping or truncation.

- [x] **Step 3: Add regression coverage**

Updated the notification-only Overview widget test to assert:
- `Новые события` is rendered;
- old `Новые уведомления` is not rendered;
- the icon action still exposes `Открыть уведомления`;
- compact banner line limits and click behavior stay intact.

Expected: future copy or layout changes cannot silently reintroduce the truncating long title.

- [x] **Step 4: Verify**

Run:

```powershell
C:\flutter\bin\dart.bat format lib\features\home\presentation\widgets\overview_today_status.dart test\features\home\mobile_overview_screen_test.dart
C:\flutter\bin\flutter.bat test test\features\home\mobile_overview_screen_test.dart --plain-name "today status" --reporter compact
C:\flutter\bin\flutter.bat test test\features\home\mobile_overview_screen_test.dart --reporter compact
C:\flutter\bin\flutter.bat analyze
C:\flutter\bin\flutter.bat test test\features\mobile_visual\mobile_viewport_audit_test.dart --reporter compact
C:\flutter\bin\flutter.bat test test\core\navigation\mojibake_guard_test.dart --reporter compact
C:\flutter\bin\flutter.bat build apk --debug
adb install -r build\app\outputs\flutter-apk\app-debug.apk
adb shell monkey -p ru.prohelper.prohelpers_mobile -c android.intent.category.LAUNCHER 1
```

Evidence after fix:

```text
today status targeted tests: 2 tests passed
mobile_overview_screen_test.dart: 14 tests passed
flutter analyze: No issues found
mobile_viewport_audit_test.dart: 7 tests passed
mojibake_guard_test.dart: 1 test passed
flutter test: 399 tests passed
flutter build apk --debug: Built build\app\outputs\flutter-apk\app-debug.apk
adb install -r: Success
emulator Overview smoke: title renders as full `Новые события` without ellipsis
UIAutomator notification status content-desc: Новые события; Непрочитанных: 3. Проверьте обновления по объекту.
UIAutomator old title `Новые уведомления`: absent
UIAutomator notification action content-desc: Открыть уведомления
UIAutomator NAF marker: not present for the compact notification action
build\qa\overview_notification_title_no_ellipsis.png
build\qa\overview_notification_title_no_ellipsis.xml
```

Expected: the compact notification card keeps a polished first-viewport presentation with no clipped status title.

---

#### Task 5AE: Compact More Tab Project Context Card

**Files:**
- Modify: `lib/features/navigation/presentation/mobile_more_screen.dart`
- Modify: `test/features/navigation/mobile_more_screen_test.dart`

- [x] **Step 1: Identify runtime density inconsistency**

The `Ещё` tab still rendered the current project as a large hero-style status block with a wide `Сменить объект` button. This duplicated the pre-hardening Overview problem and pushed the `Помощь` and `Управление` cards lower than necessary.

Expected: the current object should remain visible and actionable, but use the same compact operational-context treatment as the hardened Overview card.

- [x] **Step 2: Replace the oversized status block**

Added a private compact `_MoreProjectContextCard` that:
- uses `ProSurface` with elevated card tone;
- makes the entire project card tappable;
- exposes one semantic button with the full object name and address;
- uses a short visible `Сменить` / `Выбрать` action pill;
- limits title and address lines to keep first-viewport density stable;
- avoids nested button semantics inside the card.

Expected: the More tab no longer shows a separate large action button, and the project context card consumes less vertical space.

- [x] **Step 3: Add regression coverage**

Extended `mobile_more_screen_test.dart` to assert:
- the visible action is `Сменить`, not `Сменить объект`;
- the full card exposes `Сменить текущий объект...` semantics;
- the card stays at or below 132dp in the phone fixture;
- Android tap target guidance still passes;
- tapping the compact card opens project selection without clearing the selected project.

Expected: future changes cannot silently return the old oversized project block or break the selection flow.

- [x] **Step 4: Verify**

Run:

```powershell
C:\flutter\bin\dart.bat format lib\features\navigation\presentation\mobile_more_screen.dart test\features\navigation\mobile_more_screen_test.dart
C:\flutter\bin\flutter.bat test test\features\navigation\mobile_more_screen_test.dart --reporter compact
C:\flutter\bin\flutter.bat analyze
C:\flutter\bin\flutter.bat test test\features\mobile_visual\mobile_viewport_audit_test.dart --reporter compact
C:\flutter\bin\flutter.bat test test\core\navigation\mojibake_guard_test.dart --reporter compact
C:\flutter\bin\flutter.bat build apk --debug
adb install -r build\app\outputs\flutter-apk\app-debug.apk
adb shell monkey -p ru.prohelper.prohelpers_mobile -c android.intent.category.LAUNCHER 1
C:\flutter\bin\flutter.bat test --reporter compact
```

Evidence after fix:

```text
mobile_more_screen_test.dart: 8 tests passed
flutter analyze: No issues found
mobile_viewport_audit_test.dart: 7 tests passed
mojibake_guard_test.dart: 1 test passed
flutter build apk --debug: Built build\app\outputs\flutter-apk\app-debug.apk
adb install -r: Success
emulator More smoke: compact project card visible and old `Сменить объект` button absent
UIAutomator project card bounds after fix: [42,531][1038,794]
previous observed project card bounds before fix: [42,531][1038,959]
UIAutomator project card content-desc: Сменить текущий объект: Строительство склада Литер А. Адрес: 420054, Респ Татарстан, г Казань, Приволжский р-н, ул 2-я Гаражная, д 4
UIAutomator old `Сменить объект` node: absent
flutter test: 400 tests passed
build\qa\more_project_compact_ready.png
build\qa\more_project_compact_ready.xml
```

Expected: the More tab aligns with the hardened light-theme hierarchy and shows more useful management content in the first viewport.

---

#### Task 5AF: Separate Workflow Search and Filter Semantics

**Files:**
- Modify: `lib/features/workflow_management/presentation/workflow_management_screen.dart`
- Modify: `test/features/workflow_management/presentation/workflow_management_screen_test.dart`

- [x] **Step 1: Identify runtime semantics regression**

The real emulator walkthrough of `Согласования` showed the search/filter panel as one large native `EditText` node with the filter chips nested inside it. Bounds before the fix:

```text
EditText bounds before fix: [42,462][1038,929]
Nested filter chip bounds inside EditText: [76,664][270,769], [291,664][476,769], ...
```

Expected: the search input must be announced as the search input only; filter chips must be separate tappable controls below it.

- [x] **Step 2: Split semantic containers**

Converted `_WorkflowFilterPanel` to a stateful widget with:
- explicit semantic boundaries for the panel;
- a dedicated semantic text field labelled `Поиск по согласованиям`;
- a dedicated `Фильтры согласований` semantic group for chips;
- a separate accessible `Очистить поиск` button when the search field has text.

Expected: TalkBack/UIAutomator no longer treats filter chips as children of the search field.

- [x] **Step 3: Add regression coverage**

Added `keeps workflow search semantics separate from filter chips` to assert:
- the search text field exposes `Поиск по согласованиям`;
- the filter group exposes `Фильтры согласований`;
- no text-field semantics node has filter-chip labels as descendants.

Expected: future refactors cannot silently merge workflow filters back into the search field.

- [x] **Step 4: Verify**

Run:

```powershell
C:\flutter\bin\dart.bat format lib\features\workflow_management\presentation\workflow_management_screen.dart test\features\workflow_management\presentation\workflow_management_screen_test.dart
C:\flutter\bin\flutter.bat test test\features\workflow_management\presentation\workflow_management_screen_test.dart --reporter compact
C:\flutter\bin\flutter.bat analyze
C:\flutter\bin\flutter.bat build apk --debug
adb install -r build\app\outputs\flutter-apk\app-debug.apk
adb shell monkey -p ru.prohelper.prohelpers_mobile -c android.intent.category.LAUNCHER 1
C:\flutter\bin\flutter.bat test test\features\mobile_visual\mobile_viewport_audit_test.dart --reporter compact
C:\flutter\bin\flutter.bat test test\core\navigation\mojibake_guard_test.dart --reporter compact
C:\flutter\bin\flutter.bat test --reporter compact
```

Evidence after fix:

```text
workflow_management_screen_test.dart: 6 tests passed
flutter analyze: No issues found
flutter build apk --debug: Built build\app\outputs\flutter-apk\app-debug.apk
adb install -r: Success
mobile_viewport_audit_test.dart: 7 tests passed
mojibake_guard_test.dart: 1 test passed
flutter test: 401 tests passed
emulator Workflow smoke: filter chips are sibling controls below the search node
UIAutomator search node bounds after fix: [76,496][1004,633]
UIAutomator filter group bounds after fix: [76,664][1003,895]
build\qa\workflow_semantics_final_ready.png
build\qa\workflow_semantics_final_ready.xml
```

Note: Android UIAutomator still marks the empty `EditText` as `NAF=true` because it ignores Flutter's hint-only text-field label. This is the same known hint-only `EditText` limitation documented during login semantics hardening; the fixed issue here is the incorrect nesting of filter buttons inside the text field.

Expected: the `Согласования` filter panel has a cleaner accessibility tree without changing the visual layout.

---

#### Task 5AG: Split Notification Card and Action Button Semantics

**Files:**
- Modify: `lib/features/notifications/presentation/widgets/notification_card.dart`
- Modify: `lib/features/notifications/presentation/notifications_screen.dart`
- Modify: `test/features/notifications/notifications_screen_test.dart`

- [x] **Step 1: Confirm runtime nested-button defect**

The real emulator XML for `Уведомления` showed each unread notification as one large native `android.widget.Button` with a nested child `android.widget.Button` for `Отметить прочитанным`.

Example before the fix:

```text
Notification card button bounds: [42,410][1038,979]
Nested mark-read button bounds: [85,810][650,936]
```

Expected: the card content should not be exposed as the same button that contains inline actions.

- [x] **Step 2: Make notification actions explicit siblings**

Changed `NotificationCard` so the card is a static content surface. The actions are now explicit sibling buttons:
- `Открыть`
- `Отметить прочитанным` for unread notifications

This preserves navigation to notification detail while removing the ambiguous "button inside button" interaction model.

- [x] **Step 3: Clean up mark-all semantics**

The app-bar `Отметить все` action had the same nested semantics pattern: a custom `Semantics(button: true)` wrapper around a `TextButton`. Replaced the child semantics with a single accessible node labelled `Отметить все уведомления прочитанными`.

Expected: TalkBack/UIAutomator sees one mark-all button, not a focusable parent button with a nested child button.

- [x] **Step 4: Add regression coverage**

Added widget coverage to assert:
- no button node contains both a notification title and `Отметить прочитанным`;
- the `Открыть` action still invokes the open callback;
- the mark-all action keeps a single semantic button node while preserving visible text.

- [x] **Step 5: Verify**

Run:

```powershell
C:\flutter\bin\dart.bat format lib\features\notifications\presentation\widgets\notification_card.dart lib\features\notifications\presentation\notifications_screen.dart test\features\notifications\notifications_screen_test.dart
C:\flutter\bin\flutter.bat test test\features\notifications\notifications_screen_test.dart --reporter compact
C:\flutter\bin\flutter.bat analyze
C:\flutter\bin\flutter.bat test --reporter compact
C:\flutter\bin\flutter.bat build apk --debug
adb install -r build\app\outputs\flutter-apk\app-debug.apk
adb shell monkey -p ru.prohelper.prohelpers_mobile -c android.intent.category.LAUNCHER 1
```

Evidence after fix:

```text
notifications_screen_test.dart: 5 tests passed
flutter analyze: No issues found
flutter test: 403 tests passed
flutter build apk --debug: Built build\app\outputs\flutter-apk\app-debug.apk
adb install -r: Success
emulator login: succeeded using exact keyevent input after direct API credential check
final mark-all node: android.widget.Button content-desc="Отметить все уведомления прочитанными", no child button
final notification card node: android.view.View clickable=false
final card action nodes: sibling android.widget.Button content-desc="Открыть" and "Отметить прочитанным"
build\qa\notifications_final_card_actions.png
build\qa\notifications_final_card_actions.xml
```

Expected: the notification screen keeps visible actions while removing nested button ambiguity from both the app bar action and unread notification cards.

---

#### Task 5AH: Hide Dead Notification Detail Target Action

**Files:**
- Modify: `lib/features/notifications/presentation/notification_detail_screen.dart`
- Add: `test/features/notifications/notification_detail_screen_test.dart`

- [x] **Step 1: Confirm contradictory detail action**

The real emulator flow from `Уведомления` into a security-login notification detail showed:

```text
Действие
Для этого уведомления нет прямого перехода.
Открыть связанный раздел
```

Expected: a detail screen must not show an active action when the same block says there is no direct target.

- [x] **Step 2: Hide the action for unknown targets**

Changed `_NotificationDetailContent` to compute the navigation target and render `Открыть связанный раздел` only when the target type is not `NotificationTargetType.unknown`.

Expected: unknown notifications keep the explanatory text only; notifications with concrete or fallback module targets still keep the open action.

- [x] **Step 3: Add regression coverage**

Added widget coverage for:
- unknown notification: shows `Для этого уведомления нет прямого перехода.` and hides `Открыть связанный раздел`;
- site-request notification: shows `Откроется карточка заявки.` and keeps `Открыть связанный раздел`.

- [x] **Step 4: Verify**

Run:

```powershell
C:\flutter\bin\dart.bat format lib\features\notifications\presentation\notification_detail_screen.dart test\features\notifications\notification_detail_screen_test.dart
C:\flutter\bin\flutter.bat test test\features\notifications\notification_detail_screen_test.dart --reporter compact
C:\flutter\bin\flutter.bat test test\features\notifications --reporter compact
C:\flutter\bin\flutter.bat analyze
C:\flutter\bin\flutter.bat test --reporter compact
C:\flutter\bin\flutter.bat build apk --debug
adb install -r build\app\outputs\flutter-apk\app-debug.apk
adb shell monkey -p ru.prohelper.prohelpers_mobile -c android.intent.category.LAUNCHER 1
```

Evidence after fix:

```text
notification_detail_screen_test.dart: 2 tests passed
test\features\notifications: 16 tests passed
flutter analyze: No issues found
flutter test: 405 tests passed
flutter build apk --debug: Built build\app\outputs\flutter-apk\app-debug.apk
adb install -r: Success
runtime detail XML: contains "Действие\nДля этого уведомления нет прямого перехода."
runtime detail XML: does not contain "Открыть связанный раздел" for the unknown security-login notification
build\qa\notification_detail_no_target_fixed2.png
build\qa\notification_detail_no_target_fixed2.xml
```

Expected: notification detail screens no longer invite users into a dead navigation path.

---

#### Task 5AI: Compact Notification Detail Title

**Files:**
- Modify: `lib/features/notifications/presentation/notification_detail_screen.dart`
- Modify: `test/features/notifications/notification_detail_screen_test.dart`

- [x] **Step 1: Confirm oversized detail heading**

The real emulator screenshot for a security-login notification detail showed the notification title rendered at the same hero scale used for top-level page headings. Inside a detail card this made the screen feel visually heavy and reduced the balance between title, status badges, and message body.

Expected: notification detail cards should use a strong but compact title style, not the global `h1` hero style.

- [x] **Step 2: Apply a detail-specific title style**

Changed the notification detail title to:
- use the `h2` scale as the base;
- render at 22px with `FontWeight.w800`;
- keep a tight `1.15` line height;
- cap long titles at 3 lines with ellipsis.

Expected: long notification titles remain readable without turning the card into a hero block.

- [x] **Step 3: Add regression coverage**

Added widget coverage that renders a long notification title and asserts:
- the title font size is smaller than `AppTypography.h1`;
- `maxLines` is `3`;
- overflow uses `TextOverflow.ellipsis`.

Expected: future detail-screen changes cannot silently restore the oversized heading.

- [x] **Step 4: Verify**

Run:

```powershell
C:\flutter\bin\dart.bat format lib\features\notifications\presentation\notification_detail_screen.dart test\features\notifications\notification_detail_screen_test.dart
C:\flutter\bin\flutter.bat test test\features\notifications\notification_detail_screen_test.dart --reporter compact
C:\flutter\bin\flutter.bat test test\features\notifications --reporter compact
```

Evidence after fix:

```text
notification_detail_screen_test.dart: 3 tests passed
test\features\notifications: 17 tests passed
flutter analyze: No issues found
flutter test: 406 tests passed
flutter build apk --debug: Built build\app\outputs\flutter-apk\app-debug.apk
adb install -r: Success
runtime detail XML: top card bounds reduced from [42,252][1038,774] to [42,252][1038,735]
runtime detail XML: still does not contain the dead target action for the unknown security-login notification
build\qa\notification_detail_compact_title.png
build\qa\notification_detail_compact_title.xml
```

Expected: the notification detail screen keeps a calmer operational hierarchy while preserving the dead-target fix and direct-target action behavior.

---

#### Task 5AJ: Compact Workflow List Secondary Actions

**Files:**
- Modify: `lib/features/workflow_management/presentation/workflow_management_screen.dart`
- Modify: `test/features/workflow_management/presentation/workflow_management_screen_test.dart`

- [x] **Step 1: Confirm oversized workflow card actions**

The real emulator walkthrough of `Работа -> Процессы -> Согласования` showed the first approval card occupying most of the viewport because five CTA buttons were rendered directly on the list card:

```text
Подробнее
Согласовать
Отклонить
Изменения
Комментарий
```

Expected: a workflow list should support scanning multiple approvals; secondary actions must not turn each list item into a full detail screen.

- [x] **Step 2: Keep primary actions visible and move secondary actions behind `Ещё`**

Changed `_WorkflowTaskCard` so the list keeps:
- `Подробнее`
- `Согласовать`
- `Отклонить`
- `Ещё`

The `Ещё` button opens a bottom sheet with:
- `Запросить изменения`
- `Комментарий`

The full detail screen still keeps all workflow actions visible.

Expected: the list card is more compact without removing any available action from the workflow.

- [x] **Step 3: Add regression coverage**

Updated workflow widget coverage to assert:
- `Комментарий` and `Запросить изменения` are not visible as direct list-card CTAs;
- `Ещё` opens `Дополнительные действия`;
- the bottom sheet exposes `Запросить изменения` and `Комментарий`;
- request-changes submission still works from the compact secondary-action path;
- the detail screen still exposes its refresh action and full workflow context.

The test also caught and fixed a bottom-sheet lifecycle bug by using the sheet builder context for themed typography.

- [x] **Step 4: Verify**

Run:

```powershell
C:\flutter\bin\dart.bat format lib\features\workflow_management\presentation\workflow_management_screen.dart test\features\workflow_management\presentation\workflow_management_screen_test.dart
C:\flutter\bin\flutter.bat test test\features\workflow_management\presentation\workflow_management_screen_test.dart --reporter compact
C:\flutter\bin\flutter.bat analyze
C:\flutter\bin\flutter.bat test --reporter compact
C:\flutter\bin\flutter.bat build apk --debug
adb install -r build\app\outputs\flutter-apk\app-debug.apk
```

Evidence so far:

```text
workflow_management_screen_test.dart: 6 tests passed
flutter analyze: No issues found
flutter test: 406 tests passed
flutter build apk --debug: Built build\app\outputs\flutter-apk\app-debug.apk
adb install -r: Success
runtime list XML: first card bounds [42,961][1038,1785]
runtime list XML: second card starts at [42,1785][1038,2337]
runtime list XML: direct first-card buttons are Подробнее, Согласовать, Отклонить, Ещё
runtime bottom sheet XML: Запросить изменения [42,2001][1038,2148], Комментарий [42,2148][1038,2295]
build\qa\after_5aj_workflow_list.png
build\qa\after_5aj_workflow_list.xml
build\qa\after_5aj_workflow_more_sheet.png
build\qa\after_5aj_workflow_more_sheet.xml
```

Expected: analyzer, full suite, debug build/install, and emulator smoke confirm the compact workflow list.

---

#### Task 5AK: Project Selection Refresh Accessibility Label

**Files:**
- Modify: `lib/features/projects/presentation/project_selection_screen.dart`
- Modify: `test/features/projects/presentation/project_selection_screen_test.dart`

- [x] **Step 1: Confirm unlabeled refresh action**

The real emulator walkthrough of `Ещё -> профиль -> Сменить объект` showed one icon-only `android.widget.Button` with empty text and empty `content-desc` in the Android accessibility tree. The neighboring close action was labelled `Вернуться к обзору`, so the unlabeled control was the refresh action.

Expected: icon-only refresh controls must expose a stable Russian accessible name.

- [x] **Step 2: Add explicit icon semantics**

Set the refresh `Icon` semantic label to:

```dart
Обновить список объектов
```

The existing tooltip keeps the same text.

Expected: TalkBack/UIAutomator can announce the refresh action without relying on Flutter tooltip behavior.

- [x] **Step 3: Add regression coverage**

Added project-selection widget coverage that asserts:
- the refresh icon semantic label is `Обновить список объектов`;
- the `IconButton` tooltip remains `Обновить список объектов`.

- [x] **Step 4: Verify**

Run:

```powershell
C:\flutter\bin\dart.bat format lib\features\projects\presentation\project_selection_screen.dart test\features\projects\presentation\project_selection_screen_test.dart
C:\flutter\bin\flutter.bat test test\features\projects\presentation\project_selection_screen_test.dart --reporter compact
C:\flutter\bin\flutter.bat analyze
C:\flutter\bin\flutter.bat test --reporter compact
C:\flutter\bin\flutter.bat build apk --debug
adb install -r build\app\outputs\flutter-apk\app-debug.apk
```

Evidence so far:

```text
project_selection_screen_test.dart: 7 tests passed
flutter analyze: No issues found
flutter test: 407 tests passed
flutter build apk --debug: Built build\app\outputs\flutter-apk\app-debug.apk
adb install -r: Success
runtime project selection XML: refresh button content-desc="Обновить список объектов"
runtime project selection XML: no unnamed refresh button remains
build\qa\after_5ak_project_selection_verify.png
build\qa\after_5ak_project_selection_verify.xml
```

Expected: analyzer, full suite, debug build/install, and emulator smoke confirm no unlabeled refresh button remains.

---

#### Task 5AL: Overview Dashboard Error Resilience

**Files:**
- Modify: `lib/features/dashboard/presentation/controllers/dashboard_controller.dart`
- Modify: `lib/features/home/presentation/widgets/overview_today_status.dart`
- Modify: `lib/main.dart`
- Add: `test/features/dashboard/domain/dashboard_controller_test.dart`
- Modify: `test/features/home/mobile_overview_screen_test.dart`
- Backend modify: `../prohelper/app/Services/Mobile/MobileDashboardService.php`
- Backend modify: `../prohelper/tests/Feature/Api/V1/Mobile/MobileDashboardTest.php`

- [x] **Step 1: Confirm the reported runtime failure**

The emulator screenshot showed a large Overview error card:

```text
Не удалось обновить состояние объекта
Проверьте подключение и повторите попытку.
```

Direct production API diagnostics with the test account confirmed:

```text
POST /api/v1/mobile/auth/login: success
GET /api/v1/mobile/dashboard: 200
widgets_count=2
widget slugs=project_overview, workforce_management
```

Read-only production log inspection found no matching `mobile.dashboard.index.error` entries for this flow.

- [x] **Step 2: Prevent one dashboard widget from breaking the whole endpoint**

Changed `MobileDashboardService` so each widget is appended independently. A failing widget/access check is logged as `mobile.dashboard.widget_unavailable`, added to `meta.unavailable_widgets`, and the endpoint still returns the remaining widgets with `meta.partial=true`.

Expected: a single broken optional widget no longer turns `/mobile/dashboard` into a full-screen client failure.

- [x] **Step 3: Preserve last good dashboard data on refresh failure**

Changed `DashboardController.loadDashboard()` so a refresh exception keeps existing widgets and exposes an error only when there is no cached dashboard data yet.

Expected: Overview does not replace valid content with a large error card after a transient refresh failure.

- [x] **Step 4: Make the initial Overview fallback compact**

Changed `OverviewTodayStatus` initial error state to a compact elevated status banner:

```text
Сводка недоступна
```

Expected: if the app truly has no dashboard data yet, the failure is visible but does not dominate the main screen.

- [x] **Step 5: Start auth verification without waiting for post-frame**

Changed `MostApp` to start `checkAuth()` directly from `initState()` via `unawaited(...)`.

Runtime evidence after the change:

```text
Displayed ru.prohelper.prohelpers_mobile/.MainActivity: +39s174ms
/auth/me request: 0.5s after first Flutter frame
/auth/me response: success
/projects response: success
/dashboard response: success
```

The remaining `+39s` cold debug launch is a separate startup-performance issue, not the dashboard error.

- [x] **Step 6: Verify**

Run:

```powershell
C:\flutter\bin\dart.bat format lib\features\dashboard\presentation\controllers\dashboard_controller.dart lib\features\home\presentation\widgets\overview_today_status.dart lib\main.dart test\features\dashboard\domain\dashboard_controller_test.dart test\features\home\mobile_overview_screen_test.dart
C:\flutter\bin\flutter.bat test test\features\dashboard\domain\dashboard_controller_test.dart test\features\home\mobile_overview_screen_test.dart --reporter compact
C:\flutter\bin\flutter.bat test test\widget_test.dart test\features\auth\auth_provider_test.dart --reporter compact
C:\flutter\bin\flutter.bat analyze
C:\flutter\bin\flutter.bat test --reporter compact
C:\flutter\bin\flutter.bat build apk --debug
adb install -r build\app\outputs\flutter-apk\app-debug.apk
```

Backend verification:

```powershell
php -l app\Services\Mobile\MobileDashboardService.php
php -l tests\Feature\Api\V1\Mobile\MobileDashboardTest.php
php -d memory_limit=1G vendor\bin\phpstan analyse app\Services\Mobile\MobileDashboardService.php --no-progress
```

Evidence after fix:

```text
targeted dashboard/home tests: 16 tests passed
targeted widget/auth tests: 7 tests passed
flutter analyze: No issues found
flutter test: 412 tests passed
flutter build apk --debug: Built build\app\outputs\flutter-apk\app-debug.apk
adb install -r: Success
git diff --check: no whitespace errors in mobile/backend
php -l: no syntax errors
phpstan MobileDashboardService.php: No errors
runtime Overview screenshot: loaded Overview with project card, notification status, actions, and work summary; no "Не удалось обновить состояние объекта" card
runtime log: /auth/me, /projects, /dashboard, /modules, and notification requests returned responses; no Flutter fatal/dashboard exception in the filtered log
```

PHPUnit for the backend feature test was not run locally because project rules prohibit local DB-opening commands unless explicitly requested.

Expected: Overview remains usable through transient dashboard refresh failures, and backend dashboard composition is isolated per widget.

---

#### Task 5AM: Android Startup Splash Polish

**Files:**
- Modify: `android/app/src/main/kotlin/ru/prohelper/prohelpers_mobile/MainActivity.kt`
- Modify: `android/app/src/main/res/drawable/launch_background.xml`
- Modify: `android/app/src/main/res/drawable-v21/launch_background.xml`
- Add: `android/app/src/main/res/values/colors.xml`
- Add: `android/app/src/main/res/values-night/colors.xml`
- Add: `android/app/src/main/res/values-v31/styles.xml`
- Add: `android/app/src/main/res/values-night-v31/styles.xml`
- Modify: `test/android/android_manifest_startup_test.dart`

- [x] **Step 1: Measure the startup problem**

Profile/release timing showed that the very long first launch is dominated by debug/profile/post-install and emulator overhead, not by auth, dashboard, or API calls:

```text
profile first launch after install: WaitTime 19006ms, later Displayed +23s314ms
profile repeat cold launch: TotalTime 7809ms, WaitTime 7962ms
release first launch after install: TotalTime 13957ms, WaitTime 14040ms
release repeat cold launch: TotalTime 2868ms, WaitTime 2881ms
```

Expected: treat the remaining long debug first launch as a startup perception issue, not as the reported dashboard error.

- [x] **Step 2: Replace the blank native launch window with branded resources**

Changed Android launch resources to use:

```text
@color/most_splash_background
@mipmap/ic_launcher
```

Added light/dark splash colors and Android 12+ `windowSplashScreen*` resources for both normal and night `v31` configurations.

Expected: slow first launches show a branded МОСТ launch surface instead of a blank system-colored window.

- [x] **Step 3: Remove Android 12 splash exit animation**

Changed `MainActivity` to remove the native splash view immediately on Android 12+ exit:

```kotlin
splashScreen.setOnExitAnimationListener { splashScreenView ->
    splashScreenView.remove()
}
```

Expected: no extra native splash fade is added after Flutter draws the first frame.

- [x] **Step 4: Add static regression coverage**

Added `test/android/android_manifest_startup_test.dart` coverage for:

```text
Impeller remains explicitly disabled
MainActivity removes Android 12 splash exit animation
launch backgrounds use branded splash color and launcher icon
Android 12+ light/night styles define windowSplashScreenBackground and windowSplashScreenAnimatedIcon
```

Expected: future Android resource changes cannot silently return the app to a blank startup window or a missing splash asset.

- [x] **Step 5: Verify build, tests, and emulator**

Run:

```powershell
C:\flutter\bin\dart.bat format test\android\android_manifest_startup_test.dart
C:\flutter\bin\flutter.bat test test\android\android_manifest_startup_test.dart --reporter compact
C:\flutter\bin\flutter.bat analyze
C:\flutter\bin\flutter.bat test --reporter compact
C:\flutter\bin\flutter.bat build apk --debug
adb -s emulator-5554 install -r build\app\outputs\flutter-apk\app-debug.apk
adb -s emulator-5554 shell am start -W ru.prohelper.prohelpers_mobile/.MainActivity
```

Evidence after fix:

```text
android_manifest_startup_test.dart: 2 tests passed
flutter analyze: No issues found
flutter test: 413 tests passed
flutter build apk --debug: Built build\app\outputs\flutter-apk\app-debug.apk
adb install -r: Success
debug first launch after install: Status timeout, WaitTime 19314ms, no AndroidRuntime/FATAL/FlutterError
authenticated runtime smoke: Overview opened with project card, notifications, next actions, and work summary
runtime screenshot: build\qa\debug_after_successful_login_startup_fix.png
runtime log: no AndroidRuntime, FATAL EXCEPTION, FlutterError, Unhandled Exception, DioException, login error, or "Не удалось обновить состояние объекта" matches after successful login
git diff --check: no whitespace errors in mobile/backend; mobile reported only existing LF/CRLF conversion warnings
```

Expected: the application starts to a branded native surface, reaches the authenticated Overview, and does not show the reported dashboard update error.

---

#### Task 5AN: Knowledge Hub Search Accessibility Boundaries

**Files:**
- Modify: `lib/features/knowledge_hub/presentation/knowledge_hub_screen.dart`
- Modify: `test/features/knowledge_hub/presentation/knowledge_hub_screen_test.dart`

- [x] **Step 1: Reproduce the semantic merge defect**

The runtime Android UIAutomator dump for:

```text
Ещё -> База знаний
```

showed the whole search panel as one oversized `android.widget.EditText`:

```text
EditText bounds [42,279][1038,754]
nested search button bounds [698,576][996,712]
```

Expected: a text input must not own the separate `Искать` button in the accessibility tree.

- [x] **Step 2: Add regression coverage**

Added widget coverage that asserts:
- there is exactly one search text-field semantics node;
- the search action is available as `Искать по базе знаний`;
- no search button is nested inside the text-field semantics subtree.

Expected: future layout changes fail tests if the search field and action collapse into one accessibility node again.

- [x] **Step 3: Split the semantic containers**

Wrapped the search panel, text field, and search button in explicit `Semantics` boundaries. The search button now exposes:

```text
Искать по базе знаний
```

The visible UI remains unchanged.

- [x] **Step 4: Verify**

Run:

```powershell
C:\flutter\bin\dart.bat format lib\features\knowledge_hub\presentation\knowledge_hub_screen.dart test\features\knowledge_hub\presentation\knowledge_hub_screen_test.dart
C:\flutter\bin\flutter.bat test test\features\knowledge_hub\presentation\knowledge_hub_screen_test.dart --reporter compact
C:\flutter\bin\flutter.bat test test\features\knowledge_hub --reporter compact
C:\flutter\bin\flutter.bat analyze
C:\flutter\bin\flutter.bat test --reporter compact
C:\flutter\bin\flutter.bat build apk --debug
adb install -r build\app\outputs\flutter-apk\app-debug.apk
```

Evidence after fix:

```text
knowledge_hub_screen_test.dart: 4 tests passed
test/features/knowledge_hub: 9 tests passed
flutter analyze: No issues found
flutter test: 414 tests passed
flutter build apk --debug: Built build\app\outputs\flutter-apk\app-debug.apk
adb install -r: Success
runtime Knowledge Hub XML: EditText hint="Поиск по статьям, модулям и действиям" bounds [84,408][996,544]
runtime Knowledge Hub XML: Button content-desc="Искать по базе знаний" bounds [698,576][996,712]
runtime screenshots/XML: build\qa\audit_5an_knowledge.png, build\qa\audit_5an_knowledge_fixed2.png
```

Expected: the Knowledge Hub search field and search action are separate, touchable, and readable for Android accessibility tools.

---

#### Task 5AO: Workflow Card Action Semantic Context

**Files:**
- Modify: `lib/features/workflow_management/presentation/workflow_management_screen.dart`
- Modify: `test/features/workflow_management/presentation/workflow_management_screen_test.dart`

- [x] **Step 1: Reproduce the defect in runtime audit**

Fresh emulator audit after Task 5AN covered:

```text
Knowledge Hub
Overview
Work
Actions
More
Notifications
Project selection
Workflow list/detail
Self-attendance entry screen
```

The workflow list loaded real data and exposed card actions in Android UIAutomator as generic repeated labels:

```text
content-desc="Подробнее"
content-desc="Согласовать"
content-desc="Отклонить"
content-desc="Ещё"
```

Expected: repeated workflow card actions must include the task context, otherwise screen-reader users cannot tell which approval item the action will affect.

- [x] **Step 2: Add regression coverage and verify RED**

Extended `workflow_management_screen_test.dart` to assert contextual semantic labels for the list card:

```text
Открыть согласование: Бетонирование, задача 17
Согласовать: Бетонирование, задача 17
Отклонить: Бетонирование, задача 17
Показать дополнительные действия: Бетонирование, задача 17
```

RED evidence:

```text
flutter test test\features\workflow_management\presentation\workflow_management_screen_test.dart --reporter compact
Expected: exactly one matching candidate
Actual: Found 0 widgets
```

- [x] **Step 3: Add contextual semantics without changing visible UI**

Added `_WorkflowCardActionButton`, which keeps the existing visible button text and wraps the action with:

```dart
Semantics(
  button: true,
  enabled: true,
  excludeSemantics: true,
  label: contextualLabel,
  onTap: onTap,
  child: child,
)
```

Expected: the visual card remains unchanged, while Android accessibility tools expose the task-aware action name.

- [x] **Step 4: Verify**

Run:

```powershell
C:\flutter\bin\dart.bat format lib\features\workflow_management\presentation\workflow_management_screen.dart test\features\workflow_management\presentation\workflow_management_screen_test.dart
C:\flutter\bin\flutter.bat test test\features\workflow_management\presentation\workflow_management_screen_test.dart --reporter compact
C:\flutter\bin\flutter.bat test test\features\workflow_management --reporter compact
C:\flutter\bin\flutter.bat analyze
C:\flutter\bin\flutter.bat test --reporter compact
C:\flutter\bin\flutter.bat build apk --debug
adb -s emulator-5554 install -r build\app\outputs\flutter-apk\app-debug.apk
```

Evidence after fix:

```text
workflow_management_screen_test.dart: 6 tests passed
test/features/workflow_management: 15 tests passed
flutter analyze: No issues found
flutter test: 414 tests passed
flutter build apk --debug: Built build\app\outputs\flutter-apk\app-debug.apk
adb install -r: Success
runtime workflow XML: content-desc="Открыть согласование: Выполненная работа #1419, задача 1419"
runtime workflow XML: content-desc="Согласовать: Выполненная работа #1419, задача 1419"
runtime workflow XML: content-desc="Отклонить: Выполненная работа #1419, задача 1419"
runtime workflow XML: content-desc="Показать дополнительные действия: Выполненная работа #1419, задача 1419"
runtime workflow XML: no standalone content-desc="Подробнее" or content-desc="Ещё" action remained
runtime screenshots/XML: build\qa\audit_5ao_workflow_fixed_loaded.png, build\qa\audit_5ao_workflow_fixed_loaded.xml
```

Residual audit note:

```text
Work, Actions, and Workflow search fields still appear as hint-only EditText NAF nodes in UIAutomator. They are separate from filter/action controls, but Android does not expose a content-desc for the input itself. Treat as a future accessibility hardening candidate.
```

Expected: workflow card actions are distinguishable in screen readers and automation trees without changing the visible compact B2B layout.

---

#### Task 5AP: Notification Card Action Semantic Context

**Files:**
- Modify: `lib/features/notifications/presentation/widgets/notification_card.dart`
- Modify: `test/features/notifications/notifications_screen_test.dart`

- [x] **Step 1: Reproduce the defect in runtime audit**

Fresh emulator audit after Task 5AO checked the residual search-field NAF candidate and the Notifications screen.

The search-field audit confirmed the known Android UIAutomator limitation for empty Flutter `EditText` nodes: workflow search exposed `hint="Поиск по согласованиям"` and remained separate from filters, but Android still marked the empty field as `NAF=true`. This was not selected as the next fix because the field already has Flutter semantics and the native XML issue is hint-only mapping, not a missing user label.

The real Notifications screen exposed a stronger actionable defect: repeated notification cards rendered the inline open action as a generic label:

```text
content-desc="Открыть"
content-desc="Открыть"
content-desc="Открыть"
```

Runtime evidence before the fix:

```text
build\qa\audit_5ap_notifications_before.png
build\qa\audit_5ap_notifications_before.xml
```

Expected: repeated notification-card actions must identify which notification will be opened.

- [x] **Step 2: Add regression coverage and verify RED**

Extended `notifications_screen_test.dart` to assert contextual semantic labels:

```text
Открыть уведомление: Вход с нового устройства, 02.07.2026 08:45
Отметить уведомление прочитанным: Вход с нового устройства, 02.07.2026 08:45
```

RED evidence:

```text
flutter test test\features\notifications\notifications_screen_test.dart --reporter compact
Expected: exactly one matching candidate
Actual: Found 0 widgets
```

During emulator smoke the first implementation removed the generic label but Android merged the action into the whole notification card. Added a second boundary regression that requires the contextual action `Semantics` widgets to be explicit containers.

Boundary RED evidence:

```text
flutter test test\features\notifications\notifications_screen_test.dart --reporter compact --plain-name "notification card separates card content from inline actions"
Expected: true
Actual: <false>
```

The emulator then showed multiple real notifications with the same title, so the regression was tightened again to require date/time in the action context.

Date/time RED evidence:

```text
flutter test test\features\notifications\notifications_screen_test.dart --reporter compact --plain-name "notification card separates card content from inline actions"
Expected: exactly one matching candidate
Actual: Found 0 widgets
```

- [x] **Step 3: Add contextual action semantics with a boundary**

Added `_NotificationCardActionButton`, which keeps the visible labels unchanged while exposing context-aware action labels. `_actionContext(notification)` uses the notification title plus `_formatDateTime(createdAt)` when the timestamp is present, so repeated titles stay distinguishable:

```dart
Semantics(
  container: true,
  button: true,
  enabled: true,
  excludeSemantics: true,
  label: contextualLabel,
  onTap: onPressed,
  child: child,
)
```

Expected: screen readers and Android automation trees expose compact, separate, notification-aware action buttons instead of repeated `Открыть` labels.

- [x] **Step 4: Verify**

Run:

```powershell
C:\flutter\bin\dart.bat format lib\features\notifications\presentation\widgets\notification_card.dart test\features\notifications\notifications_screen_test.dart
C:\flutter\bin\flutter.bat test test\features\notifications\notifications_screen_test.dart --reporter compact
C:\flutter\bin\flutter.bat test test\features\notifications --reporter compact
C:\flutter\bin\flutter.bat analyze
C:\flutter\bin\flutter.bat test --reporter compact
C:\flutter\bin\flutter.bat build apk --debug
adb -s emulator-5554 install -r build\app\outputs\flutter-apk\app-debug.apk
```

Evidence after fix:

```text
notifications_screen_test.dart: 5 tests passed
test/features/notifications: 18 tests passed
flutter analyze: No issues found
flutter test: 414 tests passed
flutter build apk --debug: Built build\app\outputs\flutter-apk\app-debug.apk
adb install -r: Success
fresh reinstall smoke: app reached authenticated Overview after cold start
runtime Notifications XML: card content remains a separate non-clickable content node
runtime Notifications XML: child action buttons include title + date/time, e.g. content-desc="Открыть уведомление: Вход с нового устройства, 02.07.2026 09:08"
runtime Notifications XML: action button bounds [698,820][995,946], [698,1379][995,1505], [698,1939][995,2065]
runtime Notifications XML: no standalone content-desc="Открыть" action remained
runtime Notifications XML: exact content-desc="Открыть" count 0; contextual open button count 3; NAF=true count 0
runtime screenshots/XML: build\qa\audit_5ap_post_reinstall_after_wait.png, build\qa\audit_5ap_post_reinstall_after_wait.xml
runtime screenshots/XML: build\qa\audit_5ap_post_reinstall_notifications.png, build\qa\audit_5ap_post_reinstall_notifications.xml
```

Expected: notification-card actions are distinguishable and remain separate touch targets without changing the visible strict B2B layout.

---

#### Task 5AQ: Workflow Detail Action Semantic Context

**Files:**
- Modify: `lib/features/workflow_management/presentation/workflow_management_screen.dart`
- Modify: `test/features/workflow_management/presentation/workflow_management_screen_test.dart`

- [x] **Step 1: Reproduce the defect in runtime audit**

Fresh emulator audit after Task 5AP reopened the real workflow detail screen. The top-list card actions were already contextual after Task 5AO, but the detail action panel still exposed repeated generic action labels:

```text
content-desc="Согласовать"
content-desc="Отклонить"
content-desc="Запросить изменения"
content-desc="Комментарий"
```

Runtime evidence before the fix:

```text
build\qa\audit_5aq_workflow_detail.png
build\qa\audit_5aq_workflow_detail.xml
```

Expected: workflow detail actions must include the active task context, because these buttons directly approve, reject, request changes, or comment on one workflow item.

- [x] **Step 2: Add regression coverage and verify RED**

Extended `workflow_management_screen_test.dart` to assert contextual semantic labels in the detail panel:

```text
Согласовать: Бетонирование, задача 17
Отклонить: Бетонирование, задача 17
Запросить изменения: Бетонирование, задача 17
Добавить комментарий: Бетонирование, задача 17
```

RED evidence was verified by temporarily restoring the detail panel to the previous raw button semantics:

```text
flutter test test\features\workflow_management\presentation\workflow_management_screen_test.dart --reporter compact --plain-name "opens workflow detail with history and comments"
Expected: exactly one matching candidate
Actual: Found 0 widgets
```

- [x] **Step 3: Add contextual semantics without changing visible UI**

Updated `_WorkflowActionPanel` to reuse the same task-aware action pattern as workflow cards. `_WorkflowCardActionButton` now creates an explicit semantics container:

```dart
Semantics(
  container: true,
  button: true,
  enabled: true,
  excludeSemantics: true,
  label: semanticsLabel,
  onTap: onTap,
  child: child,
)
```

The visible strict B2B action panel remains unchanged, while Android accessibility tools receive labels with `task.title` and `task.id`.

- [x] **Step 4: Verify**

Run:

```powershell
C:\flutter\bin\dart.bat format lib\features\workflow_management\presentation\workflow_management_screen.dart test\features\workflow_management\presentation\workflow_management_screen_test.dart
C:\flutter\bin\flutter.bat test test\features\workflow_management\presentation\workflow_management_screen_test.dart --reporter compact --plain-name "opens workflow detail with history and comments"
C:\flutter\bin\flutter.bat test test\features\workflow_management --reporter compact
C:\flutter\bin\flutter.bat analyze
C:\flutter\bin\flutter.bat test --reporter compact
C:\flutter\bin\flutter.bat build apk --debug
adb -s emulator-5554 install -r build\app\outputs\flutter-apk\app-debug.apk
```

Evidence after fix:

```text
focused workflow detail test: passed
test/features/workflow_management: 15 tests passed
flutter analyze: No issues found
flutter test: 414 tests passed
flutter build apk --debug: Built build\app\outputs\flutter-apk\app-debug.apk
adb install -r: Success
runtime workflow detail XML: content-desc="Согласовать: Выполненная работа #1419, задача 1419"
runtime workflow detail XML: content-desc="Отклонить: Выполненная работа #1419, задача 1419"
runtime workflow detail XML: content-desc="Запросить изменения: Выполненная работа #1419, задача 1419"
runtime workflow detail XML: content-desc="Добавить комментарий: Выполненная работа #1419, задача 1419"
runtime workflow detail XML: no standalone content-desc="Согласовать", "Отклонить", "Запросить изменения", or "Комментарий" action remained
runtime screenshots/XML: build\qa\audit_5aq_workflow_detail_after_login_top.png, build\qa\audit_5aq_workflow_detail_after_login_top.xml
```

Expected: workflow detail actions are distinguishable for screen-reader users and automation trees without adding visual noise to the operational detail screen.

---

#### Task 5AR: Android Launch Splash Safe Area

**Files:**
- Add: `android/app/src/main/res/drawable/splash_icon.xml`
- Modify: `android/app/src/main/res/drawable/launch_background.xml`
- Modify: `android/app/src/main/res/drawable-v21/launch_background.xml`
- Modify: `android/app/src/main/res/values-v31/styles.xml`
- Modify: `android/app/src/main/res/values-night-v31/styles.xml`
- Modify: `test/android/android_manifest_startup_test.dart`

- [x] **Step 1: Reproduce the defect in runtime audit**

During debug/profile/release launch smoke after Task 5AQ, Android startup showed a real UX defect before Flutter's first frame: the platform splash used the launcher icon directly, so Android 12 displayed an oversized cropped `P` mark in the circular splash mask.

Runtime evidence:

```text
build\qa\audit_5aq_relaunch_timeout.png
build\qa\audit_5ar_debug_splash_fixed.png
```

The same investigation separated this visual defect from emulator launch latency. Launches immediately after `adb install -r` were inflated by Android PackageManager/Finsky and system_server load. Release no-reinstall cold launch reached the app in `TotalTime: 5160`, while post-install launches could still take 30+ seconds on the emulator. No Dart crash, `FlutterError`, or app-side fatal error was found in the captured logs.

Expected: the unavoidable Android native splash must look intentional and within the safe area even when the emulator or device needs extra time before Flutter draws the first frame.

- [x] **Step 2: Add regression coverage and verify RED**

Updated `test/android/android_manifest_startup_test.dart` so Android startup resources must use a dedicated drawable splash icon instead of `@mipmap/ic_launcher`.

RED evidence:

```text
flutter test test\android\android_manifest_startup_test.dart --reporter compact
Expected: true
Actual: <false>
Reason: android/app/src/main/res/drawable/splash_icon.xml is missing
```

- [x] **Step 3: Add dedicated safe-area splash drawable**

Added `@drawable/splash_icon` and pointed both pre-Android-12 launch backgrounds and Android 12 styles to it. The first vector was still too large in runtime smoke, so the icon geometry was reduced into the Android splash safe area instead of relying on the launcher asset.

Expected: launch backgrounds and Android 12 splash styles share one purpose-built startup drawable, and launcher icon shape/mask changes no longer affect the native splash.

- [x] **Step 4: Verify**

Run:

```powershell
C:\flutter\bin\dart.bat format test\android\android_manifest_startup_test.dart
C:\flutter\bin\flutter.bat test test\android\android_manifest_startup_test.dart --reporter compact
C:\flutter\bin\flutter.bat test test\features\workflow_management\presentation\workflow_management_screen_test.dart --reporter compact --plain-name "opens workflow detail with history and comments"
C:\flutter\bin\flutter.bat analyze
C:\flutter\bin\flutter.bat test --reporter compact
C:\flutter\bin\flutter.bat build apk --debug
adb -s emulator-5554 install -r build\app\outputs\flutter-apk\app-debug.apk
```

Evidence after fix:

```text
test/android/android_manifest_startup_test.dart: passed
focused workflow detail regression: passed
flutter analyze: No issues found
flutter test: 414 tests passed
flutter build apk --debug: Built build\app\outputs\flutter-apk\app-debug.apk
adb install -r: Success
runtime splash screenshot: build\qa\audit_5ar_debug_splash_fixed_safearea.png
runtime post-launch screenshot/XML: build\qa\audit_5ar_debug_launch_late.png, build\qa\audit_5ar_debug_launch_late.xml
runtime post-launch XML: login screen reached, no Android ANR dialog, no runtime error screen
runtime logcat: app displayed and fully drawn; no FlutterError, DartError, FATAL, or AndroidRuntime crash for the app process
```

Residual audit note:

```text
Post-install debug/profile/release launch latency on the emulator remains noisy and can exceed ActivityTaskManager wait thresholds because of PackageManager/Finsky/system_server load. Release no-reinstall cold launch was much lower, but startup performance should stay in the audit queue as a separate measurement task rather than being hidden by the splash polish.
```

Expected: Android native startup now uses a safe-area splash asset and no longer presents a cropped launcher icon during slow first-frame scenarios.

---

#### Task 5AS: Overview Next Actions All Button Semantic Context

**Files:**
- Modify: `lib/features/home/presentation/widgets/overview_next_actions.dart`
- Modify: `test/features/home/mobile_overview_screen_test.dart`

- [x] **Step 1: Reproduce the defect in runtime audit**

Fresh emulator audit after Task 5AR covered:

```text
Overview
Work
Actions
More
Notifications
```

The stronger actionable defect was on Overview: the `Следующие действия` header kept the visible compact text `Все`, but Android UIAutomator exposed the button as a standalone generic action:

```text
content-desc="Все"
```

Runtime evidence before the fix:

```text
build\qa\audit_5as_overview.png
build\qa\audit_5as_work.png
build\qa\audit_5as_actions.png
build\qa\audit_5as_more.png
build\qa\audit_5as_notifications.png
```

Expected: the compact visible label may remain `Все`, but accessibility must announce what the action opens.

- [x] **Step 2: Add regression coverage and verify RED**

Added `next actions all button exposes action center context` to `mobile_overview_screen_test.dart`. The test requires:

```text
Открыть все действия
```

and rejects a standalone `Все` semantics label.

RED evidence:

```text
flutter test test\features\home\mobile_overview_screen_test.dart --reporter compact --plain-name "next actions all button exposes action center context"
Expected: exactly one matching candidate
Actual: Found 0 widgets
```

- [x] **Step 3: Add an explicit semantics boundary without changing visible UI**

Wrapped the trailing `TextButton` with an explicit semantics container:

```dart
Semantics(
  container: true,
  button: true,
  enabled: true,
  excludeSemantics: true,
  label: 'Открыть все действия',
  onTap: openAllActions,
  child: TextButton(
    onPressed: openAllActions,
    child: const Text('Все'),
  ),
)
```

The visible B2B header stays compact, while screen readers and Android automation receive the actual action intent.

- [x] **Step 4: Verify**

Run:

```powershell
C:\flutter\bin\dart.bat format lib\features\home\presentation\widgets\overview_next_actions.dart test\features\home\mobile_overview_screen_test.dart
C:\flutter\bin\flutter.bat test test\features\home\mobile_overview_screen_test.dart --reporter compact --plain-name "next actions all button exposes action center context"
C:\flutter\bin\flutter.bat test test\features\home\mobile_overview_screen_test.dart --reporter compact
C:\flutter\bin\flutter.bat analyze
C:\flutter\bin\flutter.bat test --reporter compact
C:\flutter\bin\flutter.bat build apk --debug
adb -s emulator-5554 install -r build\app\outputs\flutter-apk\app-debug.apk
```

Evidence after fix:

```text
focused Overview next-actions test: passed
test/features/home/mobile_overview_screen_test.dart: 15 tests passed
flutter analyze: No issues found
flutter test: 415 tests passed
flutter build apk --debug: Built build\app\outputs\flutter-apk\app-debug.apk
adb install -r: Success
runtime Overview XML: content-desc="Открыть все действия"
runtime Overview XML: no standalone content-desc="Все" action remained
runtime screenshots/XML: build\qa\audit_5as_overview_fixed.png, build\qa\audit_5as_overview_fixed.xml
runtime logcat: no FlutterError, DartError, FATAL, or AndroidRuntime crash for the app process
```

Residual audit note:

```text
Post-install debug launch still showed emulator-side startup latency and reached first draw after +1m43s. This remains a separate startup-performance audit item. Overview also still shows the next scroll row partially at the bottom; it is visible as scroll continuation and should be judged separately from the generic semantics fix.
```

Expected: Overview next-actions header remains visually dense, but the compact `Все` command is no longer ambiguous for assistive technologies.

---

#### Task 5AT: Notification Filter Semantic Context

**Files:**
- Modify: `lib/features/notifications/presentation/notifications_screen.dart`
- Modify: `test/features/notifications/notifications_screen_test.dart`

- [x] **Step 1: Reproduce the defect in runtime audit**

Fresh emulator audit after Task 5AS opened the real Notifications screen. Notification card actions were already contextual after Task 5AP, but the top filter chip still exposed the compact visible copy as a standalone generic action:

```text
content-desc="Все"
```

Runtime evidence before the fix:

```text
build\qa\audit_5as_notifications.png
build\qa\audit_5as_notifications.xml
```

Expected: filter chips may stay visually compact, but accessibility should announce what list state will be shown.

- [x] **Step 2: Add regression coverage and verify RED**

Added `notification filters expose purpose-driven semantics` to `notifications_screen_test.dart`. The test requires:

```text
Показать все уведомления
Показать непрочитанные уведомления, 1
Показать прочитанные уведомления
```

and rejects a standalone `Все` semantics label.

RED evidence:

```text
flutter test test\features\notifications\notifications_screen_test.dart --reporter compact --plain-name "notification filters expose purpose-driven semantics"
Expected: exactly one matching candidate
Actual: Found 0 widgets
```

- [x] **Step 3: Add explicit filter semantics without changing visible chips**

Wrapped each `FilterChip` with an explicit semantics container. The visible chip labels remain `Все`, `Непрочитанные`, and `Прочитанные`, while the automation/screen-reader labels describe the filter action:

```dart
Semantics(
  container: true,
  button: true,
  enabled: true,
  selected: selected == filter,
  excludeSemantics: true,
  label: semanticLabel,
  onTap: () => onChanged(filter),
  child: FilterChip(...),
)
```

Expected: segmented notification filters are unambiguous and still preserve selected state.

- [x] **Step 4: Verify**

Run:

```powershell
C:\flutter\bin\dart.bat format lib\features\notifications\presentation\notifications_screen.dart test\features\notifications\notifications_screen_test.dart
C:\flutter\bin\flutter.bat test test\features\notifications\notifications_screen_test.dart --reporter compact --plain-name "notification filters expose purpose-driven semantics"
C:\flutter\bin\flutter.bat test test\features\notifications --reporter compact
C:\flutter\bin\flutter.bat analyze
C:\flutter\bin\flutter.bat test --reporter compact
C:\flutter\bin\flutter.bat build apk --debug
adb -s emulator-5554 install -r build\app\outputs\flutter-apk\app-debug.apk
```

Evidence after fix:

```text
focused notification filter semantics test: passed
test/features/notifications: 19 tests passed
flutter analyze: No issues found
flutter test: 416 tests passed
flutter build apk --debug: Built build\app\outputs\flutter-apk\app-debug.apk
adb install -r: Success
runtime Notifications XML: content-desc="Показать все уведомления"
runtime Notifications XML: content-desc="Показать непрочитанные уведомления"
runtime Notifications XML: content-desc="Показать прочитанные уведомления"
runtime Notifications XML: no standalone content-desc="Все", "Непрочитанные", or "Прочитанные" filter action remained
runtime screenshots/XML: build\qa\audit_5at_notifications_fixed.png, build\qa\audit_5at_notifications_fixed.xml
runtime logcat: no FlutterError, DartError, FATAL, or AndroidRuntime crash for the app process
```

Residual audit note:

```text
Post-install debug launch again showed emulator-side startup latency and reached first draw after +1m34s. This remains tracked separately from the notification filter semantics fix.
```

Expected: notification filter controls are explicit for assistive technologies while the visual segmented-control layout remains compact.

---

#### Task 5AU: Login Brand Tagline Localization

**Files:**
- Modify: `lib/features/auth/presentation/login_screen.dart`
- Modify: `test/features/auth/presentation/login_screen_test.dart`

- [x] **Step 1: Reproduce the defect in runtime audit**

Fresh startup/runtime audit after Task 5AT separated emulator startup latency from user-visible UI defects:

```text
debug no-reinstall starts: timeout around 11.9-12.8s, first draw later in logcat
profile starts: post-install timeout/noisy; later no-reinstall run reached TotalTime 8838
release clean install starts: first post-install timeout/noisy; later no-reinstall runs reached TotalTime 7426 and 4283
```

Logcat evidence showed `auth/me` starts after `Displayed/Fully drawn`, so API calls are not blocking the first Flutter frame. The clearest real release-facing defect on the first screen was the English brand subtitle:

```text
content-desc="Industrial management"
```

Runtime evidence before the fix:

```text
build\qa\audit_5au_release_login.png
build\qa\audit_5au_release_login.xml
```

Expected: the Russian mobile app must not show an English product tagline on the first screen.

- [x] **Step 2: Add regression coverage and verify RED**

Added `login brand header uses Russian product tagline` to `login_screen_test.dart`. The test requires:

```dart
expect(find.text('Управление строительством'), findsOneWidget);
expect(find.text('Industrial management'), findsNothing);
```

RED evidence:

```text
flutter test test\features\auth\presentation\login_screen_test.dart --reporter compact --plain-name "login brand header uses Russian product tagline"
Expected: exactly one matching candidate
Actual: Found 0 widgets with text "Управление строительством"
```

- [x] **Step 3: Replace only the hardcoded tagline**

Changed `_LoginBrandHeader` from:

```dart
'Industrial management'
```

to:

```dart
'Управление строительством'
```

Expected: the login screen keeps its visual layout and auth behavior, but the first-screen product signal is localized.

- [x] **Step 4: Verify**

Run:

```powershell
C:\flutter\bin\dart.bat format lib\features\auth\presentation\login_screen.dart test\features\auth\presentation\login_screen_test.dart
C:\flutter\bin\flutter.bat test test\features\auth\presentation\login_screen_test.dart --reporter compact --plain-name "login brand header uses Russian product tagline"
C:\flutter\bin\flutter.bat test test\features\auth\presentation\login_screen_test.dart --reporter compact
C:\flutter\bin\flutter.bat analyze
C:\flutter\bin\flutter.bat test --reporter compact
C:\flutter\bin\flutter.bat build apk --debug
adb -s emulator-5554 uninstall ru.prohelper.prohelpers_mobile
adb -s emulator-5554 install build\app\outputs\flutter-apk\app-debug.apk
```

Evidence after fix:

```text
focused login tagline test: passed
test/features/auth/presentation/login_screen_test.dart: 11 tests passed
flutter analyze: No issues found
flutter test: 417 tests passed
flutter build apk --debug: Built build\app\outputs\flutter-apk\app-debug.apk
adb install: Success
runtime login XML: content-desc="Управление строительством"
runtime login XML: no "Industrial management"
runtime screenshots/XML: build\qa\audit_5au_login_fixed.png, build\qa\audit_5au_login_fixed.xml
runtime app-PID logcat: no FATAL, AndroidRuntime, FlutterError, or DartError for the app process
```

Residual audit note:

```text
Debug/profile post-install startup latency remains noisy on the emulator, but release no-reinstall cold start reached 4.283s in the latest run. This should stay in the final release audit, not be mistaken for API-blocked startup.
```

Expected: the first visible mobile screen is now fully Russian and keeps the B2B login layout intact.

---

## Execution Status

- [x] Task 1 initial emulator audit performed.
- [x] Task 2 notification action clarity implemented and verified.
- [x] Task 3 Overview surface hierarchy implemented and verified.
- [x] Task 4 compact operational search implemented and verified.
- [x] Task 5A Russian Material date picker implemented and verified.
- [x] Task 5B locale-aware companion amount metrics implemented and verified.
- [x] Task 5C refresh accessibility label implemented, code-verified, and emulator-verified.
- [x] Task 5D warehouse task refresh accessibility label implemented, code-verified, and emulator-verified.
- [x] Task 5E login credential field IME hardening implemented and emulator-verified.
- [x] Task 5F warehouse empty/search accessibility implemented and emulator-verified.
- [x] Task 5G transient GET retry implemented and code-verified.
- [x] Task 5H warehouse receipt action moved from overlapping FAB into an in-flow card and emulator-verified.
- [x] Task 5I light theme system status bar readability implemented and emulator-verified.
- [x] Task 5J workflow list comment action made visible and emulator-verified.
- [x] Task 5K login field semantics hardened; UIAutomator hint-only NAF limitation documented.
- [x] Task 5L login labels and keyboard spacing code-verified and emulator-verified after dismissing Android SystemUI ANR.
- [x] Task 5M search clear action exposed as an accessible button, code-verified, and emulator-verified.
- [x] Task 5N auth bootstrap decoupled from provider construction and code-verified; residual first-frame delay remains under investigation.
- [x] Task 5O Overview work summary rows compacted, code-verified, and emulator-verified.
- [x] Task 5P compact search surface contrast implemented, code-verified, and emulator-verified on `Работа` and `Действия`.
- [x] Task 5Q Android first-frame renderer hardening implemented, profile-trace verified, analyzer-clean, and full-suite verified.
- [x] Task 5R full-screen gesture safe areas implemented, code-verified, and emulator-verified on `Уведомления`, `Согласования`, and `Детали согласования`.
- [x] Task 5S transient HTTP status retry implemented, code-verified, full-suite verified, and release-smoke verified on `Overview`, `Notifications`, `Work`, and `Workflow approvals`.
- [x] Task 5T dynamic type app-bar resilience implemented, code/full-suite verified, and release-smoke checked on the large-font auth screen; authenticated large-font Work smoke completed in Task 5V.
- [x] Task 5U login keyboard layout with large text implemented, full-suite verified, and release-smoke verified with focused Email, visible submit button, and no ANR/Fatal/Flutter/Dio log matches.
- [x] Task 5V login profile authorization fixed, full-suite verified, and release-smoke verified on normal-font login plus large-font authenticated Overview/Work.
- [x] Task 5W notification status contrast hardened, full-suite verified, and release-smoke verified on the real Notifications screen.
- [x] Task 5X landscape and tablet viewport regression coverage implemented, full-suite verified, and emulator state restored to light portrait smoke.
- [x] Task 5Y mojibake guard expanded to fixtures, broken warehouse Russian fixture corrected, analyzer-clean, and full-suite verified.
- [x] Task 5Z user-facing error sanitizer hardened, direct technical error UI outputs removed, analyzer-clean, and full-suite verified.
- [x] Task 5AA bottom navigation shell anchored in light theme, analyzer-clean, viewport-tested, and emulator-smoke verified after debug install/login.
- [x] Task 5AB Overview project context card compacted, analyzer-clean, viewport-tested, and emulator-smoke verified after debug rebuild/install.
- [x] Task 5AC Overview notification-only status banner compacted, analyzer-clean, viewport-tested, and emulator-smoke verified with accessible icon action.
- [x] Task 5AD Overview notification title copy tightened, analyzer-clean, viewport-tested, and emulator-smoke verified without ellipsis.
- [x] Task 5AE More tab project context card compacted, analyzer-clean, viewport-tested, full-suite verified, and emulator-smoke verified.
- [x] Task 5AF Workflow search/filter semantics separated, analyzer-clean, viewport-tested, and emulator-smoke verified with a documented hint-only EditText NAF limitation.
- [x] Task 5AG Notification card/action semantics split, analyzer-clean, full-suite verified, and emulator-smoke verified on the real `Уведомления` screen.
- [x] Task 5AH Notification detail dead target action hidden, analyzer-clean, full-suite verified, and emulator-smoke verified on an unknown security-login notification.
- [x] Task 5AI Notification detail title compacted, analyzer-clean, full-suite verified, and emulator-smoke verified.
- [x] Task 5AJ Workflow list secondary actions compacted, analyzer-clean, full-suite verified, and emulator-smoke verified.
- [x] Task 5AK Project selection refresh accessibility label implemented, analyzer-clean, full-suite verified, and emulator-smoke verified.
- [x] Task 5AL Overview dashboard error resilience implemented across mobile/backend, analyzer/full-suite/backend-static verified, and emulator-smoke verified.
- [x] Task 5AM Android startup splash polish implemented, analyzer/full-suite verified, and emulator-smoke verified through login to Overview.
- [x] Task 5AN Knowledge Hub search accessibility boundaries implemented, analyzer/full-suite verified, and emulator-smoke verified.
- [x] Task 5AO Workflow card action semantic context implemented, analyzer/full-suite verified, and emulator-smoke verified.
- [x] Task 5AP Notification card action semantic context implemented, analyzer/full-suite verified, and emulator-smoke verified.
- [x] Task 5AQ Workflow detail action semantic context implemented, analyzer/full-suite verified, and emulator-smoke verified.
- [x] Task 5AR Android launch splash safe area implemented, analyzer/full-suite verified, and emulator-smoke verified; startup latency remains a separate audit item.
- [x] Task 5AS Overview next-actions `Все` semantic context implemented, analyzer/full-suite verified, and emulator-smoke verified.
- [x] Task 5AT Notification filter semantic context implemented, analyzer/full-suite verified, and emulator-smoke verified.
- [x] Task 5AU Login brand tagline localized, analyzer/full-suite verified, and emulator-smoke verified.
- [ ] Task 5 continuous hardening still in progress.

## Self-Review

- Spec coverage: the plan covers emulator checks, Superpowers planning, UI/UX fixes, risky-change tests, analyzer, full test suite, and local smoke verification.
- Placeholder scan: no task uses `TBD`, `TODO`, or vague "add tests" language without concrete commands.
- Type consistency: referenced Dart types match existing or planned declarations: `ProStatusBanner.surfaceTone`, `ProSurfaceTone`, `ProSearchFilterDensity`, `ProTouchTarget`.
