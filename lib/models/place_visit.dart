import 'package:hive/hive.dart';

part 'place_visit.g.dart';

@HiveType(typeId: 2)
class PlaceVisit extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String placeId;

  @HiveField(2)
  int paxQty;

  @HiveField(3)
  DateTime arrivalTime;

  @HiveField(4)
  DateTime? exitTime;

  @HiveField(5)
  String status; // "visiting" ou "exited"

  @HiveField(6)
  bool isSynced;

  @HiveField(7)
  String? photoPath;

  @HiveField(8)  // ← NOVO
  String? tabletId;

  @HiveField(9)
  String? notes;

  @HiveField(10)
  DateTime? entryTime; // quando o grupo entra de fato no atrativo (após staging area)

  @HiveField(11)
  String? groupName; // nome do grupo (opcional, gerado aleatoriamente se vazio)

  @HiveField(12)
  String? originCity; // cidade de origem do grupo (opcional)

  PlaceVisit({
    required this.id,
    required this.placeId,
    required this.paxQty,
    required this.arrivalTime,
    this.exitTime,
    required this.status,
    this.isSynced = false,
    this.photoPath,
    this.tabletId,
    this.notes,
    this.entryTime,
    this.groupName,
    this.originCity,
  });

  int getDurationMinutes() {
    if (exitTime == null) return 0;
    return exitTime!.difference(arrivalTime).inMinutes;
  }

  int? get waitMinutes {
    if (entryTime == null) return null;
    return entryTime!.difference(arrivalTime).inMinutes;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'place_id': placeId,
    'pax_qty': paxQty,
    'arrival_time': arrivalTime.toIso8601String(),
    'entry_time': entryTime?.toIso8601String(),
    'exit_time': exitTime?.toIso8601String(),
    'status': status,
    'tablet_id': tabletId,
    'notes': notes,
    'group_name': groupName,
    'origin_city': originCity,
  };

  factory PlaceVisit.fromJson(Map<String, dynamic> json) => PlaceVisit(
    id: json['id'],
    placeId: json['place_id'],
    paxQty: json['pax_qty'],
    arrivalTime: DateTime.parse(json['arrival_time']),
    entryTime: json['entry_time'] != null ? DateTime.parse(json['entry_time']) : null,
    exitTime: json['exit_time'] != null ? DateTime.parse(json['exit_time']) : null,
    status: json['status'] ?? 'visiting',
    tabletId: json['tablet_id'],
    notes: json['notes'],
    groupName: json['group_name'],
    originCity: json['origin_city'],
  );

  PlaceVisit copyWith({
    String? id,
    String? placeId,
    int? paxQty,
    DateTime? arrivalTime,
    DateTime? entryTime,
    DateTime? exitTime,
    String? status,
    bool? isSynced,
    String? photoPath,
    String? tabletId,
    String? notes,
    String? groupName,
    String? originCity,
  }) {
    return PlaceVisit(
      id: id ?? this.id,
      placeId: placeId ?? this.placeId,
      paxQty: paxQty ?? this.paxQty,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      entryTime: entryTime ?? this.entryTime,
      exitTime: exitTime ?? this.exitTime,
      status: status ?? this.status,
      isSynced: isSynced ?? this.isSynced,
      photoPath: photoPath ?? this.photoPath,
      tabletId: tabletId ?? this.tabletId,
      notes: notes ?? this.notes,
      groupName: groupName ?? this.groupName,
      originCity: originCity ?? this.originCity,
    );
  }
}
