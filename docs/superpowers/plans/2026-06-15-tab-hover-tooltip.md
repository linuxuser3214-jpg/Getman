# Tab Hover Tooltip Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show a Postman-style hover tooltip over each desktop tab — the tab's name on top and its URL below in a muted color — appearing only after a ~500ms hover delay.

**Architecture:** A custom themed hover overlay built into `TabWidget`, mirroring the existing `variable_hover_popover.dart` pattern: a delay `Timer` started on `MouseRegion.onEnter` inserts an `OverlayEntry` rendering a themed `panelBox` card; `onExit`/`onTap`/`dispose` cancel the timer and remove the entry. The card content is a small private `_TabTooltipCard` widget (name line + optional URL line), styled entirely from the theme extensions.

**Tech Stack:** Flutter, `flutter_bloc`, theme extensions (`context.appLayout` / `appTypography` / `appDecoration`), `mocktail` + `flutter_test` for the widget test. Always invoke Flutter as `fvm flutter ...`.

---

## File Structure

- **Modify:** `lib/features/home/presentation/widgets/tab_widget.dart`
  - Add a file-level delay const + a max-width const.
  - Add `Timer? _tooltipTimer` + `OverlayEntry? _tooltipEntry` state, with `_scheduleTooltip` / `_showTooltip` / `_hideTooltip` methods.
  - Wire those into the existing `MouseRegion.onEnter/onExit`, the `GestureDetector.onTap`, `_showContextMenu`, and `dispose`.
  - Wrap the tab chrome in `Semantics(tooltip: …)` for screen readers.
  - Add a private `_TabTooltipCard` widget at the bottom of the file.
- **Create:** `test/features/home/presentation/widgets/tab_widget_test.dart`
  - Three `testWidgets`: tooltip shows name+URL after the delay; URL line omitted for an empty-URL tab; no tooltip if the pointer leaves before the delay.

---

## Task 1: Failing widget test for the hover tooltip

**Files:**
- Create: `test/features/home/presentation/widgets/tab_widget_test.dart`

- [ ] **Step 1: Write the failing test file**

Create `test/features/home/presentation/widgets/tab_widget_test.dart` with exactly:

```dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getman/core/domain/entities/request_config_entity.dart';
import 'package:getman/core/theme/themes/brutalist/brutalist_theme.dart';
import 'package:getman/features/collections/domain/entities/collection_node_entity.dart';
import 'package:getman/features/collections/domain/repositories/collections_repository.dart';
import 'package:getman/features/collections/domain/usecases/collections_usecases.dart';
import 'package:getman/features/collections/presentation/bloc/collections_bloc.dart';
import 'package:getman/features/collections/presentation/bloc/collections_event.dart';
import 'package:getman/features/home/domain/usecases/tab_dirty_checker.dart';
import 'package:getman/features/home/presentation/widgets/tab_widget.dart';
import 'package:getman/features/tabs/domain/entities/request_tab_entity.dart';
import 'package:getman/features/tabs/domain/repositories/tabs_repository.dart';
import 'package:getman/features/tabs/domain/usecases/send_request_use_case.dart';
import 'package:getman/features/tabs/presentation/bloc/tabs_bloc.dart';
import 'package:getman/features/tabs/presentation/bloc/tabs_event.dart';
import 'package:mocktail/mocktail.dart';

class MockTabsRepository extends Mock implements TabsRepository {}

class MockSendRequestUseCase extends Mock implements SendRequestUseCase {}

class MockCollectionsRepository extends Mock implements CollectionsRepository {}

class _FakeConfig extends Fake implements HttpRequestConfigEntity {}

HttpRequestTabEntity _linkedTab() => const HttpRequestTabEntity(
  tabId: 'tab1',
  config: HttpRequestConfigEntity(id: 'node1', url: 'https://api/users'),
  collectionName: 'GetUsers',
  collectionNodeId: 'node1',
);

HttpRequestTabEntity _emptyTab() => const HttpRequestTabEntity(
  tabId: 'tab2',
  config: HttpRequestConfigEntity(id: 'node2'),
);

void main() {
  late MockTabsRepository tabsRepo;
  late MockSendRequestUseCase sendUseCase;
  late MockCollectionsRepository collectionsRepo;

  setUpAll(() {
    registerFallbackValue(_FakeConfig());
    registerFallbackValue(<CollectionNodeEntity>[]);
    registerFallbackValue(
      const HttpRequestTabEntity(
        tabId: 'fallback',
        config: HttpRequestConfigEntity(id: 'fallback'),
      ),
    );
  });

  setUp(() {
    tabsRepo = MockTabsRepository();
    sendUseCase = MockSendRequestUseCase();
    collectionsRepo = MockCollectionsRepository();
    when(() => tabsRepo.saveTabs(any())).thenAnswer((_) async {});
    when(() => tabsRepo.putTab(any())).thenAnswer((_) async {});
    when(() => tabsRepo.deleteTabs(any())).thenAnswer((_) async {});
    when(() => tabsRepo.saveTabOrder(any())).thenAnswer((_) async {});
    when(
      () => collectionsRepo.getCollections(),
    ).thenAnswer((_) async => const []);
    when(() => collectionsRepo.saveCollections(any())).thenAnswer((_) async {});
  });

  Future<void> pumpTab(WidgetTester tester, HttpRequestTabEntity tab) async {
    when(() => tabsRepo.getTabs()).thenAnswer((_) async => [tab]);
    final tabsBloc =
        TabsBloc(repository: tabsRepo, sendRequestUseCase: sendUseCase)
          ..add(const LoadTabs());
    await tabsBloc.stream.firstWhere((s) => !s.isLoading && s.tabs.isNotEmpty);

    final collectionsBloc =
        CollectionsBloc(
          getCollectionsUseCase: GetCollectionsUseCase(collectionsRepo),
          saveCollectionsUseCase: SaveCollectionsUseCase(collectionsRepo),
          saveDebounce: const Duration(milliseconds: 5),
        )..add(const ReplaceCollections([]));
    await collectionsBloc.stream.first;

    addTearDown(tabsBloc.close);
    addTearDown(collectionsBloc.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: brutalistTheme(Brightness.light),
        home: Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider.value(value: tabsBloc),
              BlocProvider.value(value: collectionsBloc),
            ],
            child: RepositoryProvider<TabDirtyChecker>.value(
              value: const TabDirtyChecker(),
              child: Align(
                alignment: Alignment.topLeft,
                child: TabWidget(
                  tabId: tab.tabId,
                  index: 0,
                  isActive: true,
                  onTap: () {},
                  onClose: () async => true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<TestGesture> hoverTab(WidgetTester tester) async {
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(() => gesture.removePointer());
    await gesture.moveTo(tester.getCenter(find.byType(TabWidget)));
    await tester.pump();
    return gesture;
  }

  testWidgets('shows name + URL in a tooltip after the hover delay', (
    tester,
  ) async {
    await pumpTab(tester, _linkedTab());
    final tooltip = find.byKey(const ValueKey('tab_tooltip_tab1'));

    await hoverTab(tester);
    // Before the delay elapses, nothing is shown.
    await tester.pump(const Duration(milliseconds: 200));
    expect(tooltip, findsNothing);

    // After the delay, the tooltip appears with both lines.
    await tester.pump(const Duration(milliseconds: 400));
    expect(tooltip, findsOneWidget);
    expect(
      find.descendant(of: tooltip, matching: find.text('GetUsers')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tooltip, matching: find.text('https://api/users')),
      findsOneWidget,
    );
  });

  testWidgets('omits the URL line when the tab has no URL', (tester) async {
    await pumpTab(tester, _emptyTab());
    final tooltip = find.byKey(const ValueKey('tab_tooltip_tab2'));

    await hoverTab(tester);
    await tester.pump(const Duration(milliseconds: 600));

    expect(tooltip, findsOneWidget);
    expect(
      find.descendant(of: tooltip, matching: find.text('NEW REQUEST')),
      findsOneWidget,
    );
    // Only the name line — no muted URL row.
    expect(
      find.descendant(of: tooltip, matching: find.byType(Text)),
      findsOneWidget,
    );
  });

  testWidgets('does not show the tooltip if the pointer leaves before delay', (
    tester,
  ) async {
    await pumpTab(tester, _linkedTab());
    final tooltip = find.byKey(const ValueKey('tab_tooltip_tab1'));

    final gesture = await hoverTab(tester);
    await tester.pump(const Duration(milliseconds: 200)); // < 500ms delay
    await gesture.moveTo(Offset.zero); // leave the tab
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(tooltip, findsNothing);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `fvm flutter test test/features/home/presentation/widgets/tab_widget_test.dart`
Expected: FAIL — the first two tests fail because no widget with key `tab_tooltip_tab1` / `tab_tooltip_tab2` is ever inserted (`findsNothing` where `findsOneWidget` is expected). (The third test may already pass — that is fine.)

- [ ] **Step 3: Commit the failing test**

```bash
git add test/features/home/presentation/widgets/tab_widget_test.dart
git commit -m "test: failing hover-tooltip tests for TabWidget"
```

---

## Task 2: Implement the hover tooltip in TabWidget

**Files:**
- Modify: `lib/features/home/presentation/widgets/tab_widget.dart`

- [ ] **Step 1: Add the file-level consts**

In `lib/features/home/presentation/widgets/tab_widget.dart`, immediately **after** the import block and **before** `class TabWidget`, add:

```dart
/// Delay before the hover tooltip appears, so a quick pass across the tab strip
/// doesn't flash it. Durations aren't part of the theme extensions; this matches
/// the other hardcoded Durations already in this file.
const Duration _tabTooltipDelay = Duration(milliseconds: 500);

/// Max width of the hover tooltip card (mirrors variable_hover_popover's 320 +
/// a little extra room for URLs). Long URLs wrap to 2 lines then ellipsis.
const double _tabTooltipMaxWidth = 360;
```

- [ ] **Step 2: Add the tooltip state fields**

In `_TabWidgetState`, add these fields right below `bool _isHovered = false;`:

```dart
  Timer? _tooltipTimer;
  OverlayEntry? _tooltipEntry;
```

- [ ] **Step 3: Hide the tooltip on dispose**

Replace the existing `dispose` method:

```dart
  @override
  void dispose() {
    _sizeController.dispose();
    super.dispose();
  }
```

with:

```dart
  @override
  void dispose() {
    _hideTooltip();
    _sizeController.dispose();
    super.dispose();
  }
```

- [ ] **Step 4: Add the schedule / show / hide methods**

Add these three methods to `_TabWidgetState` (place them right after `_handleClose`):

```dart
  void _scheduleTooltip(HttpRequestTabEntity tab) {
    _tooltipTimer?.cancel();
    _tooltipTimer = Timer(_tabTooltipDelay, () => _showTooltip(tab));
  }

  void _hideTooltip() {
    _tooltipTimer?.cancel();
    _tooltipTimer = null;
    _tooltipEntry?.remove();
    _tooltipEntry?.dispose();
    _tooltipEntry = null;
  }

  void _showTooltip(HttpRequestTabEntity tab) {
    if (!mounted || _tooltipEntry != null) return;
    final overlay = Overlay.of(context);
    final overlayBox = overlay.context.findRenderObject() as RenderBox?;
    final tabBox = context.findRenderObject() as RenderBox?;
    if (overlayBox == null || tabBox == null) return;

    const gap = 4.0;
    final tabTopLeft = tabBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    final maxLeft = (overlayBox.size.width - _tabTooltipMaxWidth - gap)
        .clamp(0.0, double.infinity);
    final left = tabTopLeft.dx.clamp(0.0, maxLeft);
    final top = tabTopLeft.dy + tabBox.size.height + gap;

    _tooltipEntry = OverlayEntry(
      builder: (_) => Positioned(
        left: left,
        top: top,
        child: _TabTooltipCard(tab: tab),
      ),
    );
    overlay.insert(_tooltipEntry!);
  }
```

- [ ] **Step 5: Wire the MouseRegion + GestureDetector**

In `build`, replace the `MouseRegion(...)`/`GestureDetector(...)` opening (the part from `child: MouseRegion(` down to `onTap: widget.onTap,`) so the hover handlers also drive the tooltip and the tap dismisses it. Specifically replace:

```dart
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => setState(() => _isHovered = true),
                  onExit: (_) => setState(() => _isHovered = false),
                  child: GestureDetector(
                    onTap: widget.onTap,
```

with:

```dart
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) {
                    setState(() => _isHovered = true);
                    _scheduleTooltip(tab);
                  },
                  onExit: (_) {
                    setState(() => _isHovered = false);
                    _hideTooltip();
                  },
                  child: GestureDetector(
                    onTap: () {
                      _hideTooltip();
                      widget.onTap();
                    },
```

- [ ] **Step 6: Hide the tooltip when the context menu opens**

In `_showContextMenu`, add `_hideTooltip();` as the very first statement of the method body (before `final theme = Theme.of(context);`):

```dart
  void _showContextMenu(
    BuildContext context,
    Offset position,
    HttpRequestTabEntity tab,
  ) {
    _hideTooltip();
    final theme = Theme.of(context);
```

- [ ] **Step 7: Add the `_TabTooltipCard` widget**

At the **end** of the file (after the closing brace of `_TabWidgetState`), add:

```dart
/// The hover tooltip card: the tab's display title with the URL beneath it in a
/// muted color. Themed via the active theme's `panelBox`; the URL line is
/// omitted when the request has no URL.
class _TabTooltipCard extends StatelessWidget {
  const _TabTooltipCard({required this.tab});

  final HttpRequestTabEntity tab;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final layout = context.appLayout;
    final typography = context.appTypography;
    final url = tab.config.url;

    return Material(
      type: MaterialType.transparency,
      child: Container(
        key: ValueKey('tab_tooltip_${tab.tabId}'),
        constraints: const BoxConstraints(maxWidth: _tabTooltipMaxWidth),
        padding: EdgeInsets.all(layout.isCompact ? 8 : 12),
        decoration: context.appDecoration.panelBox(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tab.displayTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: layout.fontSizeNormal,
                fontWeight: typography.titleWeight,
                color: theme.colorScheme.onSurface,
              ),
            ),
            if (url.isNotEmpty) ...[
              SizedBox(height: layout.tabSpacing),
              Text(
                url,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: layout.fontSizeSmall,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 8: Add the `Semantics` wrapper for screen readers**

In `build`, wrap the `AnimatedContainer` (the child of the `GestureDetector`) in a `Semantics` node so the tooltip text is still announced. Change the `GestureDetector`'s `child:` from:

```dart
                    child: AnimatedContainer(
```

to:

```dart
                    child: Semantics(
                      tooltip: tab.config.url.isEmpty
                          ? tab.displayTitle
                          : '${tab.displayTitle}\n${tab.config.url}',
                      child: AnimatedContainer(
```

Then add one extra closing `)` for the new `Semantics` — find the `AnimatedContainer`'s closing `)` (the line `                    ),` that currently closes `AnimatedContainer` right before the `GestureDetector` closes) and add a matching `)` after it. After the edit the nesting reads `... child: Semantics(... child: AnimatedContainer(...)),`.

Note: run the formatter in Task 3 — it will normalize the re-indentation introduced by the new `Semantics` wrapper.

- [ ] **Step 9: Run the tooltip tests to verify they pass**

Run: `fvm flutter test test/features/home/presentation/widgets/tab_widget_test.dart`
Expected: PASS — all three tests green.

- [ ] **Step 10: Commit**

```bash
git add lib/features/home/presentation/widgets/tab_widget.dart
git commit -m "feat(tabs): hover tooltip with tab name + URL"
```

---

## Task 3: Full verification bar

**Files:** none (verification only)

- [ ] **Step 1: Format**

Run: `fvm dart format lib test`
Expected: reports the touched files formatted (or "0 changed" if already clean).

- [ ] **Step 2: Static analysis — very_good_analysis**

Run: `fvm flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Static analysis — custom_lint (architecture rules)**

Run: `fvm dart run custom_lint`
Expected: `No issues found!` (in particular `avoid_hardcoded_brand_colors` must be clean — the card uses only theme-derived colors).

- [ ] **Step 4: Static analysis — bloc_lint**

Run: `fvm dart run bloc_tools:bloc lint lib`
Expected: `0 issues found`.

- [ ] **Step 5: Full test suite**

Run: `fvm flutter test`
Expected: all tests green.

- [ ] **Step 6: Commit any format-only changes (if Step 1 changed files)**

```bash
git add -A
git commit -m "style: dart format after tab tooltip" || echo "nothing to format-commit"
```

---

## Task 4 (follow-up): Sync the wiki

**Files:** in the separate `Getman.wiki.git` repo (NOT this repo).

- [ ] **Step 1: Clone the wiki (if not already local)**

```bash
git clone https://github.com/thiagomiranda3/Getman.wiki.git /tmp/getman-wiki
```

- [ ] **Step 2: Edit the Tabs page**

Add a short note to the tabs/UI page (e.g. `Tabs.md` or the relevant page found in `/tmp/getman-wiki`): hovering a tab for a moment shows a tooltip with the tab's name and its URL. Match verbatim UI labels.

- [ ] **Step 3: Commit + push the wiki**

```bash
cd /tmp/getman-wiki && git add -A && git commit -m "docs: tab hover tooltip" && git push origin master
```

---

## Self-Review notes

- **Spec coverage:** delay (Task 2 Step 1 const + tests), name line + muted URL line (Step 7), empty-URL omission (Step 7 `if (url.isNotEmpty)` + Task 1 test 2), theme adherence (Step 7 uses only theme extensions), Semantics (Step 8), cancel-on-exit/tap/context-menu/dispose (Steps 3,5,6), verification bar (Task 3), wiki (Task 4). All covered.
- **Type consistency:** `_scheduleTooltip(HttpRequestTabEntity)`, `_showTooltip(HttpRequestTabEntity)`, `_hideTooltip()`, `_TabTooltipCard({required HttpRequestTabEntity tab})`, key `tab_tooltip_<tabId>`, const names `_tabTooltipDelay` / `_tabTooltipMaxWidth` — used identically in lib and test.
- **No placeholders:** every code/command step is complete.
