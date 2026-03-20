// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reservation.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ReservationAdapter extends TypeAdapter<Reservation> {
  @override
  final int typeId = 3;

  @override
  Reservation read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Reservation(
      id: fields[0] as String,
      placeId: fields[1] as String,
      paxQty: fields[2] as int,
      guestName: fields[3] as String,
      contactPhone: fields[4] as String?,
      scheduledTime: fields[5] as DateTime,
      arrivalTime: fields[6] as DateTime?,
      exitTime: fields[7] as DateTime?,
      status: fields[8] as String,
      notes: fields[9] as String?,
      tabletId: fields[10] as String?,
      isSynced: fields[11] as bool,
      isEstimated: fields[12] as bool,
      originCity: fields[13] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Reservation obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.placeId)
      ..writeByte(2)
      ..write(obj.paxQty)
      ..writeByte(3)
      ..write(obj.guestName)
      ..writeByte(4)
      ..write(obj.contactPhone)
      ..writeByte(5)
      ..write(obj.scheduledTime)
      ..writeByte(6)
      ..write(obj.arrivalTime)
      ..writeByte(7)
      ..write(obj.exitTime)
      ..writeByte(8)
      ..write(obj.status)
      ..writeByte(9)
      ..write(obj.notes)
      ..writeByte(10)
      ..write(obj.tabletId)
      ..writeByte(11)
      ..write(obj.isSynced)
      ..writeByte(12)
      ..write(obj.isEstimated)
      ..writeByte(13)
      ..write(obj.originCity);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReservationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
