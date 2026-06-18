// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'panel_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PanelModelAdapter extends TypeAdapter<PanelModel> {
  @override
  final typeId = 12;

  @override
  PanelModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PanelModel(
      name: fields[1] as String,
      orderedTabIds: (fields[2] as List).cast<String>(),
      activeTabId: fields[3] as String,
      id: fields[0] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, PanelModel obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.orderedTabIds)
      ..writeByte(3)
      ..write(obj.activeTabId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PanelModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
