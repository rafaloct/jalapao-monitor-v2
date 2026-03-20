// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'visit.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class VisitAdapter extends TypeAdapter<Visit> {
  @override
  final int typeId = 0;

  @override
  Visit read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Visit(
      id: fields[0] as String,
      paxQty: fields[1] as int,
      status: fields[2] as String,
      arrivalTime: fields[3] as DateTime,
      entryTime: fields[4] as DateTime?,
      exitTime: fields[5] as DateTime?,
      isSynced: fields[6] as bool,
      atrativo: fields[7] as String,
      tabletId: fields[8] as String,
      groupId: fields[9] as String,
      capacityLimit: fields[10] as int,
      groupName: fields[11] as String?,
      originCity: fields[12] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Visit obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.paxQty)
      ..writeByte(2)
      ..write(obj.status)
      ..writeByte(3)
      ..write(obj.arrivalTime)
      ..writeByte(4)
      ..write(obj.entryTime)
      ..writeByte(5)
      ..write(obj.exitTime)
      ..writeByte(6)
      ..write(obj.isSynced)
      ..writeByte(7)
      ..write(obj.atrativo)
      ..writeByte(8)
      ..write(obj.tabletId)
      ..writeByte(9)
      ..write(obj.groupId)
      ..writeByte(10)
      ..write(obj.capacityLimit)
      ..writeByte(11)
      ..write(obj.groupName)
      ..writeByte(12)
      ..write(obj.originCity);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VisitAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
