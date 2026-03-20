// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'place_visit.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PlaceVisitAdapter extends TypeAdapter<PlaceVisit> {
  @override
  final int typeId = 2;

  @override
  PlaceVisit read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PlaceVisit(
      id: fields[0] as String,
      placeId: fields[1] as String,
      paxQty: fields[2] as int,
      arrivalTime: fields[3] as DateTime,
      exitTime: fields[4] as DateTime?,
      status: fields[5] as String,
      isSynced: fields[6] as bool,
      photoPath: fields[7] as String?,
      tabletId: fields[8] as String?,
      notes: fields[9] as String?,
      entryTime: fields[10] as DateTime?,
      groupName: fields[11] as String?,
      originCity: fields[12] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, PlaceVisit obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.placeId)
      ..writeByte(2)
      ..write(obj.paxQty)
      ..writeByte(3)
      ..write(obj.arrivalTime)
      ..writeByte(4)
      ..write(obj.exitTime)
      ..writeByte(5)
      ..write(obj.status)
      ..writeByte(6)
      ..write(obj.isSynced)
      ..writeByte(7)
      ..write(obj.photoPath)
      ..writeByte(8)
      ..write(obj.tabletId)
      ..writeByte(9)
      ..write(obj.notes)
      ..writeByte(10)
      ..write(obj.entryTime)
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
      other is PlaceVisitAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
