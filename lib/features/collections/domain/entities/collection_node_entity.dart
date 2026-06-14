import 'package:equatable/equatable.dart';
import 'package:getman/core/domain/entities/request_config_entity.dart';

class CollectionNodeEntity extends Equatable {
  final String id;
  final String name;
  final bool isFolder;
  final List<CollectionNodeEntity> children;
  final HttpRequestConfigEntity? config;
  final bool isFavorite;

  /// Free-text notes for a folder or request. Null/empty means "no description".
  final String? description;

  const CollectionNodeEntity({
    required this.id,
    required this.name,
    this.isFolder = true,
    this.children = const [],
    this.config,
    this.isFavorite = false,
    this.description,
  });

  CollectionNodeEntity copyWith({
    String? name,
    bool? isFolder,
    List<CollectionNodeEntity>? children,
    HttpRequestConfigEntity? config,
    bool? isFavorite,
    String? description,
  }) {
    return CollectionNodeEntity(
      id: id,
      name: name ?? this.name,
      isFolder: isFolder ?? this.isFolder,
      children: children ?? this.children,
      config: config ?? this.config,
      isFavorite: isFavorite ?? this.isFavorite,
      description: description ?? this.description,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    isFolder,
    children,
    config,
    isFavorite,
    description,
  ];
}
