import 'package:getman/features/chaining/domain/entities/request_rules_entity.dart';
import 'package:getman/features/chaining/domain/repositories/request_rules_repository.dart';

class GetRequestRulesUseCase {
  final RequestRulesRepository repository;
  GetRequestRulesUseCase(this.repository);

  Future<RequestRulesEntity> call(String configId) => repository.getRules(configId);
}

class SaveRequestRulesUseCase {
  final RequestRulesRepository repository;
  SaveRequestRulesUseCase(this.repository);

  Future<void> call(RequestRulesEntity rules) => repository.saveRules(rules);
}
