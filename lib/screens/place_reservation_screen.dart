import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/place.dart';
import '../models/reservation.dart';
import '../providers/place_provider.dart';
import '../services/auth_service.dart';
import '../theme/jalapao_theme.dart';
import '../widgets/pax_selector.dart';
import 'gestor_login_screen.dart';

class PlaceReservationScreen extends StatefulWidget {
  const PlaceReservationScreen({super.key});

  @override
  State<PlaceReservationScreen> createState() => _PlaceReservationScreenState();
}

class _PlaceReservationScreenState extends State<PlaceReservationScreen> {
  Place? _selectedPlace;
  DateTime _selectedDate = DateTime.now();
  Timer? _tickTimer;

  // Contador de anônimos para "Grupo #N"
  int _anonCounter = 1;

  @override
  void initState() {
    super.initState();
    _tickTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }

  // ── Semáforo de ocupação ──────────────────────────────
  Color _semaphoreColor(double ratio) {
    if (ratio >= 0.9) return JalapaoTheme.error;
    if (ratio >= 0.7) return const Color(0xFFF9A825); // âmbar
    return const Color(0xFF2E7D32); // verde escuro
  }

  String _semaphoreIcon(double ratio) {
    if (ratio >= 0.9) return '🔴';
    if (ratio >= 0.7) return '⚠️';
    return '✅';
  }

  // ── Labels por tipo ───────────────────────────────────
  static String _unitLabel(String type) {
    switch (type) {
      case 'restaurante':
        return 'Pessoas';
      case 'pousada':
        return 'Hóspedes';
      case 'fazenda':
      case 'chacaras':
        return 'Pessoas do Grupo';
      case 'fervedouro':
      case 'cachoeira':
        return 'Banhistas';
      default:
        return 'Pessoas';
    }
  }

  static String _typeIcon(String type) {
    switch (type) {
      case 'fervedouro':
        return '🌊';
      case 'cachoeira':
        return '💧';
      case 'restaurante':
        return '🍽️';
      case 'pousada':
        return '🏨';
      case 'fazenda':
        return '🌾';
      case 'chacaras':
        return '🏡';
      case 'loja':
        return '🏪';
      case 'atrativo_cultural':
        return '🎭';
      default:
        return '📍';
    }
  }

  String _elapsed(DateTime from) {
    final diff = DateTime.now().difference(from);
    if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes % 60}min';
    return '${diff.inMinutes}min';
  }

  // ── Trocar Local ─────────────────────────────────────
  Future<void> _confirmChangeSession(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            backgroundColor: JalapaoTheme.background,
            title: const Text(
              'Trocar local?',
              style: TextStyle(color: JalapaoTheme.textSync),
            ),
            content: const Text(
              'Dados locais são mantidos. Você será redirecionado para a seleção de local.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Trocar',
                  style: TextStyle(color: JalapaoTheme.error),
                ),
              ),
            ],
          ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<PlaceProvider>().clearActiveSession();
    }
  }

  // ── Entrada Rápida Dialog ─────────────────────────────
  void _showQuickEntryDialog(PlaceProvider provider) {
    if (_selectedPlace == null) return;
    int paxCount = 1;
    final groupNameCtrl = TextEditingController();
    final originCityCtrl = TextEditingController();

    showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setDialogState) => Dialog(
                  backgroundColor: JalapaoTheme.background,
                  insetPadding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 24,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(ctx).size.height * 0.82,
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '⚡ ENTRADA RÁPIDA',
                            style: Theme.of(context).textTheme.displayMedium
                                ?.copyWith(color: JalapaoTheme.secondary),
                          ),
                          Text(
                            '${_typeIcon(_selectedPlace!.type)} ${_selectedPlace!.name}',
                            style: TextStyle(
                              fontSize: 13,
                              color: JalapaoTheme.textSync.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: JalapaoTheme.secondary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Sem reserva prévia — registra chegada imediata',
                              style: TextStyle(
                                fontSize: 12,
                                color: JalapaoTheme.secondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 24),
                          PaxSelector(
                            selectedCount: paxCount,
                            maxPax: _selectedPlace!.capacityTotal,
                            activeColor: JalapaoTheme.secondary,
                            label: _unitLabel(_selectedPlace!.type),
                            onChanged:
                                (v) => setDialogState(() => paxCount = v),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: groupNameCtrl,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Nome do grupo (opcional)',
                              labelStyle: TextStyle(
                                color: JalapaoTheme.textSync.withOpacity(0.6),
                              ),
                              hintText: 'Ex: Grupo Ipê',
                              hintStyle: TextStyle(
                                color: JalapaoTheme.textSync.withOpacity(0.3),
                              ),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.05),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: originCityCtrl,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Cidade de origem (opcional)',
                              labelStyle: TextStyle(
                                color: JalapaoTheme.textSync.withOpacity(0.6),
                              ),
                              hintText: 'Ex: Palmas, Brasília...',
                              hintStyle: TextStyle(
                                color: JalapaoTheme.textSync.withOpacity(0.3),
                              ),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.05),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: Text(
                                    'CANCELAR',
                                    style: TextStyle(
                                      color: JalapaoTheme.textSync.withOpacity(
                                        0.5,
                                      ),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 2,
                                child: SizedBox(
                                  height: 56,
                                  child: ElevatedButton.icon(
                                    onPressed:
                                        paxCount > 0
                                            ? () {
                                              provider.quickEntry(
                                                placeId: _selectedPlace!.id,
                                                paxQty: paxCount,
                                                groupName: groupNameCtrl.text,
                                                originCity: originCityCtrl.text,
                                              );
                                              Navigator.pop(ctx);
                                            }
                                            : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: JalapaoTheme.secondary,
                                    ),
                                    icon: const Icon(Icons.login, size: 20),
                                    label: const Text(
                                      'REGISTRAR ENTRADA',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          ),
    );
  }

  // ── Nova Reserva Dialog ───────────────────────────────
  void _showAddReservationDialog(PlaceProvider provider) {
    if (_selectedPlace == null) return;

    final guestNameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final originCityCtrl = TextEditingController();
    int paxCount = 1;
    bool isAnonymous = true;
    DateTime scheduledDate = _selectedDate;
    TimeOfDay scheduledTime = TimeOfDay.now();

    showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setDialogState) => Dialog(
                  backgroundColor: JalapaoTheme.background,
                  insetPadding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 24,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(ctx).size.height * 0.82,
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NOVA RESERVA',
                            style: Theme.of(context).textTheme.displayMedium
                                ?.copyWith(color: JalapaoTheme.primary),
                          ),
                          Text(
                            '${_typeIcon(_selectedPlace!.type)} ${_selectedPlace!.name}',
                            style: TextStyle(
                              fontSize: 13,
                              color: JalapaoTheme.textSync.withOpacity(0.6),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Data e Hora lado a lado (touch targets grandes)
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 56,
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      final picked = await showDatePicker(
                                        context: ctx,
                                        initialDate: scheduledDate,
                                        firstDate: DateTime.now().subtract(
                                          const Duration(days: 1),
                                        ),
                                        lastDate: DateTime.now().add(
                                          const Duration(days: 365),
                                        ),
                                      );
                                      if (picked != null) {
                                        setDialogState(
                                          () => scheduledDate = picked,
                                        );
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.calendar_today,
                                      size: 20,
                                    ),
                                    label: Text(
                                      DateFormat(
                                        'dd/MM/yyyy',
                                      ).format(scheduledDate),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SizedBox(
                                  height: 56,
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      final picked = await showTimePicker(
                                        context: ctx,
                                        initialTime: scheduledTime,
                                      );
                                      if (picked != null) {
                                        setDialogState(
                                          () => scheduledTime = picked,
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.schedule, size: 20),
                                    label: Text(
                                      scheduledTime.format(ctx),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Número de pessoas
                          PaxSelector(
                            selectedCount: paxCount,
                            maxPax: _selectedPlace!.capacityTotal,
                            activeColor: JalapaoTheme.primary,
                            label: _unitLabel(_selectedPlace!.type),
                            onChanged:
                                (v) => setDialogState(() => paxCount = v),
                          ),
                          const SizedBox(height: 20),

                          // Nome: campo + botão anônimo lado a lado
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: guestNameCtrl,
                                  enabled: !isAnonymous,
                                  decoration: InputDecoration(
                                    labelText: 'Nome do responsável',
                                    prefixIcon: const Icon(
                                      Icons.person_outline,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onChanged: (_) => setDialogState(() {}),
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Botão ANÔNIMO — elimina barreira do teclado
                              SizedBox(
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: () {
                                    setDialogState(() {
                                      isAnonymous = !isAnonymous;
                                      if (isAnonymous) {
                                        guestNameCtrl.text = '';
                                      }
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        isAnonymous
                                            ? JalapaoTheme.primary
                                            : JalapaoTheme.primary.withOpacity(
                                              0.15,
                                            ),
                                    foregroundColor:
                                        isAnonymous
                                            ? Colors.white
                                            : JalapaoTheme.primary,
                                    elevation: isAnonymous ? 4 : 0,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                  ),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '👤',
                                        style: TextStyle(fontSize: 18),
                                      ),
                                      Text(
                                        'Anônimo',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Telefone
                          TextField(
                            controller: phoneCtrl,
                            decoration: InputDecoration(
                              labelText: 'Telefone (opcional)',
                              prefixIcon: const Icon(Icons.phone_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 12),

                          // Observações
                          TextField(
                            controller: notesCtrl,
                            decoration: InputDecoration(
                              labelText: 'Observações (opcional)',
                              prefixIcon: const Icon(Icons.note_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 12),

                          // Cidade de Origem
                          TextField(
                            controller: originCityCtrl,
                            decoration: InputDecoration(
                              labelText: 'Cidade de origem (opcional)',
                              prefixIcon: const Icon(
                                Icons.location_city_outlined,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              hintText: 'Ex: Palmas, Brasília...',
                            ),
                          ),
                          const SizedBox(height: 24),

                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: Text(
                                    'CANCELAR',
                                    style: TextStyle(
                                      color: JalapaoTheme.textSync.withOpacity(
                                        0.5,
                                      ),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 2,
                                child: SizedBox(
                                  height: 56,
                                  child: ElevatedButton(
                                    onPressed:
                                        paxCount > 0
                                            ? () {
                                              final dt = DateTime(
                                                scheduledDate.year,
                                                scheduledDate.month,
                                                scheduledDate.day,
                                                scheduledTime.hour,
                                                scheduledTime.minute,
                                              );
                                              String name;
                                              if (isAnonymous) {
                                                name =
                                                    'Grupo #${_anonCounter++}';
                                              } else if (guestNameCtrl
                                                  .text
                                                  .isEmpty) {
                                                name =
                                                    'Grupo #${_anonCounter++}';
                                              } else {
                                                name = guestNameCtrl.text;
                                              }
                                              provider.addReservation(
                                                placeId: _selectedPlace!.id,
                                                paxQty: paxCount,
                                                guestName: name,
                                                scheduledTime: dt,
                                                contactPhone:
                                                    phoneCtrl.text.isEmpty
                                                        ? null
                                                        : phoneCtrl.text,
                                                notes:
                                                    notesCtrl.text.isEmpty
                                                        ? null
                                                        : notesCtrl.text,
                                                originCity:
                                                    originCityCtrl.text.isEmpty
                                                        ? null
                                                        : originCityCtrl.text,
                                              );
                                              Navigator.pop(ctx);
                                            }
                                            : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: JalapaoTheme.primary,
                                    ),
                                    child: const Text(
                                      'CONFIRMAR RESERVA',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JalapaoTheme.background,
      body: SafeArea(
        child: Consumer<PlaceProvider>(
          builder: (context, provider, _) {
            final places = provider.approvedPlaces;

            if (_selectedPlace == null) {
              final sessionId = provider.activeSessionPlaceId;
              final sessionPlace =
                  sessionId != null ? provider.getPlace(sessionId) : null;
              final target =
                  (sessionPlace != null && sessionPlace.status == 'active')
                      ? sessionPlace
                      : (places.isNotEmpty ? places.first : null);
              if (target != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _selectedPlace = target);
                });
              }
            }

            final reservations =
                _selectedPlace != null
                    ? provider.reservationsByPlace(
                      _selectedPlace!.id,
                      _selectedDate,
                    )
                    : <Reservation>[];
            final onSite =
                _selectedPlace != null
                    ? provider.onSiteByPlace(_selectedPlace!.id)
                    : <Reservation>[];
            final stale =
                _selectedPlace != null
                    ? provider.staleCheckIns(_selectedPlace!.id)
                    : <Reservation>[];
            final occupancy =
                _selectedPlace != null
                    ? provider.getReservationOccupancy(_selectedPlace!.id)
                    : 0;
            final capacity = _selectedPlace?.capacityTotal ?? 1;
            final ratio = (occupancy / capacity).clamp(0.0, 1.5);
            final isOverCapacity = occupancy >= capacity;

            return Column(
              children: [
                _buildHeader(provider, places, occupancy, capacity, ratio),

                // Banner de superlotação
                if (isOverCapacity)
                  Container(
                    width: double.infinity,
                    color: JalapaoTheme.error,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🔴', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Text(
                          'CAPACIDADE MÁXIMA ATINGIDA — $occupancy / $capacity ${_unitLabel(_selectedPlace?.type ?? '')}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('🔴', style: TextStyle(fontSize: 18)),
                      ],
                    ),
                  ),

                // Banner de check-ins obsoletos (estimados)
                if (stale.isNotEmpty)
                  Container(
                    width: double.infinity,
                    color: const Color(0xFFF9A825).withOpacity(0.15),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        const Text('⏰', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${stale.length} grupo(s) no local há mais de 4h sem check-out. Encerrar automaticamente?',
                            style: TextStyle(
                              fontSize: 12,
                              color: const Color(0xFF7B4F00),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            for (final r in stale) {
                              provider.checkOut(r.id, isEstimated: true);
                            }
                            HapticFeedback.mediumImpact();
                          },
                          child: const Text(
                            'Encerrar (estimado)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF7B4F00),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(
                                color: JalapaoTheme.primary.withOpacity(0.1),
                                width: 2,
                              ),
                            ),
                          ),
                          child: _buildReservationsColumn(
                            provider,
                            reservations,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _buildOnSiteColumn(
                          provider,
                          onSite,
                          occupancy,
                          capacity,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(
    PlaceProvider provider,
    List<Place> places,
    int occupancy,
    int capacity,
    double ratio,
  ) {
    final sColor = _semaphoreColor(ratio);
    final sIcon = _semaphoreIcon(ratio);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: JalapaoTheme.background,
        boxShadow: [
          BoxShadow(
            color: JalapaoTheme.textSync.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _confirmChangeSession(context),
            icon: const Icon(Icons.swap_horiz, color: JalapaoTheme.primary),
            iconSize: 28,
            tooltip: 'Trocar local',
          ),
          const SizedBox(width: 4),

          // Seletor de local
          Expanded(
            flex: 3,
            child:
                places.isEmpty
                    ? Text(
                      'Nenhum local ativo',
                      style: TextStyle(
                        color: JalapaoTheme.textSync.withOpacity(0.5),
                      ),
                    )
                    : DropdownButtonHideUnderline(
                      child: DropdownButton<Place>(
                        value: _selectedPlace,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down),
                        items:
                            places.map((p) {
                              return DropdownMenuItem(
                                value: p,
                                child: Row(
                                  children: [
                                    Text(
                                      _typeIcon(p.type),
                                      style: const TextStyle(fontSize: 20),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        p.name,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15,
                                          color: JalapaoTheme.textSync,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                        onChanged: (p) => setState(() => _selectedPlace = p),
                      ),
                    ),
          ),
          const SizedBox(width: 12),

          // Seletor de data (touch friendly)
          SizedBox(
            height: 44,
            child: OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _selectedDate = picked);
              },
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(
                DateUtils.isSameDay(_selectedDate, DateTime.now())
                    ? 'Hoje'
                    : DateFormat('dd/MM').format(_selectedDate),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Semáforo de ocupação
          if (_selectedPlace != null)
            GestureDetector(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(sIcon, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 4),
                      Text(
                        '$occupancy / $capacity',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: sColor,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    width: 90,
                    child: LinearProgressIndicator(
                      value: ratio.clamp(0.0, 1.0),
                      backgroundColor: sColor.withOpacity(0.15),
                      valueColor: AlwaysStoppedAnimation(sColor),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 12),
          Consumer<AuthService>(
            builder:
                (context, authService, _) => IconButton(
                  onPressed:
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const GestorLoginScreen(),
                        ),
                      ),
                  icon: Icon(
                    Icons.admin_panel_settings,
                    color:
                        authService.isLoggedIn
                            ? Colors.green
                            : Colors.grey[500],
                  ),
                  tooltip: 'Gestor',
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildReservationsColumn(
    PlaceProvider provider,
    List<Reservation> reservations,
  ) {
    return Column(
      children: [
        // Header da coluna
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Text(
                '🗓 RESERVAS',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: JalapaoTheme.primary,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                DateUtils.isSameDay(_selectedDate, DateTime.now())
                    ? '(Hoje)'
                    : DateFormat('dd/MM').format(_selectedDate),
                style: TextStyle(
                  fontSize: 12,
                  color: JalapaoTheme.primary.withOpacity(0.6),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: JalapaoTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${reservations.length}',
                  style: const TextStyle(
                    color: JalapaoTheme.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Lista de reservas com destaque na próxima
        Expanded(
          child:
              reservations.isEmpty
                  ? _buildEmptyState(
                    'Sem Reservas',
                    'Nenhuma reserva para este dia.',
                    JalapaoTheme.primary,
                  )
                  : () {
                    final now = DateTime.now();
                    int highlightIndex = -1;
                    // Encontra a primeira reserva que não passou (ou atraso < 30m)
                    for (int i = 0; i < reservations.length; i++) {
                      if (reservations[i].scheduledTime.isAfter(
                        now.subtract(const Duration(minutes: 30)),
                      )) {
                        highlightIndex = i;
                        break;
                      }
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: reservations.length,
                      itemBuilder:
                          (context, i) => _buildReservationCard(
                            provider,
                            reservations[i],
                            isNext: i == highlightIndex,
                          ),
                    );
                  }(),
        ),

        // Botões na base — touch targets grandes
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
          child: Column(
            children: [
              // Entrada Rápida — destaque máximo
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed:
                      _selectedPlace != null
                          ? () => _showQuickEntryDialog(provider)
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: JalapaoTheme.secondary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  icon: const Icon(Icons.bolt, size: 18),
                  label: const Text(
                    'ENTRADA RÁPIDA',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Nova Reserva — secundário
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed:
                      _selectedPlace != null
                          ? () => _showAddReservationDialog(provider)
                          : null,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: JalapaoTheme.primary.withOpacity(0.6),
                      width: 2,
                    ),
                    foregroundColor: JalapaoTheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.calendar_month, size: 20),
                  label: const Text(
                    'NOVA RESERVA COM HORÁRIO',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReservationCard(
    PlaceProvider provider,
    Reservation r, {
    bool isNext = false,
  }) {
    final now = DateTime.now();
    final isLate = r.scheduledTime.isBefore(now);
    final minutesToGo = r.scheduledTime.difference(now).inMinutes.abs();

    // Cor semáforo por status de pontualidade
    Color timeColor;
    String timeIcon;
    if (isLate) {
      timeColor = JalapaoTheme.error;
      timeIcon = '🔴';
    } else if (minutesToGo <= 15) {
      timeColor = const Color(0xFFF9A825);
      timeIcon = '⚠️';
    } else {
      timeColor = const Color(0xFF2E7D32);
      timeIcon = '🕒';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: JalapaoTheme.cardQueue,
        borderRadius: BorderRadius.circular(16),
        border:
            isNext
                ? Border.all(color: JalapaoTheme.secondary, width: 3)
                : (isLate
                    ? Border.all(
                      color: JalapaoTheme.error.withOpacity(0.5),
                      width: 2,
                    )
                    : Border.all(color: Colors.transparent)),
        boxShadow: [
          BoxShadow(
            color:
                isNext
                    ? JalapaoTheme.secondary.withOpacity(0.2)
                    : JalapaoTheme.textSync.withOpacity(0.04),
            blurRadius: isNext ? 12 : 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Horário — destaque máximo
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: timeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(timeIcon, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('HH:mm').format(r.scheduledTime),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: timeColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.guestName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: JalapaoTheme.textSync,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (r.contactPhone != null)
                      Text(
                        '📞 ${r.contactPhone}',
                        style: TextStyle(
                          fontSize: 11,
                          color: JalapaoTheme.textSync.withOpacity(0.5),
                        ),
                      ),
                  ],
                ),
              ),
              // PAX — alto contraste
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${r.paxQty} PAX',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: JalapaoTheme.textSync,
                    ),
                  ),
                  if (isNext)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: JalapaoTheme.secondary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'PRÓXIMO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (r.notes != null) ...[
            const SizedBox(height: 6),
            Text(
              '📝 ${r.notes}',
              style: TextStyle(
                fontSize: 11,
                color: JalapaoTheme.textSync.withOpacity(0.5),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 10),
          // Botões — touch targets grandes
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () => provider.cancelReservation(r.id),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: JalapaoTheme.error.withOpacity(0.4),
                      ),
                      foregroundColor: JalapaoTheme.error,
                    ),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text(
                      'Cancelar',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      provider.checkIn(r.id);
                      HapticFeedback.lightImpact();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.login, size: 18),
                    label: const Text(
                      '✅ CHECK-IN',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOnSiteColumn(
    PlaceProvider provider,
    List<Reservation> onSite,
    int occupancy,
    int capacity,
  ) {
    return Container(
      color: JalapaoTheme.secondary.withOpacity(0.05),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Text(
                  '📍 NO LOCAL',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: JalapaoTheme.secondary,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: JalapaoTheme.secondary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '$occupancy ${_unitLabel(_selectedPlace?.type ?? '').toLowerCase()}',
                    style: const TextStyle(
                      color: JalapaoTheme.secondary,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child:
                onSite.isEmpty
                    ? _buildEmptyState(
                      'Ninguém no Local',
                      'Aguardando check-ins.',
                      JalapaoTheme.secondary,
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: onSite.length,
                      itemBuilder:
                          (context, i) => _buildOnSiteCard(provider, onSite[i]),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnSiteCard(PlaceProvider provider, Reservation r) {
    final checkInTime = r.arrivalTime ?? r.scheduledTime;
    final elapsed = DateTime.now().difference(checkInTime);
    final isLongStay = elapsed.inHours >= 3;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: JalapaoTheme.cardWater,
        borderRadius: BorderRadius.circular(16),
        border:
            isLongStay
                ? Border.all(color: const Color(0xFFF9A825), width: 2)
                : Border.all(color: Colors.transparent),
        boxShadow: [
          BoxShadow(
            color: JalapaoTheme.secondary.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.guestName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: JalapaoTheme.textSync,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Reserva: ${DateFormat('HH:mm').format(r.scheduledTime)}  •  Entrada: ${DateFormat('HH:mm').format(checkInTime)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: JalapaoTheme.textSync.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${r.paxQty} PAX',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: JalapaoTheme.textSync,
                    ),
                  ),
                  Text(
                    isLongStay
                        ? '⚠️ ${_elapsed(checkInTime)}'
                        : '⏱ ${_elapsed(checkInTime)}',
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          isLongStay
                              ? const Color(0xFFF9A825)
                              : JalapaoTheme.secondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () async {
                HapticFeedback.mediumImpact();
                await provider.checkOut(r.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Check-out de ${r.guestName} registrado'),
                      duration: const Duration(seconds: 5),
                      action: SnackBarAction(
                        label: 'DESFAZER',
                        onPressed: () => provider.undoCheckOut(r.id),
                      ),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.logout, size: 20),
              label: const Text(
                '✅ CHECK-OUT',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle, Color color) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_available,
              size: 56,
              color: color.withOpacity(0.3),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: color.withOpacity(0.6),
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: JalapaoTheme.textSync.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
