import 'package:hive/hive.dart';

part 'visit.g.dart';

@HiveType(typeId: 0)
class Visit extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  int paxQty;

  @HiveField(2)
  String status; // 'fila' | 'agua' | 'concluido'

  @HiveField(3)
  DateTime arrivalTime;

  @HiveField(4)
  DateTime? entryTime;

  @HiveField(5)
  DateTime? exitTime;

  @HiveField(6)
  bool isSynced;

  @HiveField(7)
  String atrativo;

  @HiveField(8)
  String tabletId;

  @HiveField(9)
  String groupId;

  @HiveField(10)
  int capacityLimit;

  @HiveField(11)
  String? groupName;

  @HiveField(12)
  String? originCity;

  Visit({
    required this.id,
    required this.paxQty,
    required this.status,
    required this.arrivalTime,
    this.entryTime,
    this.exitTime,
    this.isSynced = false,
    this.atrativo = '',
    this.tabletId = '',
    this.groupId = '',
    this.capacityLimit = 0,
    this.groupName,
    this.originCity,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pax_qty': paxQty,
      'status': status,
      'arrival_time': arrivalTime.toUtc().toIso8601String(),
      'entry_time': entryTime?.toUtc().toIso8601String(),
      'exit_time': exitTime?.toUtc().toIso8601String(),
      'atrativo': atrativo,
      'tablet_id': tabletId,
      'group_id': groupId,
      'capacity_limit': capacityLimit,
      'group_name': groupName,
      'origin_city': originCity,
    };
  }
}
