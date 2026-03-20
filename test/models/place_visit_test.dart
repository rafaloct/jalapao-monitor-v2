import 'package:flutter_test/flutter_test.dart';
import 'package:jalapao_monitor/models/place_visit.dart';

void main() {
  group('PlaceVisit model', () {
    late DateTime arrival;

    setUp(() {
      arrival = DateTime(2026, 3, 18, 9, 0, 0);
    });

    test('cria instância com campos obrigatórios', () {
      final visit = PlaceVisit(
        id: 'abc123def456789',
        placeId: 'place001abc1234',
        paxQty: 5,
        arrivalTime: arrival,
        status: 'visiting',
      );

      expect(visit.id, 'abc123def456789');
      expect(visit.placeId, 'place001abc1234');
      expect(visit.paxQty, 5);
      expect(visit.arrivalTime, arrival);
      expect(visit.status, 'visiting');
      expect(visit.exitTime, isNull);
      expect(visit.entryTime, isNull);
      expect(visit.isSynced, isFalse);
      expect(visit.tabletId, isNull);
      expect(visit.notes, isNull);
    });

    test('getDurationMinutes retorna 0 quando sem exitTime', () {
      final visit = PlaceVisit(
        id: 'abc123def456789',
        placeId: 'place001abc1234',
        paxQty: 3,
        arrivalTime: arrival,
        status: 'visiting',
      );

      expect(visit.getDurationMinutes(), 0);
    });

    test('getDurationMinutes calcula diferença corretamente', () {
      final exit = arrival.add(const Duration(minutes: 45));
      final visit = PlaceVisit(
        id: 'abc123def456789',
        placeId: 'place001abc1234',
        paxQty: 3,
        arrivalTime: arrival,
        exitTime: exit,
        status: 'exited',
      );

      expect(visit.getDurationMinutes(), 45);
    });

    test('getDurationMinutes com permanência menor que 1 minuto retorna 0', () {
      final exit = arrival.add(const Duration(seconds: 30));
      final visit = PlaceVisit(
        id: 'abc123def456789',
        placeId: 'place001abc1234',
        paxQty: 1,
        arrivalTime: arrival,
        exitTime: exit,
        status: 'exited',
      );

      expect(visit.getDurationMinutes(), 0);
    });

    test('waitMinutes retorna null quando sem entryTime', () {
      final visit = PlaceVisit(
        id: 'abc123def456789',
        placeId: 'place001abc1234',
        paxQty: 2,
        arrivalTime: arrival,
        status: 'visiting',
      );

      expect(visit.waitMinutes, isNull);
    });

    test('waitMinutes calcula tempo de espera corretamente', () {
      final entry = arrival.add(const Duration(minutes: 15));
      final visit = PlaceVisit(
        id: 'abc123def456789',
        placeId: 'place001abc1234',
        paxQty: 2,
        arrivalTime: arrival,
        entryTime: entry,
        status: 'visiting',
      );

      expect(visit.waitMinutes, 15);
    });

    test('toJson serializa todos os campos', () {
      final entry = arrival.add(const Duration(minutes: 10));
      final exit = arrival.add(const Duration(minutes: 40));

      final visit = PlaceVisit(
        id: 'abc123def456789',
        placeId: 'place001abc1234',
        paxQty: 4,
        arrivalTime: arrival,
        entryTime: entry,
        exitTime: exit,
        status: 'exited',
        tabletId: 'tablet-02',
        notes: 'Grupo familiar',
      );

      final json = visit.toJson();

      expect(json['id'], 'abc123def456789');
      expect(json['place_id'], 'place001abc1234');
      expect(json['pax_qty'], 4);
      expect(json['arrival_time'], arrival.toIso8601String());
      expect(json['entry_time'], entry.toIso8601String());
      expect(json['exit_time'], exit.toIso8601String());
      expect(json['status'], 'exited');
      expect(json['tablet_id'], 'tablet-02');
      expect(json['notes'], 'Grupo familiar');
    });

    test('fromJson reconstrói PlaceVisit corretamente', () {
      final json = {
        'id': 'abc123def456789',
        'place_id': 'place001abc1234',
        'pax_qty': 6,
        'arrival_time': '2026-03-18T09:00:00.000',
        'entry_time': '2026-03-18T09:10:00.000',
        'exit_time': '2026-03-18T09:45:00.000',
        'status': 'exited',
        'tablet_id': 'tablet-01',
        'notes': null,
      };

      final visit = PlaceVisit.fromJson(json);

      expect(visit.id, 'abc123def456789');
      expect(visit.placeId, 'place001abc1234');
      expect(visit.paxQty, 6);
      expect(visit.status, 'exited');
      expect(visit.tabletId, 'tablet-01');
      expect(visit.entryTime, isNotNull);
      expect(visit.exitTime, isNotNull);
    });

    test('fromJson sem entry_time e exit_time', () {
      final json = {
        'id': 'abc123def456789',
        'place_id': 'place001abc1234',
        'pax_qty': 3,
        'arrival_time': '2026-03-18T09:00:00.000',
        'entry_time': null,
        'exit_time': null,
        'status': 'visiting',
        'tablet_id': null,
        'notes': null,
      };

      final visit = PlaceVisit.fromJson(json);

      expect(visit.entryTime, isNull);
      expect(visit.exitTime, isNull);
    });

    test('copyWith atualiza campos corretamente', () {
      final original = PlaceVisit(
        id: 'abc123def456789',
        placeId: 'place001abc1234',
        paxQty: 3,
        arrivalTime: arrival,
        status: 'visiting',
      );

      final exit = arrival.add(const Duration(minutes: 30));
      final updated = original.copyWith(
        exitTime: exit,
        status: 'exited',
        isSynced: true,
      );

      expect(updated.exitTime, exit);
      expect(updated.status, 'exited');
      expect(updated.isSynced, isTrue);
      // Campos não alterados
      expect(updated.id, original.id);
      expect(updated.paxQty, original.paxQty);
      expect(updated.arrivalTime, original.arrivalTime);
    });
  });
}
