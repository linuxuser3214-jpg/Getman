import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getman/core/theme/themes/brutalist/brutalist_theme.dart';
import 'package:getman/features/updates/domain/entities/release_info.dart';
import 'package:getman/features/updates/domain/repositories/update_repository.dart';
import 'package:getman/features/updates/presentation/update_controller.dart';
import 'package:getman/features/updates/presentation/update_phase.dart';
import 'package:getman/features/updates/presentation/widgets/update_dialog.dart';
import 'package:provider/provider.dart';

class _FakeUpdateRepository implements UpdateRepository {
  @override
  Future<ReleaseInfo?> fetchLatestRelease(UpdatePlatform p) async => null;
}

void main() {
  testWidgets('renders version line + all three actions', (t) async {
    await t.pumpWidget(
      MaterialApp(
        theme: brutalistTheme(Brightness.light),
        home: Builder(
          builder: (context) => const Scaffold(
            body: UpdateDialog(
              latestVersion: '1.1.0',
              currentVersion: '1.0.0',
              changelog: 'New things',
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('1.1.0'), findsWidgets);
    expect(find.byKey(const ValueKey('update_skip_button')), findsOneWidget);
    expect(find.byKey(const ValueKey('update_later_button')), findsOneWidget);
    expect(find.byKey(const ValueKey('update_now_button')), findsOneWidget);
  });

  testWidgets('shows downloading spinner when phase is downloading', (t) async {
    final controller = UpdateController(_FakeUpdateRepository());

    await t.pumpWidget(
      MaterialApp(
        theme: brutalistTheme(Brightness.light),
        home: ChangeNotifierProvider<UpdateController>.value(
          value: controller,
          child: Builder(
            builder: (context) => const Scaffold(
              body: UpdateDialog(
                latestVersion: '1.1.0',
                currentVersion: '1.0.0',
                changelog: null,
              ),
            ),
          ),
        ),
      ),
    );

    // Spinner should not be visible before downloading starts.
    expect(find.byType(CircularProgressIndicator), findsNothing);

    controller.updateFromGate(phase: UpdatePhase.downloading);
    await t.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Downloading…'), findsOneWidget);
  });
}
