import 'package:flutter_test/flutter_test.dart';
import 'package:jalapao_monitor/models/place.dart';

void main() {
  group('Place model', () {
    late DateTime fixedDate;

    setUp(() {
      fixedDate = DateTime(2026, 3, 18, 8, 0, 0);
    });

    Place _buildPlace({
      String id = 'abc123def456789',
      String name = 'Fervedouro da Ceiça',
      String type = 'fervedouro',
      double latitude = -10.1234,
      double longitude = -47.5678,
      int capacityTotal = 10,
      String ownerName = 'João Silva',
      String contactPhone = '63 98765-4321',
      String status = 'pending',
    }) {
      return Place(
        id: id,
        name: name,
        type: type,
        latitude: latitude,
        longitude: longitude,
        capacityTotal: capacityTotal,
        ownerName: ownerName,
        contactPhone: contactPhone,
        status: status,
        createdAt: fixedDate,
      );
    }

    test('cria instância com valores padrão', () {
      final place = _buildPlace();

      expect(place.id, 'abc123def456789');
      expect(place.name, 'Fervedouro da Ceiça');
      expect(place.type, 'fervedouro');
      expect(place.latitude, -10.1234);
      expect(place.longitude, -47.5678);
      expect(place.capacityTotal, 10);
      expect(place.ownerName, 'João Silva');
      expect(place.contactPhone, '63 98765-4321');
      expect(place.status, 'pending');
      expect(place.photoIds, isEmpty);
      expect(place.description, '');
      expect(place.isSynced, isFalse);
      expect(place.approvedAt, isNull);
      expect(place.approvedBy, isNull);
      expect(place.operatingHours, isNull);
    });

    test('toJson serializa todos os campos', () {
      final approvedAt = fixedDate.add(const Duration(hours: 2));
      final place = Place(
        id: 'abc123def456789',
        name: 'Cachoeira São Bento',
        type: 'cachoeira',
        latitude: -10.5,
        longitude: -47.3,
        capacityTotal: 30,
        ownerName: 'Maria Costa',
        contactPhone: '63 91234-5678',
        status: 'active',
        photoIds: ['photo1', 'photo2'],
        description: 'Linda cachoeira no cerrado',
        isSynced: true,
        createdAt: fixedDate,
        approvedAt: approvedAt,
        approvedBy: 'gestor_001',
        operatingHours: '08:00-17:00',
      );

      final json = place.toJson();

      expect(json['id'], 'abc123def456789');
      expect(json['name'], 'Cachoeira São Bento');
      expect(json['type'], 'cachoeira');
      expect(json['latitude'], -10.5);
      expect(json['longitude'], -47.3);
      expect(json['capacity_total'], 30);
      expect(json['owner_name'], 'Maria Costa');
      expect(json['contact_phone'], '63 91234-5678');
      expect(json['status'], 'active');
      expect(json['photo_ids'], ['photo1', 'photo2']);
      expect(json['description'], 'Linda cachoeira no cerrado');
      expect(json['approved_at'], approvedAt.toIso8601String());
      expect(json['approved_by_user_id'], 'gestor_001');
      expect(json['operating_hours'], '08:00-17:00');
    });

    test('fromJson reconstrói Place corretamente', () {
      final json = {
        'id': 'xyz789abc123456',
        'name': 'Restaurante Cerrado',
        'type': 'restaurante',
        'latitude': -10.2,
        'longitude': -47.6,
        'capacity_total': 50,
        'owner_name': 'Pedro Alves',
        'contact_phone': '63 99876-5432',
        'status': 'active',
        'photo_ids': [],
        'description': 'Comida típica do cerrado',
        'isSynced': true,
        'created_at_v2': '2026-03-18T08:00:00.000',
        'approved_at': null,
        'approved_by_user_id': null,
        'operating_hours': '11:00-22:00',
      };

      final place = Place.fromJson(json);

      expect(place.id, 'xyz789abc123456');
      expect(place.name, 'Restaurante Cerrado');
      expect(place.type, 'restaurante');
      expect(place.latitude, -10.2);
      expect(place.longitude, -47.6);
      expect(place.capacityTotal, 50);
      expect(place.ownerName, 'Pedro Alves');
      expect(place.status, 'active');
      expect(place.isSynced, isTrue);
      expect(place.operatingHours, '11:00-22:00');
    });

    test('fromJson aceita latitude/longitude como string', () {
      final json = {
        'id': 'abc123def456789',
        'name': 'Teste',
        'type': 'fervedouro',
        'latitude': '-10.1234', // string
        'longitude': '-47.5678', // string
        'capacity_total': 10,
        'owner_name': '',
        'contact_phone': '',
        'status': 'pending',
        'photo_ids': [],
        'description': '',
        'created': '2026-03-18T08:00:00.000Z',
      };

      final place = Place.fromJson(json);

      expect(place.latitude, closeTo(-10.1234, 0.0001));
      expect(place.longitude, closeTo(-47.5678, 0.0001));
    });

    test('fromJson usa created quando created_at_v2 ausente', () {
      final json = {
        'id': 'abc123def456789',
        'name': 'Teste',
        'type': 'fervedouro',
        'latitude': -10.0,
        'longitude': -47.0,
        'capacity_total': 5,
        'owner_name': '',
        'contact_phone': '',
        'status': 'pending',
        'photo_ids': [],
        'description': '',
        'created': '2026-01-15T12:00:00.000Z',
      };

      final place = Place.fromJson(json);

      expect(place.createdAt.year, 2026);
      expect(place.createdAt.month, 1);
      expect(place.createdAt.day, 15);
    });

    test('copyWith atualiza apenas campos especificados', () {
      final original = _buildPlace();
      final updated = original.copyWith(status: 'active', isSynced: true);

      expect(updated.id, original.id);
      expect(updated.name, original.name);
      expect(updated.status, 'active');
      expect(updated.isSynced, isTrue);
      // Campos não alterados permanecem iguais
      expect(updated.type, original.type);
      expect(updated.latitude, original.latitude);
      expect(updated.capacityTotal, original.capacityTotal);
    });

    test('copyWith não modifica o original', () {
      final original = _buildPlace();
      original.copyWith(status: 'active', name: 'Novo Nome');

      expect(original.status, 'pending');
      expect(original.name, 'Fervedouro da Ceiça');
    });

    test('tipos válidos de atrativo', () {
      final validTypes = [
        'fervedouro',
        'cachoeira',
        'restaurante',
        'pousada',
        'fazenda',
        'chacaras',
        'loja',
        'atrativo_cultural',
      ];

      for (final type in validTypes) {
        final place = _buildPlace(type: type);
        expect(place.type, type);
      }
    });

    test('status flow: pending → active', () {
      final place = _buildPlace(status: 'pending');
      final approved = place.copyWith(
        status: 'active',
        approvedAt: fixedDate,
        approvedBy: 'gestor_001',
      );

      expect(approved.status, 'active');
      expect(approved.approvedAt, fixedDate);
      expect(approved.approvedBy, 'gestor_001');
    });

    test('status flow: pending → rejected', () {
      final place = _buildPlace(status: 'pending');
      final rejected = place.copyWith(status: 'rejected');

      expect(rejected.status, 'rejected');
      expect(rejected.approvedAt, isNull);
    });
  });
}
