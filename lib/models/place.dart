import 'package:hive/hive.dart';

part 'place.g.dart';

@HiveType(typeId: 1)
class Place extends HiveObject {
  @HiveField(0)
  String id; // 15 chars, gerado locally

  @HiveField(1)
  String name; // Ex: "Fervedouro Ceiça"

  @HiveField(2)
  String type; // fervedouro|cachoeira|restaurante|pousada|fazenda|chacaras|loja|atrativo_cultural

  @HiveField(3)
  double latitude; // GPS automático

  @HiveField(4)
  double longitude; // GPS automático

  @HiveField(5)
  int capacityTotal; // Capacidade máxima

  @HiveField(6)
  String ownerName; // Nome do proprietário

  @HiveField(7)
  String contactPhone; // Telefone para contato

  @HiveField(8)
  String status; // pending|approved|rejected|active|archived

  @HiveField(9)
  List<String> photoIds; // IDs de fotos no PocketBase

  @HiveField(10)
  String description; // Observações gerais

  @HiveField(11)
  bool isSynced; // Flag de sincronização

  @HiveField(12)
  DateTime createdAt; // Timestamp de criação local

  @HiveField(13)
  DateTime? approvedAt; // Timestamp de aprovação (null até ser aprovado)

  @HiveField(14)
  String? approvedBy; // ID do gestor que aprovou

  @HiveField(15)
  String? operatingHours; // Ex: "08:00-18:00"

  Place({
    required this.id,
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.capacityTotal,
    required this.ownerName,
    required this.contactPhone,
    this.status = 'pending',
    this.photoIds = const [],
    this.description = '',
    this.isSynced = false,
    DateTime? createdAt,
    this.approvedAt,
    this.approvedBy,
    this.operatingHours,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Converte para JSON para enviar ao PocketBase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'latitude': latitude,
      'longitude': longitude,
      'capacity_total': capacityTotal,
      'owner_name': ownerName,
      'contact_phone': contactPhone,
      'status': status,
      'photo_ids': photoIds,
      'description': description,
      'created_at_v2': createdAt.toIso8601String(),
      'approved_at': approvedAt?.toIso8601String(),
      'approved_by_user_id': approvedBy,
      'operating_hours': operatingHours,
    };
  }

  /// Cria Place a partir de JSON do PocketBase
  static Place fromJson(Map<String, dynamic> json) {
    return Place(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? 'atrativo_cultural',
      latitude: (json['latitude'] is String)
          ? double.parse(json['latitude'])
          : (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] is String)
          ? double.parse(json['longitude'])
          : (json['longitude'] as num).toDouble(),
      capacityTotal: (json['capacity_total'] as num?)?.toInt() ?? 0,
      ownerName: json['owner_name'] ?? '',
      contactPhone: json['contact_phone'] ?? '',
      status: json['status'] ?? 'pending',
      photoIds: List<String>.from(json['photo_ids'] ?? []),
      description: json['description'] ?? '',
      isSynced: json['isSynced'] ?? false,
      createdAt: (json['created_at_v2'] ?? json['created']) != null
          ? DateTime.parse((json['created_at_v2'] ?? json['created']) as String)
          : DateTime.now(),
      approvedAt: json['approved_at'] != null
          ? DateTime.parse(json['approved_at'] as String)
          : null,
      approvedBy: json['approved_by_user_id'],
      operatingHours: json['operating_hours'],
    );
  }

  /// Cria cópia com campos atualizados
  Place copyWith({
    String? id,
    String? name,
    String? type,
    double? latitude,
    double? longitude,
    int? capacityTotal,
    String? ownerName,
    String? contactPhone,
    String? status,
    List<String>? photoIds,
    String? description,
    bool? isSynced,
    DateTime? createdAt,
    DateTime? approvedAt,
    String? approvedBy,
    String? operatingHours,
  }) {
    return Place(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      capacityTotal: capacityTotal ?? this.capacityTotal,
      ownerName: ownerName ?? this.ownerName,
      contactPhone: contactPhone ?? this.contactPhone,
      status: status ?? this.status,
      photoIds: photoIds ?? this.photoIds,
      description: description ?? this.description,
      isSynced: isSynced ?? this.isSynced,
      createdAt: createdAt ?? this.createdAt,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      operatingHours: operatingHours ?? this.operatingHours,
    );
  }
}
