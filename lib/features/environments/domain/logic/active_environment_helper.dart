import 'package:getman/features/environments/domain/entities/environment_entity.dart';

class ActiveEnvironmentHelper {
  static Map<String, String> variablesFor(
    List<EnvironmentEntity> environments,
    String? activeId,
  ) => activeEnvironment(environments, activeId)?.variables ?? const {};

  static EnvironmentEntity? activeEnvironment(
    List<EnvironmentEntity> environments,
    String? activeId,
  ) {
    if (activeId == null) return null;
    for (final env in environments) {
      if (env.id == activeId) return env;
    }
    return null;
  }
}
