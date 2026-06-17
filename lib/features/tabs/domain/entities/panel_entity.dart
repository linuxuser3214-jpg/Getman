import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:getman/features/tabs/domain/entities/request_tab_entity.dart';

extension PanelListLookup on Iterable<PanelEntity> {
  /// Shorthand for `firstWhereOrNull((p) => p.id == id)`.
  PanelEntity? byId(String id) => firstWhereOrNull((p) => p.id == id);
}

/// A virtual-desktop workspace grouping request tabs. Only the active panel's
/// tabs are shown in the tab strip. Invariant (enforced in TabsBloc): [tabs]
/// is never empty and [activeTabId] always names a tab in [tabs].
class PanelEntity extends Equatable {
  const PanelEntity({
    required this.id,
    required this.name,
    required this.tabs,
    required this.activeTabId,
  });

  final String id;
  final String name;
  final List<HttpRequestTabEntity> tabs;
  final String activeTabId;

  PanelEntity copyWith({
    String? id,
    String? name,
    List<HttpRequestTabEntity>? tabs,
    String? activeTabId,
  }) {
    return PanelEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      tabs: tabs ?? this.tabs,
      activeTabId: activeTabId ?? this.activeTabId,
    );
  }

  @override
  List<Object?> get props => [id, name, tabs, activeTabId];
}
