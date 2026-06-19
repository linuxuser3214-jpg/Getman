import 'package:equatable/equatable.dart';

/// What happened to a request, in motion terms. Pure Dart (no Flutter import)
/// so it can flow through TabsBloc / TabsState without tripping bloc_lint's
/// avoid_flutter_imports.
enum ThemeReactionKind {
  sendStarted,
  success,
  clientError,
  serverError,
  networkError,
  cancelled,
}

class ThemeReaction extends Equatable {
  const ThemeReaction({required this.kind, this.statusCode, this.durationMs});

  final ThemeReactionKind kind;
  final int? statusCode;
  final int? durationMs;

  /// Maps an HTTP status to a reaction kind. 200..399 success, 400..499
  /// clientError, 500..599 serverError, anything else (0, sub-200, 6xx) is
  /// treated as a network-level failure.
  static ThemeReactionKind kindForStatus(int statusCode) {
    if (statusCode >= 200 && statusCode < 400) return ThemeReactionKind.success;
    if (statusCode >= 400 && statusCode < 500) {
      return ThemeReactionKind.clientError;
    }
    if (statusCode >= 500 && statusCode < 600) {
      return ThemeReactionKind.serverError;
    }
    return ThemeReactionKind.networkError;
  }

  bool get isError =>
      kind == ThemeReactionKind.clientError ||
      kind == ThemeReactionKind.serverError ||
      kind == ThemeReactionKind.networkError;

  @override
  List<Object?> get props => [kind, statusCode, durationMs];
}
