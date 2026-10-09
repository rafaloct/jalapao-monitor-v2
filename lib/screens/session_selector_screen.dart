import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../models/place.dart';
import '../providers/place_provider.dart';
import '../providers/visit_provider.dart';
import '../services/auth_service.dart';
import 'gestor_login_screen.dart';
import 'package:jalapao_monitor/theme/jalapao_theme.dart';

/// Exibida após o onboarding. O agente seleciona o local ativo
/// onde está posicionado. A sessão persiste até troca manual.
class SessionSelectorScreen extends StatefulWidget {
  const SessionSelectorScreen({super.key});

  @override
  State<SessionSelectorScreen> createState() => _SessionSelectorScreenState();
}

class _SessionSelectorScreenState extends State<SessionSelectorScreen> {
  bool _loading = false;

  static const _typeLabels = {
    'fervedouro': 'Fervedouro',
    'cachoeira': 'Cachoeira',
    'atrativo_cultural': 'Atrativo Cultural',
    'camping': 'Camping',
    'loja': 'Loja',
    'restaurante': 'Restaurante',
    'pousada': 'Pousada',
    'fazenda': 'Fazenda',
    'chacaras': 'Chácaras',
  };

  static const _typeIcons = {
    'fervedouro': Icons.water,
    'cachoeira': Icons.waterfall_chart,
    'atrativo_cultural': Icons.museum,
    'camping': Icons.cabin,
    'loja': Icons.store,
    'restaurante': Icons.restaurant,
    'pousada': Icons.hotel,
    'fazenda': Icons.agriculture,
    'chacaras': Icons.park,
  };

  static const _typeColors = {
    'fervedouro': JalapaoTheme.secondary,
    'cachoeira': Color(0xFF2E7D32), // verde
    'atrativo_cultural': Color(0xFF795548), // marrom
    'camping': Color(0xFF455A64), // cinza
    'loja': Color(0xFFE65100), // laranja escuro
    'restaurante': JalapaoTheme.primary,
    'pousada': Color(0xFFF9A825), // ambar
    'fazenda': Color(0xFF33691E), // verde oliva
    'chacaras': Color(0xFF689F38), // verde claro
  };

  Future<void> _selectPlace(BuildContext context, Place place) async {
    setState(() => _loading = true);
    await context.read<PlaceProvider>().setActiveSession(place.id);
    // HomeRouter reacts automatically via notifyListeners
  }

  @override
  Widget build(BuildContext context) {
    final placeProvider = context.watch<PlaceProvider>();
    final visitProvider = context.watch<VisitProvider>();
    final activePlaces = placeProvider.approvedPlaces;

    return Scaffold(
      backgroundColor: JalapaoTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(visitProvider.tabletId),
            Expanded(
              child:
                  _loading
                      ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF58A6FF),
                        ),
                      )
                      : activePlaces.isEmpty
                      ? _buildEmptyState(placeProvider)
                      : _buildPlaceGrid(context, activePlaces, placeProvider),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String tabletId) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
          const Icon(Icons.location_on, color: Color(0xFF58A6FF), size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SELECIONAR LOCAL DE MONITORAMENTO',
                style: TextStyle(
                  color: JalapaoTheme.textSync,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                'Tablet: ${tabletId.isEmpty ? "não configurado" : tabletId}',
                style: TextStyle(
                  color: JalapaoTheme.textSync.withValues(alpha: 0.5),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const Spacer(),
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

  Widget _buildEmptyState(PlaceProvider placeProvider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, color: Colors.grey.shade600, size: 64),
          const SizedBox(height: 16),
          Text(
            'Nenhum local ativo encontrado',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Verifique a conexão ou aguarde aprovação do gestor',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => placeProvider.syncDownActivePlaces(),
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF58A6FF),
              side: const BorderSide(color: Color(0xFF58A6FF)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceGrid(
    BuildContext context,
    List<Place> places,
    PlaceProvider placeProvider,
  ) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Toque no local onde você está posicionado hoje:',
            style: TextStyle(
              color: JalapaoTheme.textSync.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 260,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.4,
              ),
              itemCount: places.length,
              itemBuilder: (context, index) {
                final place = places[index];
                final int occupancy = placeProvider.getCurrentOccupancy(
                  place.id,
                );
                return _PlaceCard(
                  place: place,
                  typeLabel: _typeLabels[place.type] ?? place.type,
                  icon: _typeIcons[place.type] ?? Icons.place,
                  color: _typeColors[place.type] ?? const Color(0xFF8B949E),
                  onTap: () => _selectPlace(context, place),
                  currentOccupancy: occupancy,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({
    required this.place,
    required this.typeLabel,
    required this.icon,
    required this.color,
    required this.onTap,
    this.currentOccupancy = 0,
  });

  final Place place;
  final String typeLabel;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final int currentOccupancy;

  // 1.5 + 1.6: cor da borda por limiar de capacidade
  Color _borderColor() {
    if (place.capacityTotal <= 0) return color.withValues(alpha: 0.4);
    final ratio = currentOccupancy / place.capacityTotal;
    if (ratio >= 1.0) return const Color(0xFFFF7B72); // vermelho: lotado
    if (ratio >= 0.8) return const Color(0xFFD29922); // amarelo: 80%+
    return color.withValues(alpha: 0.4);
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = _borderColor();
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: Colors.white, // Card branco sobre fundo terra
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: borderColor,
            width: borderColor == color.withValues(alpha: 0.4) ? 1.5 : 3.0,
          ),
          boxShadow: [
            BoxShadow(
              color: JalapaoTheme.textSync.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    typeLabel,
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.name,
                  style: const TextStyle(
                    color: JalapaoTheme.textSync,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                // 1.5: badge de ocupação dinâmica em tempo real
                if (place.capacityTotal > 0)
                  _OccupancyBadge(
                    current: currentOccupancy,
                    total: place.capacityTotal,
                  )
                else if (currentOccupancy > 0)
                  Text(
                    '$currentOccupancy agora',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  )
                else
                  Text(
                    'Sem limite de cap.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Badge de ocupação em tempo real com gradiente de cores (1.5 + 1.6)
class _OccupancyBadge extends StatelessWidget {
  const _OccupancyBadge({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ratio = total > 0 ? current / total : 0.0;
    final Color badgeColor;
    final String label;

    if (ratio >= 1.0) {
      badgeColor = const Color(0xFFFF7B72);
      label = '⚠️ $current / $total — LOTADO';
    } else if (ratio >= 0.8) {
      badgeColor = const Color(0xFFD29922);
      label = '⚠️ $current / $total agora';
    } else {
      badgeColor = const Color(0xFF3FB950);
      label = '$current / $total agora';
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        label,
        style: TextStyle(
          color: badgeColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
