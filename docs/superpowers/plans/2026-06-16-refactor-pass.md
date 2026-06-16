# Refactoring Pass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split the largest/most-tangled files into focused units and remove confirmed code duplication, with zero user-facing behavior change.

**Architecture:** Behavior-preserving moves. Widget clusters move to co-located files in the same feature; reusable pure helpers move to `lib/core/utils/`. Two true dedup extractions get a shared helper. One (`BodyTypeUtils`) carries a behavioral nuance and is done test-first.

**Tech Stack:** Flutter, `flutter_bloc`, `equatable`. Run everything via `fvm flutter ...`.

**Spec:** `docs/superpowers/specs/2026-06-16-refactor-pass-design.md`

---

## Conventions for every task

- **Branch:** `dev` (already checked out).
- **Imports:** always `package:getman/...` (no relative imports).
- **Verification gate (run before each commit):**
  ```bash
  fvm flutter test
  ```
  Then `git commit` — the `.githooks/pre-commit` hook automatically runs
  `dart format` (check), `fvm flutter analyze`, `fvm dart run custom_lint`, and
  `fvm dart run bloc_tools:bloc lint lib`, and **blocks the commit** if any fail.
  If the hook reports a format diff, run `fvm dart format lib test tools` and
  re-stage. Never use `--no-verify`.
- **Extraction definition:** moved code is byte-identical; only the file and the
  class visibility (`_Foo` → `Foo` iff it must be imported) change. If a widget
  reads bloc state or theme, the moved file imports the same packages it used
  before — copy the import list, then let `dart format`/analyze prune unused.
- **Commit message:** `type(scope): summary`, ending with
  `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

---

## Task 1 (B1): Extract duplicated `_firstSchemeName`

**Files:**
- Create: `lib/core/utils/openapi/spec_helpers.dart`
- Modify: `lib/core/utils/openapi/openapi_v3_normalizer.dart` (remove local copy ~270-276)
- Modify: `lib/core/utils/openapi/swagger_v2_normalizer.dart` (remove local copy ~216-222)

- [ ] **Step 1: Create the shared helper**

```dart
// lib/core/utils/openapi/spec_helpers.dart

/// Shared helpers for the OpenAPI v3 / Swagger v2 normalizers.

/// `[{schemeName: [...]}, ...]` → first scheme name, or null if empty/absent.
String? firstSecuritySchemeName(Object? security) {
  if (security is List && security.isNotEmpty) {
    final first = security.first;
    if (first is Map && first.isNotEmpty) return first.keys.first.toString();
  }
  return null;
}
```

- [ ] **Step 2: Update `openapi_v3_normalizer.dart`**

Delete the private `_firstSchemeName` function (the `String? _firstSchemeName(Object? security) {...}` block near line 270). Add the import at the top (in sorted order):

```dart
import 'package:getman/core/utils/openapi/spec_helpers.dart';
```

Replace each call `_firstSchemeName(` with `firstSecuritySchemeName(`.

- [ ] **Step 3: Update `swagger_v2_normalizer.dart`**

Delete its private `_firstSchemeName` (near line 216). Add the same import. Replace each call `_firstSchemeName(` with `firstSecuritySchemeName(`.

- [ ] **Step 4: Verify**

```bash
fvm flutter test test/core/utils/openapi/
```
Expected: all green. Then run the full gate:
```bash
fvm flutter test
```
Expected: PASS (≈611+ tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/utils/openapi/
git commit -m "refactor(openapi): share firstSecuritySchemeName across v2/v3 normalizers

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2 (A1): Extract `RequestManager` from `tabs_bloc.dart`

**Files:**
- Create: `lib/features/tabs/presentation/bloc/request_manager.dart`
- Modify: `lib/features/tabs/presentation/bloc/tabs_bloc.dart` (remove `_RequestManager` ~25-55, import + reference the new class)
- Test: `test/features/tabs/presentation/bloc/request_manager_test.dart`

- [ ] **Step 1: Read the current `_RequestManager`**

Open `lib/features/tabs/presentation/bloc/tabs_bloc.dart` and locate the private
`_RequestManager` class (≈ lines 25-55). Note its exact fields and method
signatures (`register`/`cancel`/`finish`/`cancelAll` over a
`Map<String, NetworkCancelHandle>` — confirm the real names before moving).

- [ ] **Step 2: Create `request_manager.dart` with the moved class**

Move the class verbatim into the new file, renamed `RequestManager` (drop the
leading underscore), with the import it needs:

```dart
// lib/features/tabs/presentation/bloc/request_manager.dart
import 'package:getman/core/network/cancel_handle.dart';

/// Maps an in-flight `tabId` to its [NetworkCancelHandle] so the bloc can cancel
/// a specific tab's request (or all of them on close). Extracted from TabsBloc
/// so the cancellation bookkeeping is unit-testable in isolation.
class RequestManager {
  // ... paste the exact body of the former _RequestManager, unchanged ...
}
```
(Use the real field/method bodies copied from `tabs_bloc.dart`. Verify the
`cancel_handle.dart` import path matches the type used — CLAUDE.md notes
`NetworkCancelHandle` lives in `core/network/`, wrapping pure
`cancel_handle.dart`.)

- [ ] **Step 3: Update `tabs_bloc.dart`**

Delete the `_RequestManager` class. Add the import:
```dart
import 'package:getman/features/tabs/presentation/bloc/request_manager.dart';
```
Change the field declaration/instantiation from `_RequestManager()` to
`RequestManager()` (type and constructor). Leave all call sites otherwise
unchanged.

- [ ] **Step 4: Write a test for `RequestManager`**

```dart
// test/features/tabs/presentation/bloc/request_manager_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:getman/core/network/cancel_handle.dart';
import 'package:getman/features/tabs/presentation/bloc/request_manager.dart';

void main() {
  group('RequestManager', () {
    test('cancel cancels the registered handle for a tab and forgets it', () {
      final manager = RequestManager();
      final handle = NetworkCancelHandle();
      manager.register('tab-1', handle);

      manager.cancel('tab-1');

      expect(handle.isCancelled, isTrue);
      // cancelling again is a no-op (already removed).
      expect(() => manager.cancel('tab-1'), returnsNormally);
    });

    test('finish forgets a handle without cancelling it', () {
      final manager = RequestManager();
      final handle = NetworkCancelHandle();
      manager.register('tab-1', handle);

      manager.finish('tab-1');

      expect(handle.isCancelled, isFalse);
    });

    test('cancelAll cancels every registered handle', () {
      final manager = RequestManager();
      final a = NetworkCancelHandle();
      final b = NetworkCancelHandle();
      manager..register('a', a)..register('b', b);

      manager.cancelAll();

      expect(a.isCancelled, isTrue);
      expect(b.isCancelled, isTrue);
    });
  });
}
```
> NOTE: adjust method names (`register`/`cancel`/`finish`/`cancelAll`) and the
> cancelled-state accessor (`isCancelled`) to the **actual** API found in Step 1.
> If `NetworkCancelHandle` has no public no-arg constructor or `isCancelled`
> getter, use whatever observable signal it exposes (e.g. a `CancelToken`
> wrapper) — read `lib/core/network/cancel_handle.dart` first.

- [ ] **Step 5: Verify**

```bash
fvm flutter test test/features/tabs/presentation/bloc/request_manager_test.dart
fvm flutter test test/features/tabs/
fvm flutter test
```
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/tabs/presentation/bloc/ test/features/tabs/presentation/bloc/request_manager_test.dart
git commit -m "refactor(tabs): extract RequestManager from TabsBloc + unit test

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3 (B3): code-gen internal cleanup

**Files:**
- Modify: `lib/core/utils/code_gen_service.dart`
- Test: `test/core/utils/code_gen_service_test.dart` (existing — must stay green, output byte-identical)

- [ ] **Step 1: Add a private header-writer helper**

In `code_gen_service.dart`, add a private static helper near the other helpers:

```dart
/// Writes `'key': 'value',` lines (single-quoted, escaped) at [indent].
static void _writeHeaders(
  StringBuffer buffer,
  Map<String, String> headers,
  String indent,
) {
  headers.forEach((k, v) => buffer.write("$indent'$k': '${_sq(v)}',\n"));
}
```

- [ ] **Step 2: Replace the three duplicated header loops**

In `_fetch` (~141), `_python` (~186), and `_nodeAxios` (~238), replace the line
`<buf>.forEach((k, v) => <buf>.write("    '$k': '${_sq(v)}',\n"));` with
`_writeHeaders(<buf>, e.headers, '    ');` (keep the exact original indent string
for each call site so output is identical).

- [ ] **Step 3: Unify the escapers**

Replace `_sq` and `_dq` bodies with a shared private escaper, keeping the public
wrapper names so call sites are untouched:

```dart
static String _escape(String v, String quote) => v
    .replaceAll(r'\', r'\\')
    .replaceAll('\n', r'\n')
    .replaceAll(quote, '\\$quote');

static String _sq(String v) => _escape(v, "'");
static String _dq(String v) => _escape(v, '"');
```
> Confirm the original `_sq`/`_dq` replace order before changing — it must match
> exactly (backslash first, then newline, then quote) or escaped output changes.

- [ ] **Step 4: Verify output is identical**

```bash
fvm flutter test test/core/utils/code_gen_service_test.dart
fvm flutter test
```
Expected: PASS with no test edits (proves byte-identical output).

- [ ] **Step 5: Commit**

```bash
git add lib/core/utils/code_gen_service.dart
git commit -m "refactor(codegen): dedupe header writer + quote escapers

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4 (B2): `BodyTypeUtils.applyContentType` (test-first)

**Files:**
- Create: `lib/core/utils/body_type_utils.dart`
- Create: `test/core/utils/body_type_utils_test.dart`
- Test (regression): `test/features/tabs/data/request_serializer_test.dart` (add a binary-no-file case if absent)
- Modify: `lib/features/tabs/data/request_serializer.dart`
- Modify: `lib/core/utils/code_gen_service.dart`

- [ ] **Step 1: Write the failing test for the new helper**

```dart
// test/core/utils/body_type_utils_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:getman/core/domain/entities/body_type.dart';
import 'package:getman/core/utils/body_type_utils.dart';

void main() {
  group('BodyTypeUtils.applyContentType', () {
    test('urlencoded forces the form content-type', () {
      final h = <String, String>{};
      BodyTypeUtils.applyContentType(h, BodyType.urlencoded);
      expect(h['Content-Type'], 'application/x-www-form-urlencoded');
    });

    test('multipart strips content-type (Dio adds the boundary)', () {
      final h = <String, String>{'content-type': 'text/plain'};
      BodyTypeUtils.applyContentType(h, BodyType.multipart);
      expect(h.keys.any((k) => k.toLowerCase() == 'content-type'), isFalse);
    });

    test('binary sets octet-stream only when no custom type is present', () {
      final h = <String, String>{};
      BodyTypeUtils.applyContentType(h, BodyType.binary);
      expect(h['Content-Type'], 'application/octet-stream');
    });

    test('binary respects an existing custom content-type', () {
      final h = <String, String>{'Content-Type': 'image/png'};
      BodyTypeUtils.applyContentType(h, BodyType.binary);
      expect(h['Content-Type'], 'image/png');
    });

    test('none and raw leave headers untouched', () {
      final none = <String, String>{};
      final raw = <String, String>{'Content-Type': 'application/json'};
      BodyTypeUtils.applyContentType(none, BodyType.none);
      BodyTypeUtils.applyContentType(raw, BodyType.raw);
      expect(none, isEmpty);
      expect(raw['Content-Type'], 'application/json');
    });
  });
}
```

- [ ] **Step 2: Run it; expect failure (helper not defined)**

```bash
fvm flutter test test/core/utils/body_type_utils_test.dart
```
Expected: FAIL — `BodyTypeUtils` undefined.

- [ ] **Step 3: Implement the helper**

```dart
// lib/core/utils/body_type_utils.dart
import 'package:getman/core/domain/entities/body_type.dart';
import 'package:getman/core/utils/header_utils.dart';

/// Shared Content-Type rules per [BodyType], used by both the send-path
/// serializer and the code generator so they can't drift.
///
/// NOTE: callers own *when* to apply the binary rule. The send-path serializer
/// only invokes this for binary after confirming a file exists, so a binary
/// request with no file stays header-free (matching prior behavior); the code
/// generator applies it unconditionally because it always shows the header.
class BodyTypeUtils {
  BodyTypeUtils._();

  static void applyContentType(Map<String, String> headers, BodyType type) {
    switch (type) {
      case BodyType.urlencoded:
        HeaderUtils.setHeader(
          headers,
          'Content-Type',
          'application/x-www-form-urlencoded',
        );
      case BodyType.multipart:
        HeaderUtils.removeHeader(headers, 'content-type');
      case BodyType.binary:
        if (!HeaderUtils.hasCustomContentType(headers)) {
          HeaderUtils.setHeader(
            headers,
            'Content-Type',
            'application/octet-stream',
          );
        }
      case BodyType.none:
      case BodyType.raw:
        break;
    }
  }
}
```

- [ ] **Step 4: Run the helper test; expect pass**

```bash
fvm flutter test test/core/utils/body_type_utils_test.dart
```
Expected: PASS.

- [ ] **Step 5: Add/confirm the binary-no-file regression test on the serializer**

In `test/features/tabs/data/request_serializer_test.dart`, ensure a test asserts:
`buildBody` with `bodyType: BodyType.binary` and `bodyFilePath: null` (or empty)
returns `null` **and** leaves Content-Type unset.

```dart
test('binary body with no file leaves Content-Type unset and returns null', () async {
  final headers = <String, String>{};
  final config = HttpRequestConfigEntity(
    id: 'x',
    bodyType: BodyType.binary,
    bodyFilePath: null,
  ); // fill required fields per the entity's constructor
  final body = await RequestSerializer.buildBody(
    config: config,
    headers: headers,
    envVars: const {},
  );
  expect(body, isNull);
  expect(headers.keys.any((k) => k.toLowerCase() == 'content-type'), isFalse);
});
```
> Adjust the `HttpRequestConfigEntity(...)` constructor args to the real required
> fields. Run it BEFORE the refactor and confirm it passes (it pins current
> behavior).

```bash
fvm flutter test test/features/tabs/data/request_serializer_test.dart
```
Expected: PASS (pre-refactor baseline).

- [ ] **Step 6: Refactor `code_gen_service.dart` `_effective` to call the helper**

Replace the inline `switch (config.bodyType) { ...content-type... }` block
(~72-92) with:
```dart
BodyTypeUtils.applyContentType(headers, config.bodyType);
```
Add the import `package:getman/core/utils/body_type_utils.dart`.

- [ ] **Step 7: Refactor `request_serializer.dart` `buildBody` — preserve the binary guard**

- urlencoded branch: replace the inline `HeaderUtils.setHeader(... form-urlencoded)`
  with `BodyTypeUtils.applyContentType(headers, BodyType.urlencoded);` (then keep
  building + returning the field map).
- multipart branch: replace the inline `HeaderUtils.removeHeader(headers, 'content-type')`
  with `BodyTypeUtils.applyContentType(headers, BodyType.multipart);`.
- binary branch: **keep the `path == null || path.isEmpty` early return first**;
  only after confirming a real path, replace the inner
  `if (!hasCustomContentType) setHeader(...octet-stream)` with
  `BodyTypeUtils.applyContentType(headers, BodyType.binary);`.

Add the import. Do NOT move the helper call above the path guard.

- [ ] **Step 8: Verify nothing regressed**

```bash
fvm flutter test test/core/utils/ test/features/tabs/
fvm flutter test
```
Expected: PASS — especially the binary-no-file test from Step 5 stays green.

- [ ] **Step 9: Commit**

```bash
git add lib/core/utils/body_type_utils.dart test/core/utils/body_type_utils_test.dart lib/features/tabs/data/request_serializer.dart lib/core/utils/code_gen_service.dart test/features/tabs/data/request_serializer_test.dart
git commit -m "refactor(body): share BodyTypeUtils.applyContentType between serializer and codegen

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5 (A4): Split `rules_tab_view.dart`

**Files:**
- Create: `lib/features/chaining/presentation/widgets/extraction_rule_row.dart`
- Create: `lib/features/chaining/presentation/widgets/assertion_rule_row.dart`
- Create: `lib/features/chaining/presentation/widgets/rule_card.dart`
- Modify: `lib/features/chaining/presentation/widgets/rules_tab_view.dart`
- Test: existing chaining widget tests stay green.

- [ ] **Step 1: Read `rules_tab_view.dart`**

Identify `_ExtractionRuleRow` (+state), `_AssertionRow` (+state), `_RuleCard`,
`_Header`, `_AddButton`. Note which symbols they reference from the parent
(callbacks, entities, bloc events) — these become public constructor params.

- [ ] **Step 2: Move `_RuleCard` → `rule_card.dart`**

Create the file; paste `_RuleCard` renamed `RuleCard` (public), with its imports.
In `rules_tab_view.dart` import it and replace `_RuleCard(` usages with `RuleCard(`.

```bash
fvm flutter test test/features/chaining/ && git add -A && git commit -m "refactor(chaining): extract RuleCard chrome

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 3: Move extraction row → `extraction_rule_row.dart`**

Paste `_ExtractionRuleRow` + its `State` into the new file, renamed
`ExtractionRuleRow` (public). Keep the controller-lifetime + emit-on-change logic
verbatim. Import `RuleCard` if it uses it. In `rules_tab_view.dart` import the new
file and replace `_ExtractionRuleRow(` with `ExtractionRuleRow(`.

```bash
fvm flutter test test/features/chaining/ && git add -A && git commit -m "refactor(chaining): extract ExtractionRuleRow widget

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 4: Move assertion row → `assertion_rule_row.dart`**

Same procedure for `_AssertionRow` (+state) → `AssertionRuleRow`. Keep the
conditional-field logic verbatim.

```bash
fvm flutter test test/features/chaining/ && git add -A && git commit -m "refactor(chaining): extract AssertionRuleRow widget

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 5: Final verify**

```bash
fvm flutter test
```
Expected: PASS. `rules_tab_view.dart` now holds only the list + load state +
`_Header`/`_AddButton` (leave those private — single-use here).

---

## Task 6 (A5): Split `spec_import_dialog.dart`

**Files:**
- Create: `lib/features/collections/presentation/widgets/spec_import_source.dart`
- Create: `lib/features/collections/presentation/widgets/spec_import_preview.dart`
- Modify: `lib/features/collections/presentation/widgets/spec_import_dialog.dart`
- Test: existing collections/import tests stay green.

- [ ] **Step 1: Read the dialog**

Identify `_SourceSelector`, `_SourceButton` (source picker) and `_ImportPreview`,
`_FolderRow`, `_LeafRow`, `_ErrorText` (preview tree). Note callbacks threaded
from `SpecImportDialog` (selection toggles, source-change, fetch).

- [ ] **Step 2: Extract source picker → `spec_import_source.dart`**

Move `_SourceSelector` + `_SourceButton` (and any small source-input widget)
into the file, renaming the entry widget public (`SpecImportSource`). Pass the
current source + `onSourceChanged` etc. as constructor params. Wire it back in.

```bash
fvm flutter test test/features/collections/ && git add -A && git commit -m "refactor(import): extract spec-import source picker

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 3: Extract preview → `spec_import_preview.dart`**

Move `_ImportPreview`, `_FolderRow`, `_LeafRow`, `_ErrorText` into the file;
rename the entry widget public (`SpecImportPreview`). Thread the selection state
+ toggle callbacks via constructor params (keep the tri-state semantics identical).
Wire it back in.

```bash
fvm flutter test test/features/collections/ && git add -A && git commit -m "refactor(import): extract spec-import preview tree

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 4: Final verify**

```bash
fvm flutter test
```
Expected: PASS. `spec_import_dialog.dart` retains only the state machine
(source → parse → preview → dispatch); it stays bloc-agnostic.

---

## Task 7 (A3): Split `response_body_view.dart`

**Files:**
- Create: `lib/features/tabs/presentation/widgets/response/response_body_controls.dart`
- Create: `lib/features/tabs/presentation/widgets/response/response_large_body_view.dart`
- Modify: `lib/features/tabs/presentation/widgets/response/response_body_view.dart`
- Test: existing response widget tests stay green.

- [ ] **Step 1: Read the file**

Map the four button builders (copy / save-to-file / compare / save-as-example)
with their `BlocBuilder` gates and the `_exampleTargets`/`_historyTargets`
helpers; the large-mode builder (`_buildLargeMode` + banner); the `_syncBody`
pretty/raw pipeline; and `_PrettyRawToggle`.

- [ ] **Step 2: Extract the large-body view → `response_large_body_view.dart`**

Move the large-mode UI (banner + plain-text/editor fallback) into a widget
(`ResponseLargeBodyView`) taking the body string + the relevant flags/callbacks
as params. Preserve the `kLargeResponseViewerChars` /
`kResponseBodyTooLargePlaceholder` handling and the
`// ignore: avoid_hardcoded_brand_colors` dynamic-contrast line verbatim. Wire
it back into `response_body_view.dart`.

```bash
fvm flutter test test/features/tabs/ && git add -A && git commit -m "refactor(response): extract large-body viewer

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 3: Extract the controls → `response_body_controls.dart`**

Move the copy / save / compare / save-as-example button builders and their
`_exampleTargets`/`_historyTargets` helpers into a widget
(`ResponseBodyControls`) taking `tabId` + the copyable-body accessor. Keep each
button's existing `buildWhen` gate unchanged. Wire it back in.

```bash
fvm flutter test test/features/tabs/ && git add -A && git commit -m "refactor(response): extract response-body action controls

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 4: Final verify**

```bash
fvm flutter test
```
Expected: PASS. `response_body_view.dart` keeps the main widget, `_syncBody`
pipeline, and `_PrettyRawToggle`. Manually sanity-check (if running the app):
large body, pretty/raw toggle, compare picker, save-as-example.

---

## Task 8 (A2): Split `collections_list.dart` (largest — last)

**Files:**
- Create: `lib/features/collections/presentation/widgets/collection_node_row.dart`
- Create: `lib/features/collections/presentation/widgets/collection_node_menu.dart`
- Create: `lib/features/collections/presentation/widgets/example_row.dart`
- Create: `lib/features/collections/presentation/widgets/example_menu.dart`
- Modify: `lib/features/collections/presentation/widgets/collections_list.dart`
- Test: existing collections widget tests stay green (esp. the H2 expansion test).

> **Critical invariants — must NOT regress:**
> - H2: `_expandedIds` (`Set<String>`) expansion ownership + reseeding into
>   `TreeViewNode(expanded:)` stays entirely in `collections_list.dart`.
> - Drag-and-drop via `Draggable<String>`/`DragTarget<String>` carrying `node.id`.
> - `ValueKey(node.id)` on tree tiles; fixed `AppLayout.treeRowExtent`.
> - `_TreeItem` node-vs-example union behavior; tapping an example opens an
>   unlinked tab via `AddTab(response: …)`.
> Extracted row widgets must stay **dumb**: they receive data + callbacks; the
> coordinator (`collections_list.dart`) keeps all state and bloc access.

- [ ] **Step 1: Read `collections_list.dart` end-to-end**

Identify `_CollectionNodeWidget` (+state), `_NodeContextMenu`, `_ExampleRow`
(+state), `_ExampleMenu`. For each, list every value/callback it reads from the
parent — those become constructor params (e.g. `node`, `depth`, `isExpanded`,
`onToggle`, `onRename`, `onDelete`, `onFavorite`, `onExport`, `onOpenExample`).

- [ ] **Step 2: Extract the node context menu → `collection_node_menu.dart`**

Move `_NodeContextMenu` → public `CollectionNodeMenu`, params = the node + the
action callbacks it currently invokes. It must reach those actions only via the
passed callbacks (no new bloc reads beyond what it already did). Wire back in.

```bash
fvm flutter test test/features/collections/ && git add -A && git commit -m "refactor(collections): extract CollectionNodeMenu

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 3: Extract the example menu → `example_menu.dart`**

Move `_ExampleMenu` → public `ExampleMenu` (rename/delete example callbacks).
Wire back in.

```bash
fvm flutter test test/features/collections/ && git add -A && git commit -m "refactor(collections): extract ExampleMenu

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 4: Extract the example row → `example_row.dart`**

Move `_ExampleRow` (+state) → public `ExampleRow`. It renders one saved example
and calls `onOpen`/menu callbacks. Import `ExampleMenu`. Wire back in.

```bash
fvm flutter test test/features/collections/ && git add -A && git commit -m "refactor(collections): extract ExampleRow

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 5: Extract the node row → `collection_node_row.dart`**

Move `_CollectionNodeWidget` (+state) → public `CollectionNodeRow`. This is the
hover/drag row; it receives `isExpanded` + `onToggle` (it must NOT own expansion
state — that stays in the coordinator). Import `CollectionNodeMenu`. Keep the
`Draggable`/`DragTarget` wiring and `ValueKey(node.id)` intact. Wire back in.

```bash
fvm flutter test test/features/collections/ && git add -A && git commit -m "refactor(collections): extract CollectionNodeRow

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 6: Final verify (full suite + H2 specifically)**

```bash
fvm flutter test test/features/collections/
fvm flutter test
```
Expected: PASS, including the H2 test (expand a folder, mutate a sibling, assert
the folder stays expanded). `collections_list.dart` is now the coordinator only:
search debounce, `_expandedIds`, tree build, import coordination, root drop,
empty state.

---

## Self-Review (completed during authoring)

- **Spec coverage:** A1–A5 and B1–B3 each map to Tasks 2,8,7,5,6 and 1,4,3
  respectively. Perf is a documented no-op (no task) — matches spec.
- **Placeholders:** none. Code-bearing steps include code; the few "confirm the
  real API" notes point at exact files to read (cancel_handle, entity
  constructors) because those signatures must be read live, not guessed.
- **Type consistency:** new public names are used consistently — `RequestManager`,
  `BodyTypeUtils.applyContentType`, `firstSecuritySchemeName`, `RuleCard`,
  `ExtractionRuleRow`, `AssertionRuleRow`, `SpecImportSource`,
  `SpecImportPreview`, `ResponseLargeBodyView`, `ResponseBodyControls`,
  `CollectionNodeRow`, `CollectionNodeMenu`, `ExampleRow`, `ExampleMenu`.

## Order & rationale

Tasks run 1→8 (cheap/safe dedup first, largest widget split last). Each task —
and each sub-commit within Tasks 5–8 — leaves the suite green and the analysis
stack clean before moving on.
