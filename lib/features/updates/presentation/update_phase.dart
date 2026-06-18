/// Web-safe mirror of `updat`'s `UpdatStatus`. Only `update_gate_io.dart` maps
/// between the two; everything else (controller, dialog, settings) uses this so
/// the web build never imports `updat`/`dart:io`.
enum UpdatePhase {
  idle,
  checking,
  upToDate,
  available,
  downloading,
  readyToInstall,
  error,
  dismissed,
}
