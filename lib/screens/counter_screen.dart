import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/place.dart';
import '../models/place_visit.dart';
import '../providers/place_provider.dart';
import '../services/auth_service.dart';
import '../widgets/pax_selector.dart';
import 'gestor_login_screen.dart';
import 'package:jalapao_monitor/theme/jalapao_theme.dart';

/// Tela de monitoramento para cachoeira, atrativo_cultural, camping, loja.
/// Grupos chegam juntos, entram em momentos distintos, saem juntos.
/// Registra: arrival_time, entry_time (opcional), exit_time via PlaceVisit.
class CounterScreen extends StatefulWidget {
  const CounterScreen({super.key});

  @override
  State<CounterScreen> createState() => _CounterScreenState();
}

class _CounterScreenState extends State<CounterScreen> {
  int _pendingPax = 1;
  bool _registering = false;

  static const _timeFmt = 'HH:mm';

  String _fmt(DateTime? dt) {
    if (dt == null) return '--:--';
    return DateFormat(_timeFmt).format(dt);
  }

  Future<void> _registerArrival(
    PlaceProvider pp,
    String placeId, {
    String? groupName,
    String? originCity,
  }) async {
    setState(() => _registering = true);
    await pp.registerArrival(
      placeId: placeId,
      paxQty: _pendingPax,
      groupName: groupName,
      originCity: originCity,
    );
    setState(() {
      _pendingPax = 1;
      _registering = false;
    });
  }

  void _showRegisterDialog(PlaceProvider pp, String placeId) {
    final groupNameCtrl = TextEditingController();
    final originCityCtrl = TextEditingController();
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: JalapaoTheme.background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Confirmar chegada',
              style: TextStyle(color: JalapaoTheme.textSync),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: groupNameCtrl,
                    autofocus: false,
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
                  const SizedBox(height: 12),
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
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'CANCELAR',
                  style: TextStyle(
                    color: JalapaoTheme.textSync.withOpacity(0.5),
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _registerArrival(
                    pp,
                    placeId,
                    groupName: groupNameCtrl.text,
                    originCity: originCityCtrl.text,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: JalapaoTheme.primary,
                ),
                child: const Text('CONFIRMAR'),
              ),
            ],
          ),
    );
  }

  Future<void> _registerEntry(PlaceProvider pp, String visitId) async {
    await pp.registerEntry(visitId);
  }

  Future<void> _registerExit(PlaceProvider pp, String visitId) async {
    await pp.registerExit(visitId);
  }

  @override
  Widget build(BuildContext context) {
    final pp = context.watch<PlaceProvider>();
    final placeId = pp.activeSessionPlaceId;
    if (placeId == null) return const SizedBox.shrink();

    final place = pp.getPlace(placeId);
    if (place == null) return const SizedBox.shrink();

    final activeVisits =
        pp.visitsByPlace(placeId).where((v) => v.status == 'visiting').toList()
          ..sort((a, b) => a.arrivalTime.compareTo(b.arrivalTime));

    final todayExited =
        pp.visitsByPlace(placeId).where((v) => v.status == 'exited').toList();

    final occupancy = activeVisits.fold<int>(0, (s, v) => s + v.paxQty);
    final todayTotal = [
      ...activeVisits,
      ...todayExited,
    ].fold<int>(0, (s, v) => s + v.paxQty);
    final over = place.capacityTotal > 0 && occupancy > place.capacityTotal;

    return Scaffold(
      backgroundColor: JalapaoTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, place, occupancy, over),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Left panel: registro ───────────────
                  SizedBox(
                    width: 280,
                    child: _buildRegisterPanel(pp, placeId, todayTotal, place),
                  ),
                  Container(
                    width: 1,
                    color: JalapaoTheme.textSync.withValues(alpha: 0.1),
                  ),
                  // ── Right panel: grupos no local ───────
                  Expanded(
                    child: _buildVisitList(pp, activeVisits, todayExited),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    Place place,
    int occupancy,
    bool over,
  ) {
    // 1.6: Gradiente de cores por limiar de capacidade
    final Color capColor;
    if (place.capacityTotal <= 0) {
      capColor = const Color(0xFF58A6FF); // sem limite → azul neutro
    } else {
      final ratio = occupancy / place.capacityTotal;
      if (ratio >= 1.0) {
        capColor = const Color(0xFFFF7B72); // vermelho: lotado
      } else if (ratio >= 0.8) {
        capColor = const Color(0xFFD29922); // amarelo: 80%+
      } else {
        capColor = const Color(0xFF3FB950); // verde: normal
      }
    }

    final capText =
        place.capacityTotal > 0
            ? '$occupancy / ${place.capacityTotal}'
            : '$occupancy';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: JalapaoTheme.background,
        border: Border(
          bottom: BorderSide(
            color: JalapaoTheme.textSync.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.name,
                  style: const TextStyle(
                    color: JalapaoTheme.textSync,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  place.type.toUpperCase().replaceAll('_', ' '),
                  style: TextStyle(
                    color: JalapaoTheme.textSync.withValues(alpha: 0.5),
                    fontSize: 11,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          // Occupancy badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: capColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: capColor.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Icon(Icons.people, color: capColor, size: 18),
                const SizedBox(width: 6),
                Text(
                  capText,
                  style: TextStyle(
                    color: capColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
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
          // Change session button
          IconButton(
            onPressed: () => _confirmChangeSession(context),
            icon: const Icon(Icons.swap_horiz),
            color: Colors.grey.shade500,
            tooltip: 'Trocar local',
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterPanel(
    PlaceProvider pp,
    String placeId,
    int todayTotal,
    Place place,
  ) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'REGISTRAR CHEGADA',
              style: TextStyle(
                color: JalapaoTheme.textSync.withValues(alpha: 0.5),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            PaxSelector(
              // 1.2: maxPax dinâmico baseado na capacidade do lugar; fallback 30
              maxPax: place.capacityTotal > 0 ? place.capacityTotal : 30,
              selectedCount: _pendingPax,
              activeColor: const Color(0xFF3FB950),
              label: 'Pessoas no grupo',
              onChanged: (v) => setState(() => _pendingPax = v),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed:
                    _registering
                        ? null
                        : () => _showRegisterDialog(pp, placeId),
                icon: const Icon(Icons.add_circle_outline, size: 22),
                label: Text(
                  'CHEGOU — $_pendingPax pessoa${_pendingPax > 1 ? "s" : ""}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: JalapaoTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Divider(color: JalapaoTheme.textSync.withValues(alpha: 0.1)),
            const SizedBox(height: 16),
            Text(
              'HOJE',
              style: TextStyle(
                color: JalapaoTheme.textSync.withValues(alpha: 0.5),
                fontSize: 11,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$todayTotal visitantes',
              style: const TextStyle(
                color: JalapaoTheme.textSync,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisitList(
    PlaceProvider pp,
    List<PlaceVisit> active,
    List<PlaceVisit> exited,
  ) {
    if (active.isEmpty && exited.isEmpty) {
      return Center(
        child: Text(
          'Nenhum grupo registrado',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      children: [
        if (active.isNotEmpty) ...[
          _sectionLabel('NO LOCAL (${active.length})'),
          const SizedBox(height: 8),
          ...active.map(
            (v) => _VisitTile(
              visit: v,
              fmt: _fmt,
              onEntry:
                  v.entryTime == null ? () => _registerEntry(pp, v.id) : null,
              onExit: () => _registerExit(pp, v.id),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (exited.isNotEmpty) ...[
          _sectionLabel('SAÍRAM HOJE (${exited.length})'),
          const SizedBox(height: 8),
          ...exited
              .take(20)
              .map(
                (v) => _VisitTile(
                  visit: v,
                  fmt: _fmt,
                  onEntry: null,
                  onExit: null,
                ),
              ),
        ],
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: JalapaoTheme.textSync.withValues(alpha: 0.5),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
    );
  }

  Future<void> _confirmChangeSession(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            backgroundColor: JalapaoTheme.cardQueue, // Cor Adobe
            title: const Text('Trocar local?'),
            content: const Text(
              'Dados locais são mantidos. Você será redirecionado para a seleção de local.',
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
                  style: TextStyle(color: Color(0xFFFF7B72)),
                ),
              ),
            ],
          ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<PlaceProvider>().clearActiveSession();
    }
  }
}

class _VisitTile extends StatelessWidget {
  const _VisitTile({
    required this.visit,
    required this.fmt,
    required this.onEntry,
    required this.onExit,
  });

  final PlaceVisit visit;
  final String Function(DateTime?) fmt;
  final VoidCallback? onEntry;
  final VoidCallback? onExit;

  @override
  Widget build(BuildContext context) {
    final isExited = visit.status == 'exited';
    final hasEntry = visit.entryTime != null;
    final baseColor = isExited ? Colors.grey.shade700 : const Color(0xFF3FB950);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color:
            isExited
                ? JalapaoTheme.textSync.withValues(alpha: 0.03)
                : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color:
              isExited
                  ? JalapaoTheme.textSync.withValues(alpha: 0.1)
                  : JalapaoTheme.primary.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: JalapaoTheme.textSync.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Pax
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: baseColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '${visit.paxQty}',
              style: TextStyle(
                color: baseColor,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Times
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _timeChip(
                      Icons.login,
                      'Chegada',
                      fmt(visit.arrivalTime),
                      JalapaoTheme.textSync.withValues(alpha: 0.5),
                    ),
                    if (hasEntry) ...[
                      const SizedBox(width: 8),
                      _timeChip(
                        Icons.directions_walk,
                        'Entrou',
                        fmt(visit.entryTime),
                        JalapaoTheme.secondary,
                      ),
                    ],
                    if (isExited) ...[
                      const SizedBox(width: 8),
                      _timeChip(
                        Icons.logout,
                        'Saiu',
                        fmt(visit.exitTime),
                        JalapaoTheme.textSync.withValues(alpha: 0.4),
                      ),
                    ],
                  ],
                ),
                if (!isExited &&
                    visit.waitMinutes != null &&
                    visit.waitMinutes! > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      'Espera: ${visit.waitMinutes} min',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Action buttons
          if (!isExited) ...[
            if (onEntry != null)
              _actionBtn(
                icon: Icons.directions_walk,
                label: 'ENTROU',
                color: const Color(0xFF58A6FF),
                onTap: onEntry!,
              ),
            const SizedBox(width: 6),
            _actionBtn(
              icon: Icons.logout,
              label: 'SAIU',
              color: JalapaoTheme.error,
              onTap: onExit!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _timeChip(IconData icon, String label, String time, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text('$label $time', style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
