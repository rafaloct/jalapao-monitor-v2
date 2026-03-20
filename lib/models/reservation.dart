import 'package:hive/hive.dart';

part 'reservation.g.dart';

/// Status flow: reserva → no_local → concluida
///                      ↘ cancelada
@HiveType(typeId: 3)
class Reservation extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String placeId;

  @HiveField(2)
  int paxQty;

  /// Nome do responsável pelo grupo (pode ser anônimo)
  @HiveField(3)
  String guestName;

  @HiveField(4)
  String? contactPhone;

  /// Horário agendado da reserva
  @HiveField(5)
  DateTime scheduledTime;

  /// Momento real do check-in (chegada ao local)
  @HiveField(6)
  DateTime? arrivalTime;

  /// Momento real do check-out (saída do local)
  @HiveField(7)
  DateTime? exitTime;

  /// 'reserva' | 'no_local' | 'concluida' | 'cancelada'
  @HiveField(8)
  String status;

  @HiveField(9)
  String? notes;

  @HiveField(10)
  String? tabletId;

  @HiveField(11)
  bool isSynced;

  /// true quando o check-out foi gerado automaticamente (não pelo fiscal)
  /// Dados estimados são mantidos no dataset mas marcados para exclusão na análise estatística rigorosa
  @HiveField(12)
  bool isEstimated;

  @HiveField(13)
  String? originCity;

  Reservation({
    required this.id,
    required this.placeId,
    required this.paxQty,
    required this.guestName,
    this.contactPhone,
    required this.scheduledTime,
    this.arrivalTime,
    this.exitTime,
    this.status = 'reserva',
    this.notes,
    this.tabletId,
    this.isSynced = false,
    this.isEstimated = false,
    this.originCity,
  });

  int? getDurationMinutes() {
    if (arrivalTime == null || exitTime == null) return null;
    return exitTime!.difference(arrivalTime!).inMinutes;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'place_id': placeId,
        'pax_qty': paxQty,
        'guest_name': guestName,
        'contact_phone': contactPhone,
        'scheduled_time': scheduledTime.toIso8601String(),
        'arrival_time': arrivalTime?.toIso8601String(),
        'exit_time': exitTime?.toIso8601String(),
        'status': status,
        'notes': notes,
        'tablet_id': tabletId,
        'is_estimated': isEstimated,
        'origin_city': originCity,
      };

  Reservation copyWith({
    String? id,
    String? placeId,
    int? paxQty,
    String? guestName,
    String? contactPhone,
    DateTime? scheduledTime,
    DateTime? arrivalTime,
    DateTime? exitTime,
    String? status,
    String? notes,
    String? tabletId,
    bool? isSynced,
    bool? isEstimated,
    String? originCity,
  }) {
    return Reservation(
      id: id ?? this.id,
      placeId: placeId ?? this.placeId,
      paxQty: paxQty ?? this.paxQty,
      guestName: guestName ?? this.guestName,
      contactPhone: contactPhone ?? this.contactPhone,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      exitTime: exitTime ?? this.exitTime,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      tabletId: tabletId ?? this.tabletId,
      isSynced: isSynced ?? this.isSynced,
      isEstimated: isEstimated ?? this.isEstimated,
      originCity: originCity ?? this.originCity,
    );
  }
}
