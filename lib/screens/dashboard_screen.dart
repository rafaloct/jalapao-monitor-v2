import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'history_screen.dart';
import 'place_visits_screen.dart';
import 'place_reservation_screen.dart';
import 'gestor_login_screen.dart';
import 'gestor_screen.dart';
import '../models/visit.dart';
import '../providers/visit_provider.dart';
import '../providers/place_provider.dart';
import '../services/auth_service.dart';
import '../widgets/pax_selector.dart';
import '../theme/jalapao_theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Timer? _tickTimer;
  DateTime? _syncErrorSince; // 1.4: rastreia desde quando o erro de sync persiste

  @override
  void initState() {
    super.initState();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    // Seed atrativo + poolCapacity do place ativo (quando selecionado via SessionSelector)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pp = context.read<PlaceProvider>();
      final place = pp.getPlace(pp.activeSessionPlaceId ?? '');
      if (place != null) {
        final vp = context.read<VisitProvider>();
        if (place.name != vp.atrativo || place.capacityTotal != vp.poolCapacity) {
          vp.saveConfig(
            atrativo: place.name,
            tabletId: vp.tabletId,
            poolCapacity: place.capacityTotal > 0 ? place.capacityTotal : vp.poolCapacity,
            bathTimeMinutes: vp.bathTimeMinutes > 0 ? vp.bathTimeMinutes : 20,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }

  // ── Add to Queue Dialog ────────────────────────────
  void _showAddToQueueDialog() {
    int selected = 1;
    final groupNameCtrl = TextEditingController();
    final originCityCtrl = TextEditingController();
    final placeProvider = context.read<PlaceProvider>();
    final activePlaceId = placeProvider.activeSessionPlaceId;
    final activePlace = activePlaceId != null ? placeProvider.getPlace(activePlaceId) : null;
    final int maxPax = (activePlace != null && activePlace.capacityTotal > 0)
        ? activePlace.capacityTotal
        : 30;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: JalapaoTheme.background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.85,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'CHEGADA DE GRUPO',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: JalapaoTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  PaxSelector(
                    maxPax: maxPax,
                    selectedCount: selected,
                    activeColor: JalapaoTheme.primary,
                    label: 'Quantas Pessoas?',
                    onChanged: (v) => setDialogState(() => selected = v),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: groupNameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Nome do grupo (opcional)',
                      labelStyle: TextStyle(color: JalapaoTheme.textSync.withOpacity(0.6)),
                      hintText: 'Ex: Grupo Ipê',
                      hintStyle: TextStyle(color: JalapaoTheme.textSync.withOpacity(0.3)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: originCityCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Cidade de origem (opcional)',
                      labelStyle: TextStyle(color: JalapaoTheme.textSync.withOpacity(0.6)),
                      hintText: 'Ex: Palmas, Brasília...',
                      hintStyle: TextStyle(color: JalapaoTheme.textSync.withOpacity(0.3)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
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
                              color: JalapaoTheme.textSync.withOpacity(0.6),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: selected > 0
                              ? () {
                                  context.read<VisitProvider>().addToQueue(
                                    selected,
                                    groupName: groupNameCtrl.text,
                                    originCity: originCityCtrl.text,
                                  );
                                  Navigator.pop(ctx);
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: JalapaoTheme.primary,
                          ),
                          child: const Text('CONFIRMAR FILA'),
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

  // ── Move to Water Dialog ─────────────────────────────
  void _showMoveToWaterDialog(Visit visit) {
    final provider = context.read<VisitProvider>();
    final int maxAllowed = provider.poolCapacity - provider.currentOccupancy;
    final bool isOverCapacity = maxAllowed < 0;
    int selected = 0;
    final int maxSelectable = visit.paxQty;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: JalapaoTheme.background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ENTRAR NO FERVEDOURO',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: JalapaoTheme.secondary,
                  ),
                ),
                const SizedBox(height: 8),
                isOverCapacity
                    ? Text(
                        '⚠️ Piscina Lotada! (${maxAllowed.abs()} acima)',
                        style: TextStyle(
                          fontSize: 14,
                          color: JalapaoTheme.error,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : Text(
                        'Vagas disponíveis: $maxAllowed',
                        style: TextStyle(
                          fontSize: 14,
                          color: JalapaoTheme.textSync.withOpacity(0.7),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                const SizedBox(height: 24),
                PaxSelector(
                  maxPax: maxSelectable,
                  selectedCount: selected,
                  activeColor: JalapaoTheme.secondary,
                  label: 'Mergulhando',
                  onChanged: (v) => setDialogState(() => selected = v),
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
                            color: JalapaoTheme.textSync.withOpacity(0.6),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: selected > 0
                            ? () {
                                final entryNow = DateTime.now();
                                provider.moveToWater(visit, selected);
                                // Gera PlaceVisit para o Hub (v2.1)
                                final placeProvider = context.read<PlaceProvider>();
                                final sessionPlaceId = placeProvider.activeSessionPlaceId;
                                if (sessionPlaceId != null) {
                                  placeProvider.registerArrival(
                                    placeId: sessionPlaceId,
                                    paxQty: selected,
                                    id: visit.groupId.isNotEmpty ? visit.groupId : visit.id,
                                    arrivalTime: visit.arrivalTime,
                                    entryTime: entryNow,
                                    groupName: visit.groupName,
                                    originCity: visit.originCity,
                                  );
                                }
                                Navigator.pop(ctx);
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: JalapaoTheme.secondary,
                        ),
                        child: const Text('ENTRAR NA ÁGUA'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Release Dialog ───────────────────────────────────
  void _releaseAndClosePlaceVisit(Visit visit) {
    context.read<VisitProvider>().release(visit);
    final placeProvider = context.read<PlaceProvider>();
    if (placeProvider.activeSessionPlaceId != null) {
      placeProvider.registerExit(
        visit.groupId.isNotEmpty ? visit.groupId : visit.id,
      );
    }
  }

  void _showReleaseDialog(Visit visit) {
    int selected = 0;
    if (visit.paxQty == 1) {
      _releaseAndClosePlaceVisit(visit);
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: JalapaoTheme.background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'SAÍDA DO BANHO',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: Colors.green[700],
                  ),
                ),
                const SizedBox(height: 24),
                PaxSelector(
                  maxPax: visit.paxQty,
                  selectedCount: selected,
                  activeColor: const Color(0xFF2E7D32),
                  label: 'Saindo...',
                  onChanged: (v) => setDialogState(() => selected = v),
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
                            color: JalapaoTheme.textSync.withOpacity(0.6),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: selected > 0
                            ? () {
                                context.read<VisitProvider>().releasePartially(visit, selected);
                                // Fecha PlaceVisit quando todo o grupo sai
                                if (selected >= visit.paxQty) {
                                  final placeProvider = context.read<PlaceProvider>();
                                  if (placeProvider.activeSessionPlaceId != null) {
                                    placeProvider.registerExit(
                                      visit.groupId.isNotEmpty ? visit.groupId : visit.id,
                                    );
                                  }
                                }
                                Navigator.pop(ctx);
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                        ),
                        child: const Text('CONFIRMAR SAÍDA'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmChangeSession(PlaceProvider placeProvider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: JalapaoTheme.background,
        title: const Text('Trocar local?',
            style: TextStyle(color: JalapaoTheme.textSync)),
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
            child: Text('Trocar',
                style: TextStyle(color: JalapaoTheme.error)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await placeProvider.clearActiveSession();
    }
  }

  String _elapsed(DateTime from) {
    final diff = DateTime.now().difference(from);
    if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes % 60}min';
    return '${diff.inMinutes}min';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JalapaoTheme.background,
      body: SafeArea(
        child: Consumer<VisitProvider>(
          builder: (context, provider, _) {
            final placeProvider = context.watch<PlaceProvider>();
            return Column(
              children: [
                _buildHeader(provider),
                _buildSyncErrorBanner(provider, placeProvider),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Left: Queue Column (Terra) ─────
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
                          child: _buildQueueColumn(provider),
                        ),
                      ),
                      // ── Right: Water Column (Fervedouro) 
                      Expanded(child: _buildWaterColumn(provider)),
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

  /// 1.4: Banner laranja só após 5 min de erro contínuo (sync crítico).
  /// Abaixo desse limiar, apenas o ícone no header muda de cor.
  Widget _buildSyncErrorBanner(VisitProvider vp, PlaceProvider pp) {
    final error = vp.lastSyncError ?? pp.lastSyncError;

    if (error == null) {
      _syncErrorSince = null; // limpa tracking ao recuperar
      return const SizedBox.shrink();
    }

    // Marca o início do erro (apenas na 1ª vez)
    _syncErrorSince ??= DateTime.now();
    final errorDuration = DateTime.now().difference(_syncErrorSince!);
    final isCritical = errorDuration.inMinutes >= 5;

    if (!isCritical) return const SizedBox.shrink(); // 1.4: aba discreta via ícone no header

    return Container(
      color: Colors.orange[900],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '⚠️ Sync crítico (>${errorDuration.inMinutes}min): $error',
              style: const TextStyle(color: Colors.white, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: () {
              if (vp.lastSyncError != null) vp.clearSyncError();
              if (pp.lastSyncError != null) pp.clearSyncError();
              setState(() => _syncErrorSince = null);
            },
            child: const Icon(Icons.close, color: Colors.white, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(VisitProvider provider) {
    final authService = context.watch<AuthService>();
    final placeProvider = context.watch<PlaceProvider>();
    final activePlaceVisits = placeProvider.activeVisits.length;
    final approvedPlacesCount = placeProvider.approvedPlaces.length;
    final hasSyncError =
        provider.lastSyncError != null || placeProvider.lastSyncError != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: JalapaoTheme.background,
        boxShadow: [
          BoxShadow(
            color: JalapaoTheme.textSync.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: JalapaoTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('👤', style: TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    (placeProvider.getPlace(placeProvider.activeSessionPlaceId ?? '')?.name
                            ?? (provider.atrativo.isNotEmpty ? provider.atrativo : 'Fervedouro'))
                        .toUpperCase(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: JalapaoTheme.textSync,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.timer,
                        size: 14,
                        color: JalapaoTheme.secondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Ciclo de Banho: ${provider.bathTimeMinutes}min',
                        style: TextStyle(
                          fontSize: 14,
                          color: JalapaoTheme.textSync.withOpacity(0.7),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),

              // Mini-stats dos places (se houver places ativos)
              if (approvedPlacesCount > 0) ...[
                _buildPlaceMiniStats(
                  approvedPlacesCount,
                  activePlaceVisits,
                ),
                const SizedBox(width: 8),
              ],

              // Botão Reservas de Locais
              IconButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PlaceReservationScreen(),
                  ),
                ),
                icon: const Icon(Icons.calendar_month, color: JalapaoTheme.primary),
                tooltip: 'Reservas de Locais',
              ),
              const SizedBox(width: 4),

              // Botão Rastreio de Visitantes
              IconButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PlaceVisitsScreen(),
                  ),
                ),
                icon: const Icon(Icons.people_rounded, color: Colors.blue),
                tooltip: 'Rastreio de Visitantes',
              ),
              const SizedBox(width: 4),

              // Botão Gestor
              Tooltip(
                message: authService.isLoggedIn
                    ? 'Painel do Gestor (${authService.gestorName})'
                    : 'Acesso do Gestor',
                child: IconButton(
                  onPressed: () {
                    if (authService.isLoggedIn) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const GestorScreen(),
                        ),
                      );
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const GestorLoginScreen(),
                        ),
                      );
                    }
                  },
                  icon: Icon(
                    Icons.admin_panel_settings,
                    color: authService.isLoggedIn
                        ? Colors.green
                        : Colors.grey[500],
                  ),
                ),
              ),
              const SizedBox(width: 4),

              IconButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HistoryScreen()),
                ),
                icon: const Icon(Icons.history, color: JalapaoTheme.primary),
                tooltip: 'Histórico',
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: () => _confirmChangeSession(placeProvider),
                icon: Icon(Icons.swap_horiz, color: Colors.grey[500]),
                tooltip: 'Trocar local de monitoramento',
              ),
              const SizedBox(width: 4),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    onPressed: () => provider.forceSync(),
                    icon: Icon(
                      Icons.cloud_sync,
                      color: hasSyncError ? Colors.orange : JalapaoTheme.secondary,
                    ),
                    tooltip: hasSyncError
                        ? (provider.lastSyncError ?? placeProvider.lastSyncError ?? 'Erro de sync')
                        : 'Sincronizar',
                  ),
                  if (provider.unsyncedCount > 0)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: JalapaoTheme.error,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            '${provider.unsyncedCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Mini-stats compacto dos places ativos no header
  Widget _buildPlaceMiniStats(int totalPlaces, int activeVisits) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_on, size: 14, color: Colors.blue),
          const SizedBox(width: 4),
          Text(
            '$totalPlaces locais',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.blue,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (activeVisits > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$activeVisits ativos',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQueueColumn(VisitProvider provider) {
    final queue = provider.queueVisits;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Text(
                'FILA DE ESPERA',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: JalapaoTheme.primary,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: JalapaoTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${queue.length} GRUPOS',
                  style: const TextStyle(
                    color: JalapaoTheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: queue.isEmpty
              ? _buildEmptyState('Fila Vazia', 'Ninguém esperando na terra firme.', JalapaoTheme.primary)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: queue.length,
                  itemBuilder: (context, index) => _buildQueueCard(queue[index], provider),
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: double.infinity,
            height: 64,
            child: ElevatedButton.icon(
              onPressed: _showAddToQueueDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: JalapaoTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 8,
                shadowColor: JalapaoTheme.primary.withOpacity(0.4),
              ),
              icon: const Icon(Icons.add, size: 32),
              label: const Text('NOVO GRUPO', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQueueCard(Visit visit, VisitProvider provider) {
    return GestureDetector(
      onTap: () => _showMoveToWaterDialog(visit),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: JalapaoTheme.cardQueue, // Cor de Adobe/Creme
          borderRadius: BorderRadius.circular(20),
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
            Expanded(
              child: Wrap(
                spacing: -8, // Slight overlap for "herd" effect
                runSpacing: 4,
                children: List.generate(
                  visit.paxQty,
                  (_) => Text(
                    '👤',
                    style: TextStyle(
                      fontSize: 24,
                      color: JalapaoTheme.textSync.withOpacity(0.8),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${visit.paxQty} PAX',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: JalapaoTheme.textSync,
                  ),
                ),
                Text(
                  '${_elapsed(visit.arrivalTime)} de espera',
                  style: TextStyle(
                    fontSize: 14,
                    color: JalapaoTheme.textSync.withOpacity(0.6),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: () => provider.removeFromQueue(visit),
              icon: Icon(Icons.close, color: JalapaoTheme.error.withOpacity(0.5)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Capacity Quick-Adjust Dialog ─────────────────────
  void _showCapacityDialog(VisitProvider provider) {
    int tempCap = provider.poolCapacity;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: JalapaoTheme.background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Capacidade do Fervedouro',
            style: TextStyle(color: JalapaoTheme.secondary, fontWeight: FontWeight.w900),
          ),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: tempCap > 1
                    ? () => setDialogState(() => tempCap--)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
                color: JalapaoTheme.secondary,
                iconSize: 32,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '$tempCap',
                  style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900),
                ),
              ),
              IconButton(
                onPressed: () => setDialogState(() => tempCap++),
                icon: const Icon(Icons.add_circle_outline),
                color: JalapaoTheme.secondary,
                iconSize: 32,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('CANCELAR', style: TextStyle(color: JalapaoTheme.textSync.withOpacity(0.5))),
            ),
            ElevatedButton(
              onPressed: () {
                provider.saveConfig(
                  atrativo: provider.atrativo,
                  tabletId: provider.tabletId,
                  poolCapacity: tempCap,
                  bathTimeMinutes: provider.bathTimeMinutes,
                );
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: JalapaoTheme.secondary),
              child: const Text('SALVAR'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaterColumn(VisitProvider provider) {
    final water = provider.waterVisits;
    final int occ = provider.currentOccupancy;
    final int cap = provider.poolCapacity;
    final double ratio = cap > 0 ? (occ / cap).clamp(0.0, 1.0) : 0;

    return Container(
      color: JalapaoTheme.secondary.withOpacity(0.05), // Fundo azulado suave
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Text(
                  'NA ÁGUA',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: JalapaoTheme.secondary,
                    letterSpacing: 1.5,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onLongPress: () => _showCapacityDialog(provider),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$occ / $cap',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: ratio >= 1.0 ? JalapaoTheme.error : JalapaoTheme.secondary,
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: LinearProgressIndicator(
                          value: ratio,
                          backgroundColor: JalapaoTheme.secondary.withOpacity(0.2),
                          valueColor: AlwaysStoppedAnimation(
                              ratio >= 1.0 ? JalapaoTheme.error : JalapaoTheme.secondary),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Text(
                        'segure para ajustar',
                        style: TextStyle(
                          fontSize: 9,
                          color: JalapaoTheme.secondary.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: water.isEmpty
                ? _buildEmptyState('Fervedouro Vazio', 'Águas calmas e cristalinas.', JalapaoTheme.secondary)
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: water.length,
                    itemBuilder: (context, index) => _buildWaterCard(water[index], provider),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaterCard(Visit visit, VisitProvider provider) {
    final timer = _getTimerInfo(visit, provider.bathTimeMinutes);

    return GestureDetector(
      onTap: () => _showReleaseDialog(visit),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: JalapaoTheme.cardWater, // Azul Turquesa
          borderRadius: BorderRadius.circular(20),
          border: timer.isExpired
              ? Border.all(color: JalapaoTheme.error, width: 3)
              : Border.all(color: Colors.transparent, width: 0),
          boxShadow: [
            BoxShadow(
              color: JalapaoTheme.secondary.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: -8,
                runSpacing: 4,
                children: List.generate(
                  visit.paxQty,
                  (_) => const Text(
                    '👤',
                    style: TextStyle(
                      fontSize: 24,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: timer.color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    timer.label, // Timer
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: timer.color == Colors.red ? JalapaoTheme.error : JalapaoTheme.textSync,
                    ),
                  ),
                ),
                Text(
                  '${visit.paxQty} banhista${visit.paxQty > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: JalapaoTheme.textSync.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle, Color color) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.eco, size: 42, color: color.withOpacity(0.3)),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: JalapaoTheme.textSync.withOpacity(0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _TimerInfo _getTimerInfo(Visit visit, int bathMinutes) {
    if (visit.entryTime == null) {
      return _TimerInfo(remaining: Duration.zero, color: Colors.green, label: '--:--', isExpired: false);
    }
    final elapsed = DateTime.now().difference(visit.entryTime!);
    final total = Duration(minutes: bathMinutes);
    final remaining = total - elapsed;

    if (remaining.isNegative) {
      final over = elapsed - total;
      return _TimerInfo(
        remaining: remaining,
        color: JalapaoTheme.error,
        label: '+${over.inMinutes}:${(over.inSeconds % 60).toString().padLeft(2, '0')}',
        isExpired: true,
      );
    } else {
      return _TimerInfo(
        remaining: remaining,
        color: JalapaoTheme.textSync,
        label: '${remaining.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}',
        isExpired: false,
      );
    }
  }
}

class _TimerInfo {
  final Duration remaining;
  final Color color;
  final String label;
  final bool isExpired;

  _TimerInfo({required this.remaining, required this.color, required this.label, required this.isExpired});
}
