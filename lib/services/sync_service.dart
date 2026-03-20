import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive/hive.dart';
import 'package:pocketbase/pocketbase.dart';
import '../config/app_config.dart';
import '../models/visit.dart';
import '../models/place.dart';
import '../models/place_visit.dart';
import '../models/reservation.dart';

class SyncService {
  final PocketBase _pb = PocketBase(AppConfig.pbUrl);

  /// Callback acionado quando um erro de sync ocorre.
  /// Permite que Providers exibam o erro na UI sem acoplamento.
  final void Function(String message)? onError;
  final Box<Visit>? _visitsBox;
  final Box<Place>? _placesBox;
  final Box<PlaceVisit>? _placeVisitsBox;
  final Box<Reservation>? _reservationsBox;
  Timer? _timer;
  bool _isSyncing = false;

  /// Constructor com suporte opcional a Places
  SyncService({
    Box<Visit>? visitsBox,
    Box<Place>? placesBox,
    Box<PlaceVisit>? placeVisitsBox,
    Box<Reservation>? reservationsBox,
    this.onError,
  })  : _visitsBox = visitsBox,
        _placesBox = placesBox,
        _placeVisitsBox = placeVisitsBox,
        _reservationsBox = reservationsBox;

  /// Backwards compatibility constructor
  SyncService.legacy(Box<Visit> visitsBox, {this.onError})
      : _visitsBox = visitsBox,
        _placesBox = null,
        _placeVisitsBox = null,
        _reservationsBox = null;

  void startPeriodicSync() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => syncAll());
    // Also do an immediate sync attempt
    syncAll();
  }

  void stopSync() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> syncAll() async {
    if (_isSyncing) return;

    _isSyncing = true;

    try {
      // Check connectivity safely
      try {
        final connectivityResult = await Connectivity().checkConnectivity();
        if (connectivityResult.contains(ConnectivityResult.none)) return;
      } catch (e) {
        debugPrint('Connectivity check failed: $e');
        return; // Assume offline if check fails
      }

      // Sync v2.0 visits (backwards compatibility)
      if (_visitsBox != null) {
        await _syncVisits();
      }

      // Sync v2.1-beta places and place_visits
      if (_placesBox != null) {
        await _syncPlaces();
      }
      if (_placeVisitsBox != null) {
        await _syncPlaceVisits();
      }
      if (_reservationsBox != null) {
        await _syncReservations();
      }
    } catch (e) {
      debugPrint('General sync error: $e');
      onError?.call('Falha geral de sincronização');
    } finally {
      _isSyncing = false;
    }
  }

  /// Sincroniza visits (v2.0 - funcionalidade existente)
  Future<void> _syncVisits() async {
    if (_visitsBox == null) return;

    final unsyncedVisits =
        _visitsBox.values.where((v) => !v.isSynced).toList();

    for (var visit in unsyncedVisits) {
      try {
        // PocketBase ID limit: 15 chars.
        // If we have an old UUID (> 15 chars), we sanitize it and migrate Hive.
        if (visit.id.length > 15) {
          final oldId = visit.id;
          final newId = oldId.replaceAll('-', '').substring(0, 15);

          // 1. Delete old record FIRST to free the HiveObject instance
          await _visitsBox.delete(oldId);

          // 2. Update the object
          visit.id = newId;
          if (visit.groupId.length > 15) {
            visit.groupId = visit.groupId.replaceAll('-', '').substring(0, 15);
          }

          // 3. Put back with the new key
          await _visitsBox.put(newId, visit);
        } else if (visit.groupId.length > 15) {
          // Handle case where ID is fine but GroupID is old UUID
          visit.groupId = visit.groupId.replaceAll('-', '').substring(0, 15);
          await visit.save();
        }

        // Try to update existing record first, create if not found
        try {
          await _pb
              .collection('visits')
              .update(visit.id, body: visit.toJson());
        } on ClientException catch (e) {
          if (e.statusCode == 404) {
            await _pb.collection('visits').create(body: visit.toJson());
          } else {
            rethrow;
          }
        }
        visit.isSynced = true;
        await visit.save();
      } catch (e) {
        debugPrint('Sync failed for visit ${visit.id}: $e');
        onError?.call('Visita não sincronizada — sem conexão com servidor');
      }
    }
  }

  /// Sincroniza places (v2.1-beta)
  Future<void> _syncPlaces() async {
    if (_placesBox == null) return;

    final unsyncedPlaces =
        _placesBox.values.where((p) => !p.isSynced).toList();

    for (var place in unsyncedPlaces) {
      try {
        // Try to update existing record first, create if not found
        try {
          await _pb
              .collection('places')
              .update(place.id, body: place.toJson());
        } on ClientException catch (e) {
          if (e.statusCode == 404) {
            await _pb.collection('places').create(body: place.toJson());
          } else {
            rethrow;
          }
        }
        place.isSynced = true;
        await place.save();
      } catch (e) {
        debugPrint('Sync failed for place ${place.id}: $e');
        onError?.call('Local "${place.name}" não sincronizado — verifique conexão');
      }
    }
  }

  /// Sincroniza place_visits (v2.1-beta)
  /// CRÍTICO: Tratamento de erro para imagens deletadas
  Future<void> _syncPlaceVisits() async {
    if (_placeVisitsBox == null) return;

    final unsyncedVisits =
        _placeVisitsBox.values.where((pv) => !pv.isSynced).toList();

    for (var visit in unsyncedVisits) {
      try {
        // Try to update existing record first, create if not found
        try {
          await _pb
              .collection('place_visits')
              .update(visit.id, body: visit.toJson());
        } on ClientException catch (e) {
          if (e.statusCode == 404) {
            await _pb.collection('place_visits').create(body: visit.toJson());
          } else {
            rethrow;
          }
        }
        visit.isSynced = true;
        await visit.save();
      } catch (e) {
        debugPrint('Sync failed for place_visit ${visit.id}: $e');
        onError?.call('Registro de visita não sincronizado — verifique conexão');
      }
    }
  }

  /// Sincroniza reservations (v2.1-beta)
  Future<void> _syncReservations() async {
    if (_reservationsBox == null) return;

    final unsynced =
        _reservationsBox.values.where((r) => !r.isSynced).toList();

    for (var reservation in unsynced) {
      try {
        try {
          await _pb
              .collection('reservations')
              .update(reservation.id, body: reservation.toJson());
        } on ClientException catch (e) {
          if (e.statusCode == 404) {
            await _pb
                .collection('reservations')
                .create(body: reservation.toJson());
          } else {
            rethrow;
          }
        }
        reservation.isSynced = true;
        await reservation.save();
      } catch (e) {
        debugPrint('Sync failed for reservation ${reservation.id}: $e');
        onError?.call('Reserva não sincronizada — verifique conexão');
      }
    }
  }

  /// Alias backwards compatibility
  void stopPeriodicSync() => stopSync();

  void dispose() {
    stopSync();
  }
}
