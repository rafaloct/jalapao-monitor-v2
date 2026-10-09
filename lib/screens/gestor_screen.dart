import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/place.dart';
import '../providers/place_provider.dart';
import '../services/auth_service.dart';
import '../theme/jalapao_theme.dart';
import 'place_form_screen.dart';

/// Painel do Gestor — aprovação de places + monitoramento de fluxo.
/// Acessível apenas após login no GestorLoginScreen.
class GestorScreen extends StatefulWidget {
  const GestorScreen({super.key});

  @override
  State<GestorScreen> createState() => _GestorScreenState();
}

class _GestorScreenState extends State<GestorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Places pendentes buscados do PocketBase (podem não estar no Hive local)
  List<Map<String, dynamic>> _remotePendingPlaces = [];
  bool _loadingPending = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadPendingFromServer();
  }

  /// Busca places pendentes do PocketBase para o gestor revisar
  Future<void> _loadPendingFromServer() async {
    setState(() => _loadingPending = true);
    final authService = context.read<AuthService>();
    final pending = await authService.fetchPendingPlaces();
    if (!mounted) return;
    setState(() {
      _remotePendingPlaces = pending;
      _loadingPending = false;
    });
  }

  Future<void> _approvePlace(Map<String, dynamic> placeData) async {
    final placeProvider = context.read<PlaceProvider>();
    final authService = context.read<AuthService>();

    final placeId = placeData['id'] as String;
    final localPlace =
        placeProvider.allPlaces.where((p) => p.id == placeId).firstOrNull;

    // #24: sucesso somente com confirmação do servidor — aprovação não
    // confirmada não é exibida como aplicada.
    final success = localPlace != null
        ? await placeProvider.approvePlace(placeId, authService)
        : await placeProvider.approvePlaceRemote(placeData, authService);

    if (!mounted) return;
    if (success) {
      setState(
        () => _remotePendingPlaces.removeWhere((p) => p['id'] == placeId),
      );
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? '✅ "${placeData['name']}" aprovado com sucesso!'
              : '⚠️ "${placeData['name']}" não foi aprovado no servidor.\n'
                  'Verifique a conexão e a sessão do gestor.',
        ),
        backgroundColor: success ? Colors.green : Colors.orange[700],
        duration: Duration(seconds: success ? 3 : 5),
      ),
    );
  }

  Future<void> _rejectPlace(Map<String, dynamic> placeData) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rejeitar local?'),
        content: Text(
          'Deseja rejeitar "${placeData['name']}"?\nO local não ficará disponível para operadores.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Rejeitar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final placeProvider = context.read<PlaceProvider>();
    final authService = context.read<AuthService>();
    final placeId = placeData['id'] as String;

    final localPlace = placeProvider.allPlaces
        .where((p) => p.id == placeId)
        .firstOrNull;

    bool success;
    if (localPlace != null) {
      success = await placeProvider.rejectPlace(placeId, authService);
    } else {
      success = await placeProvider.rejectPlaceRemote(placeData, authService);
    }

    if (!mounted) return;
    if (success) {
      setState(() => _remotePendingPlaces.removeWhere((p) => p['id'] == placeId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ "${placeData['name']}" rejeitado.'),
        ),
      );
    }
  }

  void _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair do painel?'),
        content: const Text('Deseja encerrar a sessão do gestor?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await context.read<AuthService>().logout();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    return Scaffold(
      backgroundColor: JalapaoTheme.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Painel do Gestor',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              authService.gestorName ?? '',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
        backgroundColor: JalapaoTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar pendentes',
            onPressed: _loadPendingFromServer,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: _logout,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(
              text: 'PENDENTES',
              icon: Badge(
                label: Text('${_remotePendingPlaces.length}'),
                isLabelVisible: _remotePendingPlaces.isNotEmpty,
                child: const Icon(Icons.pending_actions, size: 18),
              ),
            ),
            const Tab(text: 'ATIVOS', icon: Icon(Icons.check_circle, size: 18)),
            const Tab(text: 'MONITORAR', icon: Icon(Icons.analytics, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingTab(),
          _buildActiveTab(),
          _buildMonitoringTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PlaceFormScreen()),
        ),
        backgroundColor: JalapaoTheme.primaryColor,
        icon: const Icon(Icons.add_location_alt, color: Colors.white),
        label: const Text(
          'Novo Local',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // ── Tab 1: Places Pendentes ──────────────────────────

  Widget _buildPendingTab() {
    return Consumer<PlaceProvider>(
      builder: (context, placeProvider, _) {
        // IDs já carregados do servidor (já sincronizados)
        final remoteIds =
            _remotePendingPlaces.map((p) => p['id'] as String).toSet();

        // Places locais pendentes ainda não enviados ao PocketBase
        final localOnlyPending = placeProvider.pendingPlaces
            .where((p) => !remoteIds.contains(p.id))
            .map((p) => <String, dynamic>{...p.toJson(), '_localOnly': true})
            .toList();

        // Mescla: locais não sincronizados aparecem primeiro
        final allPending = [...localOnlyPending, ..._remotePendingPlaces];

        if (_loadingPending && allPending.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (allPending.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline,
                    size: 64, color: Colors.green[300]),
                const SizedBox(height: 16),
                const Text(
                  'Nenhum local pendente de aprovação.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _loadPendingFromServer,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Atualizar'),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _loadPendingFromServer,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: allPending.length,
            itemBuilder: (context, index) {
              final placeData = allPending[index];
              final isLocalOnly = placeData['_localOnly'] == true;
              return _PendingPlaceCard(
                placeData: placeData,
                isLocalOnly: isLocalOnly,
                onApprove: () => _approvePlace(placeData),
                onReject: () => _rejectPlace(placeData),
              );
            },
          ),
        );
      },
    );
  }

  // ── Tab 2: Places Ativos ─────────────────────────────

  Widget _buildActiveTab() {
    return Consumer<PlaceProvider>(
      builder: (context, placeProvider, _) {
        final active = placeProvider.approvedPlaces;

        if (active.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_off, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text(
                  'Nenhum local ativo.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Aprove places na aba "Pendentes".',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: active.length,
          itemBuilder: (context, index) {
            final place = active[index];
            final occupancy = placeProvider.getCurrentOccupancy(place.id);
            final avgStay = placeProvider.getAverageStay(place.id);
            final todayVisits = placeProvider
                .visitsByPlace(place.id)
                .where((v) {
                  final today = DateTime.now();
                  return v.arrivalTime.year == today.year &&
                      v.arrivalTime.month == today.month &&
                      v.arrivalTime.day == today.day;
                })
                .length;

            return _ActivePlaceCard(
              place: place,
              occupancy: occupancy,
              avgStayMinutes: avgStay,
              todayVisits: todayVisits,
            );
          },
        );
      },
    );
  }

  // ── Tab 3: Monitoramento Analítico ───────────────────

  Widget _buildMonitoringTab() {
    return Consumer<PlaceProvider>(
      builder: (context, placeProvider, _) {
        final active = placeProvider.approvedPlaces;
        final todayVisitors = placeProvider.totalPlaceVisitorsToday;
        final activeVisits = placeProvider.activeVisits.length;

        if (active.isEmpty) {
          return const Center(
            child: Text(
              'Aprove locais para ver o monitoramento.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        // Agrupar por tipo
        final Map<String, List<Place>> byType = {};
        for (final place in active) {
          byType.putIfAbsent(place.type, () => []).add(place);
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Summary cards
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    label: 'Locais Ativos',
                    value: '${active.length}',
                    icon: Icons.location_on,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    label: 'Visitantes Hoje',
                    value: '$todayVisitors',
                    icon: Icons.people,
                    color: JalapaoTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    label: 'Visitas Ativas',
                    value: '$activeVisits',
                    icon: Icons.person_pin_circle,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Por tipo de place
            ...byType.entries.map((entry) {
              return _PlaceTypeSection(
                type: entry.key,
                places: entry.value,
                placeProvider: placeProvider,
              );
            }),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

// ── Widgets auxiliares ───────────────────────────────────

class _PendingPlaceCard extends StatelessWidget {
  final Map<String, dynamic> placeData;
  final bool isLocalOnly;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PendingPlaceCard({
    required this.placeData,
    required this.isLocalOnly,
    required this.onApprove,
    required this.onReject,
  });

  String _typeLabel(String type) {
    const labels = {
      'fervedouro': '🌊 Fervedouro',
      'cachoeira': '💧 Cachoeira',
      'restaurante': '🍽️ Restaurante',
      'pousada': '🏨 Pousada',
      'fazenda': '🌾 Fazenda',
      'chacaras': '🏡 Chácara',
      'loja': '🏪 Loja',
      'atrativo_cultural': '🎭 Atrativo Cultural',
    };
    return labels[type] ?? type;
  }

  @override
  Widget build(BuildContext context) {
    final name = placeData['name'] ?? 'Sem nome';
    final type = placeData['type'] ?? '';
    final capacity = placeData['capacity_total'] ?? 0;
    final owner = placeData['owner_name'] ?? '';
    final lat = placeData['latitude'];
    final lng = placeData['longitude'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isLocalOnly
              ? Colors.blue.withOpacity(0.4)
              : Colors.orange.withOpacity(0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isLocalOnly
                        ? Colors.blue.withOpacity(0.12)
                        : Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isLocalOnly ? '📱 AGUARDANDO SYNC' : '⏳ PENDENTE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isLocalOnly ? Colors.blue[700] : Colors.orange[700],
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  _typeLabel(type),
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.person, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  owner,
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
                const SizedBox(width: 16),
                Icon(Icons.groups, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Cap: $capacity',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ],
            ),
            if (lat != null && lng != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${(lat as num).toStringAsFixed(4)}, ${(lng as num).toStringAsFixed(4)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close, color: Colors.red),
                    label: const Text(
                      'Rejeitar',
                      style: TextStyle(color: Colors.red),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check, color: Colors.white),
                    label: const Text(
                      'Aprovar',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivePlaceCard extends StatelessWidget {
  final Place place;
  final int occupancy;
  final double? avgStayMinutes;
  final int todayVisits;

  const _ActivePlaceCard({
    required this.place,
    required this.occupancy,
    this.avgStayMinutes,
    required this.todayVisits,
  });

  Color _occupancyColor(int occ, int cap) {
    if (cap <= 0) return Colors.grey;
    final ratio = occ / cap;
    if (ratio >= 1.0) return Colors.red;
    if (ratio >= 0.7) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final ratio = place.capacityTotal > 0
        ? occupancy / place.capacityTotal
        : 0.0;
    final color = _occupancyColor(occupancy, place.capacityTotal);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    place.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$occupancy / ${place.capacityTotal}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Barra de ocupação
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio.clamp(0.0, 1.0),
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _StatChip(
                  icon: Icons.today,
                  label: 'Hoje: $todayVisits visitas',
                ),
                if (avgStayMinutes != null)
                  _StatChip(
                    icon: Icons.timer,
                    label: 'Média: ${avgStayMinutes!.toStringAsFixed(0)}min',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Seção de monitoramento por tipo de place
class _PlaceTypeSection extends StatelessWidget {
  final String type;
  final List<Place> places;
  final PlaceProvider placeProvider;

  const _PlaceTypeSection({
    required this.type,
    required this.places,
    required this.placeProvider,
  });

  static const Map<String, Map<String, dynamic>> _typeInfo = {
    'fervedouro': {
      'label': '🌊 Fervedouros',
      'unit': 'pessoas',
      'metric': 'Ocupação (banho simultâneo)',
    },
    'cachoeira': {
      'label': '💧 Cachoeiras',
      'unit': 'pessoas',
      'metric': 'Ocupação simultânea',
    },
    'restaurante': {
      'label': '🍽️ Restaurantes',
      'unit': 'mesas',
      'metric': 'Mesas ocupadas',
    },
    'pousada': {
      'label': '🏨 Pousadas',
      'unit': 'camas',
      'metric': 'Camas ocupadas',
    },
    'fazenda': {
      'label': '🌾 Fazendas',
      'unit': 'grupos',
      'metric': 'Tours ativos',
    },
    'chacaras': {
      'label': '🏡 Chácaras',
      'unit': 'grupos',
      'metric': 'Tours ativos',
    },
    'loja': {
      'label': '🏪 Lojas',
      'unit': 'pessoas',
      'metric': 'Visitantes ativos',
    },
    'atrativo_cultural': {
      'label': '🎭 Atrativos Culturais',
      'unit': 'pessoas',
      'metric': 'Visitantes ativos',
    },
  };

  @override
  Widget build(BuildContext context) {
    final info = _typeInfo[type] ?? {'label': type, 'unit': 'pessoas', 'metric': 'Ocupação'};

    // Métricas do tipo
    final totalCapacity = places.fold<int>(
      0,
      (sum, p) => sum + p.capacityTotal,
    );
    final totalOccupancy = places.fold<int>(
      0,
      (sum, p) => sum + placeProvider.getCurrentOccupancy(p.id),
    );
    final todayVisits = places.fold<int>(0, (sum, p) {
      final today = DateTime.now();
      return sum +
          placeProvider
              .visitsByPlace(p.id)
              .where(
                (v) =>
                    v.arrivalTime.year == today.year &&
                    v.arrivalTime.month == today.month &&
                    v.arrivalTime.day == today.day,
              )
              .length;
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header do tipo
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: JalapaoTheme.primaryColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Text(
                info['label'] as String,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${places.length} local${places.length > 1 ? 'is' : ''}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // Resumo do tipo
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              _StatChip(
                icon: Icons.equalizer,
                label: '${info['metric']}: $totalOccupancy / $totalCapacity',
              ),
              _StatChip(
                icon: Icons.today,
                label: 'Hoje: $todayVisits visitas',
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Cada place do tipo
        ...places.map((place) {
          final occ = placeProvider.getCurrentOccupancy(place.id);
          final ratio = place.capacityTotal > 0
              ? occ / place.capacityTotal
              : 0.0;
          final color = ratio >= 1.0
              ? Colors.red
              : ratio >= 0.7
              ? Colors.orange
              : Colors.green;

          return Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 6),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    place.name,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Text(
                  '$occ/${place.capacityTotal}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio.clamp(0.0, 1.0),
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 6,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 16),
      ],
    );
  }
}
