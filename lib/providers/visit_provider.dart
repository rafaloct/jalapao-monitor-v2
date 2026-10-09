import 'dart:io';
import 'dart:math';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/visit.dart';
import '../services/sync_service.dart';

class VisitProvider extends ChangeNotifier {
  final Box<Visit> _visitsBox;
  final Box _configBox;
  late final SyncService _syncService;

  String? _lastSyncError;
  String? get lastSyncError => _lastSyncError;

  VisitProvider(this._visitsBox, this._configBox) {
    _syncService = SyncService(
      visitsBox: _visitsBox,
      onError: _handleSyncError,
    );
    _syncService.startPeriodicSync();
  }

  void _handleSyncError(String message) {
    _lastSyncError = message;
    notifyListeners();
  }

  void clearSyncError() {
    _lastSyncError = null;
    notifyListeners();
  }

  // ── ID Generator ─────────────────────────────────────
  /// PocketBase IDs must be exactly 15 alphanumeric characters.
  String _generateId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random();
    return List.generate(
      15,
      (index) => chars[rand.nextInt(chars.length)],
    ).join();
  }

  // ── Config Getters ───────────────────────────────────
  String get atrativo => _configBox.get('atrativo', defaultValue: '');
  String get tabletId => _configBox.get('tabletId', defaultValue: '');
  int get poolCapacity => _configBox.get('poolCapacity', defaultValue: 6);
  int get bathTimeMinutes =>
      _configBox.get('bathTimeMinutes', defaultValue: 20);
  bool get isConfigured => _configBox.get('isConfigured', defaultValue: false);

  // ── Config Setters ───────────────────────────────────
  Future<void> saveConfig({
    required String atrativo,
    required String tabletId,
    required int poolCapacity,
    required int bathTimeMinutes,
  }) async {
    await _configBox.put('atrativo', atrativo);
    await _configBox.put('tabletId', tabletId);
    await _configBox.put('poolCapacity', poolCapacity);
    await _configBox.put('bathTimeMinutes', bathTimeMinutes);
    await _configBox.put('isConfigured', true);
    notifyListeners();
  }

  // ── Visit Lists ──────────────────────────────────────
  List<Visit> get queueVisits {
    return _visitsBox.values.where((v) => v.status == 'fila').toList()
      ..sort((a, b) => a.arrivalTime.compareTo(b.arrivalTime));
  }

  List<Visit> get waterVisits {
    return _visitsBox.values.where((v) => v.status == 'agua').toList()..sort(
      (a, b) => (a.entryTime ?? a.arrivalTime).compareTo(
        b.entryTime ?? b.arrivalTime,
      ),
    );
  }

  /// Returns visits created today (local time), sorted by arrival time (descending)
  List<Visit> get historyVisits {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    return _visitsBox.values
        .where((v) => v.arrivalTime.isAfter(todayStart))
        .toList()
      ..sort((a, b) => b.arrivalTime.compareTo(a.arrivalTime));
  }

  int get currentOccupancy {
    return waterVisits.fold(0, (sum, v) => sum + v.paxQty);
  }

  /// Registros locais ainda não enviados ao PocketBase
  int get unsyncedCount => _visitsBox.values.where((v) => !v.isSynced).length;

  // ── Actions ──────────────────────────────────────────
  static const _jalapaoNames = [
    'Ipê',
    'Buriti',
    'Capim-dourado',
    'Cerrado',
    'Veredas',
    'Sertão',
    'Candeia',
    'Pequi',
    'Aroeira',
    'Mangaba',
  ];

  String _randomGroupName() {
    final rand = Random();
    return 'Grupo ${_jalapaoNames[rand.nextInt(_jalapaoNames.length)]}';
  }

  Future<void> addToQueue(
    int paxQty, {
    String? groupName,
    String? originCity,
  }) async {
    final String uid = _generateId();
    final visit = Visit(
      id: uid,
      paxQty: paxQty,
      status: 'fila',
      arrivalTime: DateTime.now(),
      atrativo: atrativo,
      tabletId: tabletId,
      groupId: uid,
      capacityLimit: poolCapacity,
      groupName:
          groupName?.trim().isEmpty ?? true
              ? _randomGroupName()
              : groupName!.trim(),
      originCity:
          originCity?.trim().isEmpty ?? true ? null : originCity!.trim(),
    );
    await _visitsBox.put(visit.id, visit);
    notifyListeners();
  }

  /// Move [enterCount] people from a queue visit into the water.
  Future<void> moveToWater(Visit visit, int enterCount) async {
    final int remaining = visit.paxQty - enterCount;
    final now = DateTime.now();

    if (remaining > 0) {
      // Shrink original visit in queue
      visit.paxQty = remaining;
      visit.isSynced = false;
      await visit.save();

      // New visit for those entering water
      final waterVisit = Visit(
        id: _generateId(),
        paxQty: enterCount,
        status: 'agua',
        arrivalTime: visit.arrivalTime,
        entryTime: now,
        atrativo: atrativo,
        tabletId: tabletId,
        groupId: visit.groupId.isNotEmpty ? visit.groupId : visit.id,
        capacityLimit: poolCapacity,
      );
      await _visitsBox.put(waterVisit.id, waterVisit);
    } else {
      // Whole group enters the water
      visit.status = 'agua';
      visit.entryTime = now;
      visit.isSynced = false;
      if (visit.groupId.isEmpty)
        visit.groupId = visit.id; // Ensure legacy data has groupId
      await visit.save();
    }

    notifyListeners();
  }

  /// Release a group or partial group from the water (mark as concluded).
  Future<void> releasePartially(Visit visit, int exitCount) async {
    final now = DateTime.now();

    if (exitCount >= visit.paxQty) {
      // Full release
      visit.status = 'concluido';
      visit.exitTime = now;
      visit.isSynced = false;
      await visit.save();
    } else {
      // Partial release
      // 1. Update remaining people in water
      visit.paxQty -= exitCount;
      visit.isSynced = false;
      await visit.save();

      // 2. Create new concluded visit for those leaving
      final concludedVisit = Visit(
        id: _generateId(),
        paxQty: exitCount,
        status: 'concluido',
        arrivalTime: visit.arrivalTime,
        entryTime: visit.entryTime,
        exitTime: now,
        atrativo: atrativo,
        tabletId: tabletId,
        groupId: visit.groupId,
        capacityLimit: poolCapacity,
      );
      await _visitsBox.put(concludedVisit.id, concludedVisit);
    }
    notifyListeners();
  }

  /// Release a group from the water (mark as concluded).
  Future<void> release(Visit visit) async {
    await releasePartially(visit, visit.paxQty);
  }

  /// Remove a group from the queue entirely.
  Future<void> removeFromQueue(Visit visit) async {
    await _visitsBox.delete(visit.id);
    notifyListeners();
  }

  /// Force an immediate sync
  Future<void> forceSync() async {
    await _syncService.syncAll();
    notifyListeners();
  }

  // ── Export CSV ───────────────────────────────────────
  Future<void> exportCsv() async {
    final List<List<dynamic>> rows = [];

    // Header (BigQuery Compatible)
    rows.add([
      'id',
      'group_id',
      'arrival_date',
      'atrativo',
      'tablet_id',
      'pax_qty',
      'arrival_time',
      'entry_time',
      'exit_time',
      'stay_duration_min',
      'status',
      'capacity_limit',
    ]);

    final dateFormat = DateFormat('yyyy-MM-dd');
    final timeFormat = DateFormat('HH:mm:ss');

    for (final visit in historyVisits) {
      int? durationMin;
      if (visit.entryTime != null && visit.exitTime != null) {
        durationMin = visit.exitTime!.difference(visit.entryTime!).inMinutes;
      }

      rows.add([
        visit.id,
        visit.groupId,
        dateFormat.format(visit.arrivalTime),
        visit.atrativo,
        visit.tabletId,
        visit.paxQty,
        timeFormat.format(visit.arrivalTime),
        visit.entryTime != null ? timeFormat.format(visit.entryTime!) : '',
        visit.exitTime != null ? timeFormat.format(visit.exitTime!) : '',
        durationMin ?? '',
        visit.status,
        visit.capacityLimit,
      ]);
    }

    final String csvData = const ListToCsvConverter().convert(rows);
    final String dateStr = dateFormat.format(DateTime.now());
    final String fileName = 'relatorio_jalapao_$dateStr.csv';

    // Save and Share
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/$fileName';
    final file = File(path);
    await file.writeAsString(csvData);

    await Share.shareXFiles([
      XFile(path),
    ], text: 'Relatório Jalapão Monitor ($dateStr)');
  }

  @override
  void dispose() {
    _syncService.dispose();
    super.dispose();
  }
}
