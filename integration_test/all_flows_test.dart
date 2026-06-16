import 'package:integration_test/integration_test.dart';

import 'flows/auth_test.dart' as auth;
import 'flows/chaining_rules_test.dart' as chaining_rules;
import 'flows/code_gen_test.dart' as code_gen;
import 'flows/collections_test.dart' as collections;
import 'flows/command_palette_test.dart' as command_palette;
import 'flows/cookies_test.dart' as cookies;
import 'flows/environments_test.dart' as environments;
import 'flows/history_test.dart' as history;
import 'flows/json_fold_test.dart' as json_fold;
import 'flows/realtime_sse_test.dart' as realtime_sse;
import 'flows/realtime_ws_test.dart' as realtime_ws;
import 'flows/request_config_test.dart' as request_config;
import 'flows/request_send_test.dart' as request_send;
import 'flows/response_views_test.dart' as response_views;
import 'flows/settings_test.dart' as settings;
import 'flows/smoke_test.dart' as smoke;
import 'flows/tabs_test.dart' as tabs;
import 'flows/variable_substitution_test.dart' as variable_substitution;

/// Aggregator: runs every flow in a **single** `flutter test` invocation, so
/// the macOS app is built and launched **once** and all cases run sequentially
/// in that one process (instead of rebuilding per file).
///
/// This is the entry point `run_macos.sh` uses. Each imported flow still has
/// its own `main()`, so you can also run a single flow on its own during
/// development (`fvm flutter test integration_test/flows/<name>_test.dart`).
///
/// To add a flow: create `flows/<name>_test.dart`, then import it here and call
/// its `main()` below.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Core round-trip + rendering.
  smoke.main();
  request_send.main();
  json_fold.main();
  variable_substitution.main();

  // Feature flows.
  tabs.main();
  request_config.main();
  history.main();
  collections.main();
  environments.main();
  chaining_rules.main();
  cookies.main();
  realtime_ws.main();
  realtime_sse.main();
  auth.main();
  code_gen.main();
  settings.main();
  response_views.main();
  command_palette.main();
}
