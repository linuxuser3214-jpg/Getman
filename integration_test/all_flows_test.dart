import 'package:integration_test/integration_test.dart';

import 'flows/json_fold_test.dart' as json_fold;
import 'flows/request_send_test.dart' as request_send;
import 'flows/smoke_test.dart' as smoke;
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

  smoke.main();
  request_send.main();
  json_fold.main();
  variable_substitution.main();
}
