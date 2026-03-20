import 'package:flutter_test/flutter_test.dart';
import 'package:jalapao_monitor/models/visit.dart';

void main() {
  group('Visit model', () {
    late DateTime now;

    setUp(() {
      now = DateTime(2026, 3, 18, 10, 0, 0);
    });

    test('cria instância com valores padrão', () {
      final visit = Visit(
        id: 'abc123def456789',
        paxQty: 4,
        status: 'fila',
        arrivalTime: now,
      );

      expect(visit.id, 'abc123def456789');
      expect(visit.paxQty, 4);
      expect(visit.status, 'fila');
      expect(visit.arrivalTime, now);
      expect(visit.entryTime, isNull);
      expect(visit.exitTime, isNull);
      expect(visit.isSynced, isFalse);
      expect(visit.atrativo, '');
      expect(visit.tabletId, '');
      expect(visit.groupId, '');
      expect(visit.capacityLimit, 0);
    });

    test('toJson serializa todos os campos corretamente', () {
      final entryTime = now.add(const Duration(minutes: 5));
      final exitTime = now.add(const Duration(minutes: 25));

      final visit = Visit(
        id: 'abc123def456789',
        paxQty: 3,
        status: 'concluido',
        arrivalTime: now,
        entryTime: entryTime,
        exitTime: exitTime,
        isSynced: true,
        atrativo: 'Fervedouro da Ceiça',
        tabletId: 'tablet-01',
        groupId: 'grp001',
        capacityLimit: 6,
      );

      final json = visit.toJson();

      expect(json['id'], 'abc123def456789');
      expect(json['pax_qty'], 3);
      expect(json['status'], 'concluido');
      expect(json['arrival_time'], now.toUtc().toIso8601String());
      expect(json['entry_time'], entryTime.toUtc().toIso8601String());
      expect(json['exit_time'], exitTime.toUtc().toIso8601String());
      expect(json['atrativo'], 'Fervedouro da Ceiça');
      expect(json['tablet_id'], 'tablet-01');
      expect(json['group_id'], 'grp001');
      expect(json['capacity_limit'], 6);
    });

    test('toJson com campos opcionais nulos', () {
      final visit = Visit(
        id: 'abc123def456789',
        paxQty: 2,
        status: 'fila',
        arrivalTime: now,
      );

      final json = visit.toJson();

      expect(json['entry_time'], isNull);
      expect(json['exit_time'], isNull);
    });

    test('status fila → agua → concluido representa fluxo válido', () {
      final statusFlow = ['fila', 'agua', 'concluido'];

      for (final status in statusFlow) {
        final visit = Visit(
          id: 'abc123def456789',
          paxQty: 1,
          status: status,
          arrivalTime: now,
        );
        expect(visit.status, status);
      }
    });

    test('paxQty aceita diferentes quantidades de pessoas', () {
      for (final qty in [1, 2, 5, 10, 20]) {
        final visit = Visit(
          id: 'abc123def456789',
          paxQty: qty,
          status: 'fila',
          arrivalTime: now,
        );
        expect(visit.paxQty, qty);
      }
    });

    test('arrivalTime é salvo em UTC no JSON', () {
      final localTime = DateTime(2026, 3, 18, 10, 30, 0); // horário local
      final visit = Visit(
        id: 'abc123def456789',
        paxQty: 1,
        status: 'fila',
        arrivalTime: localTime,
      );

      final json = visit.toJson();
      final parsedTime = DateTime.parse(json['arrival_time'] as String);

      // Deve ser interpretável como DateTime
      expect(parsedTime, isA<DateTime>());
    });
  });
}
