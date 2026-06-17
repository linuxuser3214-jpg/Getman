import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:patrol_finders/patrol_finders.dart';

import '../support/actions.dart';
import '../support/app_harness.dart';

Future<void> _saveRequestAs(PatrolTester $, String name) async {
  await $(const ValueKey('save_request_button')).tap();
  await enterPromptText($, name);
  await $('SAVE').tap();
  await $.pumpAndSettle();
}

Future<void> _newFolder(PatrolTester $, String name) async {
  await $(const ValueKey('new_folder_button')).tap();
  await enterPromptText($, name);
  await $('CREATE').tap();
  await $.pumpAndSettle();
}

/// Opens the (single) node's desktop context menu via its more-vert button.
Future<void> _openNodeMenu(PatrolTester $) async {
  await $(find.byIcon(Icons.more_vert)).tap();
  await $.pumpAndSettle();
}

/// Deep collections coverage: rename, favorite, description (set + clear),
/// delete folder, nested subfolder, and a drag-and-drop re-parent.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  patrolWidgetTest('renames a saved request', ($) async {
    await bootGetman($);
    await _saveRequestAs($, 'Orig Name');

    await _openNodeMenu($);
    await $('RENAME').tap();
    await enterPromptText($, 'Renamed Node');
    await $('SAVE').tap();
    await $.pumpAndSettle();

    expect($('Renamed Node'), findsWidgets);
  });

  patrolWidgetTest('favorites a folder', ($) async {
    await bootGetman($);
    await _newFolder($, 'Faves');

    await _openNodeMenu($);
    await $('FAVORITE').tap();
    await $.pumpAndSettle();

    expect($('Added to favorites'), findsWidgets);
    expect($(find.byIcon(Icons.star)), findsWidgets);
  });

  patrolWidgetTest('sets then clears a node description', ($) async {
    await bootGetman($);
    await _saveRequestAs($, 'Documented');

    await _openNodeMenu($);
    await $('EDIT DESCRIPTION').tap();
    await enterPromptText($, 'some notes about this request');
    await $('SAVE').tap();
    await $.pumpAndSettle();
    expect($('Description updated'), findsWidgets);

    // Clear it (empty is allowed for descriptions).
    await _openNodeMenu($);
    await $('EDIT DESCRIPTION').tap();
    await enterPromptText($, '');
    await $('SAVE').tap();
    await $.pumpAndSettle();
    expect($('Description updated'), findsWidgets);
  });

  patrolWidgetTest('deletes a folder via its menu (confirm)', ($) async {
    await bootGetman($);
    await _newFolder($, 'Trash Bin');
    expect($('Trash Bin'), findsWidgets);

    await _openNodeMenu($);
    await $('DELETE').tap(); // menu item
    expect($('Delete folder?'), findsWidgets); // confirm dialog
    await $('DELETE').tap(); // confirm
    await $.pumpAndSettle();

    expect($(find.byIcon(Icons.more_vert)), findsNothing);
  });

  patrolWidgetTest('adds a nested subfolder', ($) async {
    await bootGetman($);
    await _newFolder($, 'Parent');

    await _openNodeMenu($);
    await $('ADD SUBFOLDER').tap();
    await enterPromptText($, 'Child');
    await $('ADD').tap();
    await $.pumpAndSettle();
    expect($('Folder "Child" created'), findsWidgets);

    // Expand the parent to reveal the child row.
    await $(find.byIcon(Icons.keyboard_arrow_right)).first.tap();
    await $.pumpAndSettle();
    expect($('Child'), findsWidgets);
  });

  patrolWidgetTest('drag-and-drop re-parents a folder', ($) async {
    await bootGetman($);
    // Two root folders (folder names show only in the tree → unambiguous).
    await _newFolder($, 'Box');
    await _newFolder($, 'Loose');
    expect($('Box'), findsWidgets);
    expect($('Loose'), findsWidgets);

    // Drag 'Loose' onto 'Box' to nest it.
    final from = $.tester.getCenter(find.text('Loose'));
    final to = $.tester.getCenter(find.text('Box'));
    final gesture = await $.tester.startGesture(from);
    await $.tester.pump(const Duration(milliseconds: 50));
    // Move in a few steps so the DragTarget registers the hover.
    for (var i = 1; i <= 4; i++) {
      await gesture.moveTo(Offset.lerp(from, to, i / 4)!);
      await $.tester.pump(const Duration(milliseconds: 30));
    }
    await gesture.up();
    await $.pumpAndSettle();

    // 'Loose' is now nested under 'Box': collapsed by default, revealed on
    // expand.
    await $(find.byIcon(Icons.keyboard_arrow_right)).first.tap();
    await $.pumpAndSettle();
    expect($('Loose'), findsWidgets);
  });
}
