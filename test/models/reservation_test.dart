import 'package:flutter_test/flutter_test.dart';
import 'package:jalapao_monitor/models/reservation.dart';

void main() {
  group('Reservation model', () {
    late DateTime scheduled;

    setUp(() {
      scheduled = DateTime(2026, 3, 18, 12, 0, 0);
    });

    Reservation _buildReservation({
      String id = 'res123abc456789',
      String placeId = 'place001abc1234',
      int paxQty = 4,
      String guestName = 'Ana Souza',
      DateTime? scheduledTime,
      String status = 'reserva',
    }) {
      return Reservation(
        id: id,
        placeId: placeId,
        paxQty: paxQty,
        guestName: guestName,
        scheduledTime: scheduledTime ?? scheduled,
        status: status,
      );
    }

    test('cria instância com valores padrão', () {
      final r = _buildReservation();

      expect(r.id, 'res123abc456789');
      expect(r.placeId, 'place001abc1234');
      expect(r.paxQty, 4);
      expect(r.guestName, 'Ana Souza');
      expect(r.scheduledTime, scheduled);
      expect(r.status, 'reserva');
      expect(r.arrivalTime, isNull);
      expect(r.exitTime, isNull);
      expect(r.isSynced, isFalse);
      expect(r.isEstimated, isFalse);
      expect(r.contactPhone, isNull);
      expect(r.notes, isNull);
      expect(r.tabletId, isNull);
    });

    test('getDurationMinutes retorna null sem arrivalTime ou exitTime', () {
      final r = _buildReservation();
      expect(r.getDurationMinutes(), isNull);
    });

    test('getDurationMinutes retorna null com apenas arrivalTime', () {
      final r = Reservation(
        id: 'res123abc456789',
        placeId: 'place001abc1234',
        paxQty: 2,
        guestName: 'Teste',
        scheduledTime: scheduled,
        arrivalTime: scheduled.add(const Duration(minutes: 10)),
        status: 'no_local',
      );
      expect(r.getDurationMinutes(), isNull);
    });

    test('getDurationMinutes calcula permanência corretamente', () {
      final arrival = scheduled.add(const Duration(minutes: 5));
      final exit = arrival.add(const Duration(minutes: 120));

      final r = Reservation(
        id: 'res123abc456789',
        placeId: 'place001abc1234',
        paxQty: 2,
        guestName: 'Teste',
        scheduledTime: scheduled,
        arrivalTime: arrival,
        exitTime: exit,
        status: 'concluida',
      );

      expect(r.getDurationMinutes(), 120);
    });

    test('toJson serializa campos obrigatórios e opcionais', () {
      final arrival = scheduled.add(const Duration(minutes: 5));
      final exit = arrival.add(const Duration(hours: 2));

      final r = Reservation(
        id: 'res123abc456789',
        placeId: 'place001abc1234',
        paxQty: 3,
        guestName: 'Carlos Lima',
        contactPhone: '63 98888-7777',
        scheduledTime: scheduled,
        arrivalTime: arrival,
        exitTime: exit,
        status: 'concluida',
        notes: 'Aniversário',
        tabletId: 'tablet-03',
        isSynced: true,
        isEstimated: false,
      );

      final json = r.toJson();

      expect(json['id'], 'res123abc456789');
      expect(json['place_id'], 'place001abc1234');
      expect(json['pax_qty'], 3);
      expect(json['guest_name'], 'Carlos Lima');
      expect(json['contact_phone'], '63 98888-7777');
      expect(json['scheduled_time'], scheduled.toIso8601String());
      expect(json['arrival_time'], arrival.toIso8601String());
      expect(json['exit_time'], exit.toIso8601String());
      expect(json['status'], 'concluida');
      expect(json['notes'], 'Aniversário');
      expect(json['tablet_id'], 'tablet-03');
      expect(json['is_estimated'], isFalse);
    });

    test('copyWith preserva campos não alterados', () {
      final original = _buildReservation();
      final checkedIn = original.copyWith(
        status: 'no_local',
        arrivalTime: scheduled.add(const Duration(minutes: 5)),
        isSynced: false,
      );

      expect(checkedIn.id, original.id);
      expect(checkedIn.placeId, original.placeId);
      expect(checkedIn.paxQty, original.paxQty);
      expect(checkedIn.guestName, original.guestName);
      expect(checkedIn.status, 'no_local');
      expect(checkedIn.arrivalTime, isNotNull);
    });

    test('fluxo completo: reserva → no_local → concluida', () {
      var r = _buildReservation(status: 'reserva');
      expect(r.status, 'reserva');
      expect(r.getDurationMinutes(), isNull);

      final arrival = scheduled.add(const Duration(minutes: 2));
      r = r.copyWith(status: 'no_local', arrivalTime: arrival);
      expect(r.status, 'no_local');
      expect(r.arrivalTime, arrival);

      final exit = arrival.add(const Duration(minutes: 90));
      r = r.copyWith(status: 'concluida', exitTime: exit);
      expect(r.status, 'concluida');
      expect(r.getDurationMinutes(), 90);
    });

    test('fluxo cancelamento: reserva → cancelada', () {
      var r = _buildReservation(status: 'reserva');
      r = r.copyWith(status: 'cancelada', isSynced: false);

      expect(r.status, 'cancelada');
      expect(r.arrivalTime, isNull);
      expect(r.exitTime, isNull);
    });

    test('isEstimated marca checkout automático', () {
      final r = Reservation(
        id: 'res123abc456789',
        placeId: 'place001abc1234',
        paxQty: 2,
        guestName: 'Grupo Auto',
        scheduledTime: scheduled,
        status: 'concluida',
        isEstimated: true,
      );

      expect(r.isEstimated, isTrue);
      expect(r.toJson()['is_estimated'], isTrue);
    });
  });
}
