import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:getman/core/error/failures.dart';
import 'package:getman/features/chaining/domain/usecases/request_rules_usecases.dart';
import 'package:getman/features/chaining/presentation/bloc/rules_event.dart';
import 'package:getman/features/chaining/presentation/bloc/rules_state.dart';

/// Holds the rules for the active request editor's config. Only one rules
/// editor is mounted at a time (the active tab's), so a single loaded entity
/// is sufficient; switching tabs re-dispatches [LoadRules].
class RulesBloc extends Bloc<RulesEvent, RulesState> {
  final GetRequestRulesUseCase getRequestRulesUseCase;
  final SaveRequestRulesUseCase saveRequestRulesUseCase;

  RulesBloc({
    required this.getRequestRulesUseCase,
    required this.saveRequestRulesUseCase,
  }) : super(const RulesState()) {
    on<LoadRules>(_onLoad);
    on<SaveRules>(_onSave);
  }

  Future<void> _onLoad(LoadRules event, Emitter<RulesState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      final rules = await getRequestRulesUseCase(event.configId);
      emit(RulesState(rules: rules));
    } on PersistenceFailure catch (f) {
      debugPrint('LoadRules failed: ${f.message}');
      emit(const RulesState());
    }
  }

  Future<void> _onSave(SaveRules event, Emitter<RulesState> emit) async {
    // Reflect immediately; persist best-effort.
    emit(RulesState(rules: event.rules));
    try {
      await saveRequestRulesUseCase(event.rules);
    } on PersistenceFailure catch (f) {
      debugPrint('SaveRules failed: ${f.message}');
    }
  }
}
