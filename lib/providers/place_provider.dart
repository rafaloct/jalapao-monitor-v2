import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:pocketbase/pocketbase.dart';
import '../config/app_config.dart';
import '../models/place.dart';
import '../models/place_visit.dart';
import '../models/reservation.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';

class PlaceProvider extends ChangeNotifier {
  final Box<Place> _placesBox;
  final Box<PlaceVisit> _placeVisitsBox;
  final Box<Reservation> _reservationsBox;
  final Box _configBox; // tabletId e outras configurações locais
  late final SyncService _syncService;
  final PocketBase _pb = PocketBase(AppConfig.pbUrl);
  Timer? _syncDownTimer;

  String? _lastSyncError;
  String? get lastSyncError => _lastSyncError;

  PlaceProvider(this._placesBox, this._placeVisitsBox, this._reservationsBox, this._configBox) {
    _syncService = SyncService(
      placesBox: _placesBox,
      placeVisitsBox: _placeVisitsBox,
      reservationsBox: _reservationsBox,
      onError: _handleSyncError,
    );
    _syncService.startPeriodicSync();
    // Reset de sessão se for um novo dia (fiscal deve reconfirmar local toda manhã)
    _clearStaleSession();
    // Sync-down: baixa places ativos do PocketBase periodicamente
    _startSyncDownTimer();
  }

  /// Limpa a sessão ativa se foi definida em um dia anterior.
  /// Garante que o fiscal escolhe explicitamente o local a cada turno.
  void _clearStaleSession() {
    final sessionDateStr = _configBox.get('sessionDate') as String?;
    if (sessionDateStr == null) return;
    final sessionDate = DateTime.parse(sessionDateStr);
    final today = DateTime.now();
    final isToday = sessionDate.year == today.year &&
        sessionDate.month == today.month &&
        sessionDate.day == today.day;
    if (!isToday) {
      _configBox.delete('activeSessionPlaceId');
      _configBox.delete('sessionDate');
    }
  }

  void _handleSyncError(String message) {
    _lastSyncError = message;
    notifyListeners();
  }

  void clearSyncError() {
    _lastSyncError = null;
    notifyListeners();
  }

  void _startSyncDownTimer() {
    // Download imediato ao iniciar
    syncDownActivePlaces();
    // Depois a cada 60 segundos
    _syncDownTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => syncDownActivePlaces(),
    );
  }

  // ── Session Management ────────────────────────────────
  String? get activeSessionPlaceId =>
      _configBox.get('activeSessionPlaceId') as String?;

  Future<void> setActiveSession(String placeId) async {
    await _configBox.put('activeSessionPlaceId', placeId);
    await _configBox.put('sessionDate', DateTime.now().toIso8601String());
    notifyListeners();
  }

  Future<void> clearActiveSession() async {
    await _configBox.delete('activeSessionPlaceId');
    notifyListeners();
  }

  Place? getPlace(String placeId) => _placesBox.get(placeId);

  // ── ID Generator ─────────────────────────────────────
  String _generateId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random();
    return List.generate(15, (index) => chars[rand.nextInt(chars.length)])
        .join();
  }

  // ── Sync-Down: Baixa places ativos do PocketBase ──────

  /// Baixa todos os places com status=active do PocketBase e salva no Hive local.
  /// Permite que tablets de operadores vejam places aprovados pelo gestor.
  Future<void> syncDownActivePlaces() async {
    try {
      final records = await _pb.collection('places').getFullList(
        filter: 'status = "active"',
        sort: 'name',
      );

      bool changed = false;
      for (final record in records) {
        final existing = _placesBox.get(record.id);
        final incomingData = <String, dynamic>{'id': record.id, ...record.data};

        if (existing == null) {
          // Novo place ativo — adicionar ao Hive
          final place = Place.fromJson(incomingData).copyWith(isSynced: true);
          await _placesBox.put(record.id, place);
          changed = true;
        } else if (existing.status != 'active') {
          // Place que foi aprovado remotamente — atualizar localmente
          final updated = existing.copyWith(status: 'active', isSynced: true);
          await _placesBox.put(record.id, updated);
          changed = true;
        }
      }

      if (changed) notifyListeners();
      debugPrint('[PlaceProvider] SyncDown: ${records.length} places ativos');
    } catch (e) {
      debugPrint('[PlaceProvider] SyncDown error: $e');
    }
  }

  // ── Place Management ──────────────────────────────────

  Future<void> addPlace(Place place) async {
    final placeWithId = place.copyWith(
      id: _generateId(),
      isSynced: false,
    );
    await _placesBox.put(placeWithId.id, placeWithId);
    notifyListeners();
  }

  Future<void> updatePlace(Place place) async {
    await _placesBox.put(place.id, place);
    notifyListeners();
  }

  List<Place> get allPlaces {
    return _placesBox.values.toList();
  }

  List<Place> get pendingPlaces {
    return _placesBox.values
        .where((p) => p.status == 'pending')
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<Place> get approvedPlaces {
    return _placesBox.values
        .where((p) => p.status == 'active')
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  List<Place> placesByType(String type) {
    return _placesBox.values
        .where((p) => p.type == type && p.status == 'active')
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> deletePlace(String placeId) async {
    final place = _placesBox.get(placeId);
    if (place != null && !place.isSynced) {
      await _placesBox.delete(placeId);
      notifyListeners();
    }
  }

  // ── Gestão de Aprovação (Gestor only) ─────────────────

  /// Aprova um place localmente E tenta sincronizar com PocketBase.
  /// Retorna true se aprovado localmente (sempre).
  /// A sincronização com PocketBase pode falhar se a regra de update exigir auth
  /// de usuário — nesse caso, aprovar localmente funciona mas outros tablets
  /// não verão o place como ativo até que o admin aprove no PocketBase.
  Future<bool> approvePlace(String placeId, AuthService authService) async {
    // Sempre aprova localmente primeiro
    final place = _placesBox.get(placeId);
    if (place != null) {
      await _placesBox.put(
        placeId,
        place.copyWith(
          status: 'active',
          approvedAt: DateTime.now(),
          isSynced: false, // marca para tentar sync depois
        ),
      );
      notifyListeners();
    }
    // Tenta sincronizar com PocketBase
    final syncedRemote = await authService.approvePlace(placeId);
    if (syncedRemote && place != null) {
      await _placesBox.put(
        placeId,
        (place).copyWith(status: 'active', isSynced: true),
      );
    }
    return true; // local approval always succeeds
  }

  /// Rejeita um place localmente E tenta sincronizar com PocketBase.
  Future<bool> rejectPlace(String placeId, AuthService authService) async {
    final place = _placesBox.get(placeId);
    if (place != null) {
      await _placesBox.put(
        placeId,
        place.copyWith(status: 'rejected', isSynced: false),
      );
      notifyListeners();
    }
    await authService.rejectPlace(placeId);
    return true;
  }

  /// Aprova um place pendente do PocketBase (não existe localmente ainda).
  /// Salva localmente como active e tenta aprovar no PocketBase.
  Future<bool> approvePlaceRemote(
    Map<String, dynamic> placeData,
    AuthService authService,
  ) async {
    final placeId = placeData['id'] as String;

    // Salvar localmente como active
    final place = Place.fromJson(placeData).copyWith(
      status: 'active',
      approvedAt: DateTime.now(),
      isSynced: false,
    );
    await _placesBox.put(placeId, place);
    notifyListeners();

    // Tentar sincronizar com PocketBase
    final syncedRemote = await authService.approvePlace(placeId);
    if (syncedRemote) {
      await _placesBox.put(placeId, place.copyWith(isSynced: true));
    }
    return true;
  }

  /// Rejeita um place remoto (não existe no Hive local)
  Future<bool> rejectPlaceRemote(
    Map<String, dynamic> placeData,
    AuthService authService,
  ) async {
    final placeId = placeData['id'] as String;
    final place = Place.fromJson(placeData).copyWith(
      status: 'rejected',
      isSynced: false,
    );
    await _placesBox.put(placeId, place);
    notifyListeners();
    await authService.rejectPlace(placeId);
    return true;
  }

  // ── PlaceVisit Management ──────────────────────────────

  static const _jalapaoNames = [
    'Ipê', 'Buriti', 'Capim-dourado', 'Cerrado', 'Veredas',
    'Sertão', 'Candeia', 'Pequi', 'Aroeira', 'Mangaba',
  ];

  String _randomGroupName() {
    final rand = Random();
    return 'Grupo ${_jalapaoNames[rand.nextInt(_jalapaoNames.length)]}';
  }

  Future<String> registerArrival({
    required String placeId,
    required int paxQty,
    String? id,
    DateTime? arrivalTime,
    DateTime? entryTime,
    String? groupName,
    String? originCity,
  }) async {
    final visitId = id ?? _generateId();
    // Idempotent: skip if PlaceVisit with this ID already exists
    if (_placeVisitsBox.containsKey(visitId)) return visitId;
    final visit = PlaceVisit(
      id: visitId,
      placeId: placeId,
      paxQty: paxQty,
      arrivalTime: arrivalTime ?? DateTime.now(),
      entryTime: entryTime,
      status: 'visiting',
      tabletId: _configBox.get('tabletId') as String? ?? 'tablet-sem-id',
      groupName: groupName?.trim().isEmpty ?? true ? _randomGroupName() : groupName!.trim(),
      originCity: originCity?.trim().isEmpty ?? true ? null : originCity!.trim(),
    );
    await _placeVisitsBox.put(visitId, visit);
    notifyListeners();
    return visitId;
  }

  /// Registra a entrada efetiva no atrativo (após staging area).
  /// Usado em fervedouro (fila→água) e cachoeira (chegada→entrada).
  Future<void> registerEntry(String visitId) async {
    final visit = _placeVisitsBox.get(visitId);
    if (visit != null && visit.entryTime == null) {
      final updated = visit.copyWith(entryTime: DateTime.now());
      await _placeVisitsBox.put(visitId, updated);
      notifyListeners();
    }
  }

  Future<void> registerExit(String visitId) async {
    final visit = _placeVisitsBox.get(visitId);
    if (visit != null) {
      final updated = visit.copyWith(
        exitTime: DateTime.now(),
        status: 'exited',
      );
      await _placeVisitsBox.put(visitId, updated);
      notifyListeners();
    }
  }

  List<PlaceVisit> visitsByPlace(String placeId) {
    return _placeVisitsBox.values
        .where((v) => v.placeId == placeId)
        .toList()
      ..sort((a, b) => b.arrivalTime.compareTo(a.arrivalTime));
  }

  List<PlaceVisit> get activeVisits {
    return _placeVisitsBox.values
        .where((v) => v.status == 'visiting')
        .toList()
      ..sort((a, b) => a.arrivalTime.compareTo(b.arrivalTime));
  }

  List<PlaceVisit> get todayVisits {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    return _placeVisitsBox.values
        .where((v) => v.arrivalTime.isAfter(todayStart))
        .toList()
      ..sort((a, b) => b.arrivalTime.compareTo(a.arrivalTime));
  }

  int getCurrentOccupancy(String placeId) {
    return activeVisits
        .where((v) => v.placeId == placeId)
        .fold<int>(0, (sum, v) => sum + v.paxQty);
  }

  double? getAverageStay(String placeId) {
    final visits = _placeVisitsBox.values
        .where((v) => v.placeId == placeId && v.status == 'exited')
        .toList();
    if (visits.isEmpty) return null;
    final totalMinutes = visits.fold<int>(
      0,
      (sum, v) => sum + v.getDurationMinutes(),
    );
    return totalMinutes / visits.length;
  }

  /// Total de visitantes hoje em todos os places (para mini-stats no dashboard)
  int get totalPlaceVisitorsToday {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    return _placeVisitsBox.values
        .where((v) => v.arrivalTime.isAfter(todayStart))
        .fold<int>(0, (sum, v) => sum + v.paxQty);
  }

  /// Places com visitantes ativos agora
  List<Place> get placesWithActiveVisits {
    final activePlaceIds = activeVisits.map((v) => v.placeId).toSet();
    return _placesBox.values
        .where((p) => activePlaceIds.contains(p.id))
        .toList();
  }

  // ── Reservation Management ────────────────────────────

  /// Cria uma nova reserva com horário agendado.
  Future<void> addReservation({
    required String placeId,
    required int paxQty,
    required String guestName,
    required DateTime scheduledTime,
    String? contactPhone,
    String? notes,
    String? tabletId,
    String? originCity,
  }) async {
    final id = _generateId();
    final reservation = Reservation(
      id: id,
      placeId: placeId,
      paxQty: paxQty,
      guestName: guestName,
      contactPhone: contactPhone,
      scheduledTime: scheduledTime,
      status: 'reserva',
      notes: notes,
      tabletId: tabletId,
      originCity: originCity?.trim().isEmpty ?? true ? null : originCity!.trim(),
    );
    await _reservationsBox.put(id, reservation);
    notifyListeners();
  }

  /// Faz check-in: reserva → no_local
  Future<void> checkIn(String reservationId) async {
    final r = _reservationsBox.get(reservationId);
    if (r == null) return;
    await _reservationsBox.put(
      reservationId,
      r.copyWith(status: 'no_local', arrivalTime: DateTime.now(), isSynced: false),
    );
    notifyListeners();
  }

  /// Faz check-out: no_local → concluida
  /// [isEstimated] = true quando gerado automaticamente (sem ação do fiscal)
  Future<void> checkOut(String reservationId, {bool isEstimated = false}) async {
    final r = _reservationsBox.get(reservationId);
    if (r == null || r.status != 'no_local') return;
    await _reservationsBox.put(
      reservationId,
      r.copyWith(
        status: 'concluida',
        exitTime: DateTime.now(),
        isSynced: false,
        isEstimated: isEstimated,
      ),
    );
    notifyListeners();
  }

  /// Entrada Rápida: cria reserva já com check-in (sem agendamento prévio)
  /// Usado quando um grupo chega sem reserva — prioridade de volume sobre nome
  Future<void> quickEntry({
    required String placeId,
    required int paxQty,
    String? tabletId,
    String? groupName,
    String? originCity,
  }) async {
    final id = _generateId();
    final now = DateTime.now();
    final reservation = Reservation(
      id: id,
      placeId: placeId,
      paxQty: paxQty,
      guestName: groupName?.trim().isEmpty ?? true
          ? _randomGroupName()
          : groupName!.trim(),
      scheduledTime: now,
      arrivalTime: now,
      status: 'no_local',
      tabletId: tabletId,
      originCity: originCity?.trim().isEmpty ?? true ? null : originCity!.trim(),
    );
    await _reservationsBox.put(id, reservation);
    notifyListeners();
  }

  /// Retorna check-ins sem check-out com mais de [maxHours] horas
  /// Estes são candidatos ao encerramento automático (estimado)
  List<Reservation> staleCheckIns(String placeId, {int maxHours = 4}) {
    final cutoff = DateTime.now().subtract(Duration(hours: maxHours));
    return _reservationsBox.values
        .where((r) =>
            r.placeId == placeId &&
            r.status == 'no_local' &&
            (r.arrivalTime ?? r.scheduledTime).isBefore(cutoff))
        .toList();
  }

  /// Desfaz um check-out recente: concluida → no_local
  Future<void> undoCheckOut(String reservationId) async {
    final r = _reservationsBox.get(reservationId);
    if (r == null || r.status != 'concluida') return;
    final restored = Reservation(
      id: r.id,
      placeId: r.placeId,
      paxQty: r.paxQty,
      guestName: r.guestName,
      contactPhone: r.contactPhone,
      scheduledTime: r.scheduledTime,
      arrivalTime: r.arrivalTime,
      exitTime: null, // limpa o exitTime
      status: 'no_local',
      notes: r.notes,
      tabletId: r.tabletId,
      isSynced: false,
      isEstimated: false,
    );
    await _reservationsBox.put(reservationId, restored);
    notifyListeners();
  }

  /// Cancela uma reserva (status = cancelada)
  Future<void> cancelReservation(String reservationId) async {
    final r = _reservationsBox.get(reservationId);
    if (r == null) return;
    await _reservationsBox.put(
      reservationId,
      r.copyWith(status: 'cancelada', isSynced: false),
    );
    notifyListeners();
  }

  /// Reservas pendentes para um place em uma data específica, ordenadas por horário
  List<Reservation> reservationsByPlace(String placeId, DateTime date) {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return _reservationsBox.values
        .where((r) =>
            r.placeId == placeId &&
            r.status == 'reserva' &&
            r.scheduledTime.isAfter(dayStart.subtract(const Duration(seconds: 1))) &&
            r.scheduledTime.isBefore(dayEnd))
        .toList()
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
  }

  /// Visitantes atualmente no local (status = no_local) para um place
  List<Reservation> onSiteByPlace(String placeId) {
    return _reservationsBox.values
        .where((r) => r.placeId == placeId && r.status == 'no_local')
        .toList()
      ..sort((a, b) => (a.arrivalTime ?? a.scheduledTime)
          .compareTo(b.arrivalTime ?? b.scheduledTime));
  }

  /// Ocupação atual de um place via reservas (soma de paxQty no_local)
  int getReservationOccupancy(String placeId) {
    return onSiteByPlace(placeId)
        .fold<int>(0, (sum, r) => sum + r.paxQty);
  }

  /// Histórico de reservas concluídas de um place em uma data
  List<Reservation> reservationHistoryByPlace(String placeId, DateTime date) {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return _reservationsBox.values
        .where((r) =>
            r.placeId == placeId &&
            r.status == 'concluida' &&
            r.scheduledTime.isAfter(dayStart.subtract(const Duration(seconds: 1))) &&
            r.scheduledTime.isBefore(dayEnd))
        .toList()
      ..sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));
  }

  @override
  void dispose() {
    _syncDownTimer?.cancel();
    _syncService.stopPeriodicSync();
    super.dispose();
  }
}
