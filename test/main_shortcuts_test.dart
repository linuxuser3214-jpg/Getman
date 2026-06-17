import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getman/core/navigation/intents.dart';
import 'package:getman/main.dart';

void main() {
  // SingleActivator has no value equality (Shortcuts indexes by trigger +
  // accepts, not map-key ==), so scan the entries by trigger/modifiers rather
  // than looking up with a freshly-constructed activator.
  JumpToTabIntent? jumpFor(
    LogicalKeyboardKey key, {
    bool meta = false,
    bool control = false,
  }) {
    for (final entry in appShortcuts.entries) {
      final a = entry.key;
      if (a is SingleActivator &&
          a.trigger == key &&
          a.meta == meta &&
          a.control == control &&
          entry.value is JumpToTabIntent) {
        return entry.value as JumpToTabIntent;
      }
    }
    return null;
  }

  group('appShortcuts', () {
    test('Ctrl+Tab / Ctrl+Shift+Tab map to next / previous tab', () {
      expect(
        appShortcuts[const SingleActivator(
          LogicalKeyboardKey.tab,
          control: true,
        )],
        isA<NextTabIntent>(),
      );
      expect(
        appShortcuts[const SingleActivator(
          LogicalKeyboardKey.tab,
          control: true,
          shift: true,
        )],
        isA<PrevTabIntent>(),
      );
    });

    test('Cmd/Ctrl+1..9 map to JumpToTabIntent with a 0-based index', () {
      expect(jumpFor(LogicalKeyboardKey.digit1, meta: true)?.index, 0);
      expect(jumpFor(LogicalKeyboardKey.digit1, control: true)?.index, 0);
      expect(jumpFor(LogicalKeyboardKey.digit9, meta: true)?.index, 8);
      expect(jumpFor(LogicalKeyboardKey.digit9, control: true)?.index, 8);
    });

    test('existing bindings still resolve', () {
      expect(
        appShortcuts[const SingleActivator(
          LogicalKeyboardKey.keyN,
          meta: true,
        )],
        isA<NewTabIntent>(),
      );
    });

    test('Cmd/Ctrl+E map to SwitchEnvironmentIntent', () {
      expect(
        appShortcuts[const SingleActivator(
          LogicalKeyboardKey.keyE,
          meta: true,
        )],
        isA<SwitchEnvironmentIntent>(),
      );
      expect(
        appShortcuts[const SingleActivator(
          LogicalKeyboardKey.keyE,
          control: true,
        )],
        isA<SwitchEnvironmentIntent>(),
      );
    });

    test('appShortcuts includes panel bindings', () {
      bool hasBinding<T extends Intent>(
        LogicalKeyboardKey key, {
        bool control = false,
        bool meta = false,
        bool shift = false,
      }) => appShortcuts.entries.any(
        (e) =>
            e.key is SingleActivator &&
            (e.key as SingleActivator).trigger == key &&
            (e.key as SingleActivator).control == control &&
            (e.key as SingleActivator).meta == meta &&
            (e.key as SingleActivator).shift == shift &&
            e.value is T,
      );

      // Ctrl+Shift+N and Cmd+Shift+N → NewPanelIntent.
      expect(
        hasBinding<NewPanelIntent>(
          LogicalKeyboardKey.keyN,
          control: true,
          shift: true,
        ),
        isTrue,
        reason: 'Ctrl+Shift+N must be bound to NewPanelIntent',
      );
      expect(
        hasBinding<NewPanelIntent>(
          LogicalKeyboardKey.keyN,
          meta: true,
          shift: true,
        ),
        isTrue,
        reason: 'Cmd+Shift+N must be bound to NewPanelIntent',
      );
      // Bracket bindings for next/prev panel.
      expect(
        hasBinding<NextPanelIntent>(
          LogicalKeyboardKey.bracketRight,
          control: true,
          shift: true,
        ),
        isTrue,
        reason: 'Ctrl+Shift+] must be bound to NextPanelIntent',
      );
      expect(
        hasBinding<PrevPanelIntent>(
          LogicalKeyboardKey.bracketLeft,
          control: true,
          shift: true,
        ),
        isTrue,
        reason: 'Ctrl+Shift+[ must be bound to PrevPanelIntent',
      );
      // 9 JumpToPanelIntent entries per modifier = 18 total.
      expect(
        appShortcuts.values.whereType<JumpToPanelIntent>().length,
        18,
        reason: '9 control + 9 meta JumpToPanelIntent bindings expected',
      );
    });
  });
}
