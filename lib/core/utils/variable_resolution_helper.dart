import 'package:equatable/equatable.dart';
import 'package:getman/core/utils/environment_resolver.dart';

/// How a `{{var}}` token resolves against the active environment.
enum VariableValueKind { resolved, secret, dynamicValue, unresolved }

/// The classification of a single variable name for the hover tooltip.
class ResolvedVariable extends Equatable {
  const ResolvedVariable({
    required this.name,
    required this.kind,
    this.value,
    this.environmentName,
  });

  final String name;
  final VariableValueKind kind;

  /// The value to display: the resolved string for resolved/secret kinds, a
  /// freshly-generated sample for dynamicValue, or null for unresolved.
  final String? value;

  /// Active environment display name; null when no environment is active.
  final String? environmentName;

  @override
  List<Object?> get props => [name, kind, value, environmentName];
}

/// Classifies a variable name against the active environment. Pure Dart — no
/// Flutter, no Hive. Lives beside [EnvironmentResolver] in core/utils so core
/// widgets can depend on it without reaching into a feature.
class VariableResolutionHelper {
  const VariableResolutionHelper._();

  static ResolvedVariable classify({
    required String name,
    required Map<String, String> variables,
    required Set<String> secretKeys,
    required String? environmentName,
  }) {
    // An env var always wins over a dynamic name of the same spelling, matching
    // EnvironmentResolver.resolve.
    if (variables.containsKey(name)) {
      return ResolvedVariable(
        name: name,
        kind: secretKeys.contains(name)
            ? VariableValueKind.secret
            : VariableValueKind.resolved,
        value: variables[name],
        environmentName: environmentName,
      );
    }
    if (EnvironmentResolver.isDynamic(name)) {
      return ResolvedVariable(
        name: name,
        kind: VariableValueKind.dynamicValue,
        value: EnvironmentResolver.resolveDynamic(name),
        environmentName: environmentName,
      );
    }
    return ResolvedVariable(
      name: name,
      kind: VariableValueKind.unresolved,
      environmentName: environmentName,
    );
  }
}
