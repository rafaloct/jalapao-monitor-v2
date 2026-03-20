// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'place.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PlaceAdapter extends TypeAdapter<Place> {
  @override
  final int typeId = 1;

  @override
  Place read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Place(
      id: fields[0] as String,
      name: fields[1] as String,
      type: fields[2] as String,
      latitude: fields[3] as double,
      longitude: fields[4] as double,
      capacityTotal: fields[5] as int,
      ownerName: fields[6] as String,
      contactPhone: fields[7] as String,
      status: fields[8] as String,
      photoIds: (fields[9] as List).cast<String>(),
      description: fields[10] as String,
      isSynced: fields[11] as bool,
      createdAt: fields[12] as DateTime?,
      approvedAt: fields[13] as DateTime?,
      approvedBy: fields[14] as String?,
      operatingHours: fields[15] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Place obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.latitude)
      ..writeByte(4)
      ..write(obj.longitude)
      ..writeByte(5)
      ..write(obj.capacityTotal)
      ..writeByte(6)
      ..write(obj.ownerName)
      ..writeByte(7)
      ..write(obj.contactPhone)
      ..writeByte(8)
      ..write(obj.status)
      ..writeByte(9)
      ..write(obj.photoIds)
      ..writeByte(10)
      ..write(obj.description)
      ..writeByte(11)
      ..write(obj.isSynced)
      ..writeByte(12)
      ..write(obj.createdAt)
      ..writeByte(13)
      ..write(obj.approvedAt)
      ..writeByte(14)
      ..write(obj.approvedBy)
      ..writeByte(15)
      ..write(obj.operatingHours);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
