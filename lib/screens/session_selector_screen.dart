import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/place.dart';
import '../providers/place_provider.dart';
import '../providers/visit_provider.dart';
import '../services/auth_service.dart';
import 'gestor_login_screen.dart';
import '../theme/jalapao_theme.dart';
import '../theme/place_type_style.dart';
import '../widgets/screen_header.dart';

/// Exibida após o onboarding. O agente seleciona o local ativo
/// onde está posicionado. A sessão persiste até troca manual.
class SessionSelectorScreen extends StatefulWidget {
  const SessionSelectorScreen({super.key});

  @override
  State<SessionSelectorScreen> createState() => _SessionSelectorScreenState();
}

class _SessionSelectorScreenState extends State<SessionSelectorScreen> {
  bool _loading = false;

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
                      ? const Center(child: CircularProgressIndicator())
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
    return ScreenHeader(
      leading: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Icon(
          Icons.location_on,
          color: JalapaoTheme.primaryDeep,
          size: 28,
        ),
      ),
      title: const Text('SELECIONAR LOCAL DE MONITORAMENTO'),
      subtitle: Text(
        'Tablet: ${tabletId.isEmpty ? "não configurado" : tabletId}',
      ),
      actions: [
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
                          ? JalapaoTheme.ok
                          : JalapaoTheme.textFaint,
                ),
                tooltip: 'Gestor',
              ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(PlaceProvider placeProvider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, color: JalapaoTheme.textFaint, size: 64),
          const SizedBox(height: 16),
          Text(
            'Nenhum local ativo encontrado',
            style: TextStyle(
              color: JalapaoTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Verifique a conexão ou aguarde aprovação do gestor',
            style: TextStyle(color: JalapaoTheme.textMuted, fontSize: 14),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => placeProvider.syncDownActivePlaces(),
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente'),
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
              color: JalapaoTheme.textMuted,
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
                  typeLabel: PlaceTypeStyle.label(place.type),
                  icon: PlaceTypeStyle.icon(place.type),
                  color: PlaceTypeStyle.color(place.type),
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
    if (ratio >= 0.8) {
      return JalapaoTheme.occupancyColor(currentOccupancy, place.capacityTotal);
    }
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
          color: JalapaoTheme.surface,
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
                  child: Icon(icon, color: color, size: 24),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    typeLabel,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
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
                    style: const TextStyle(
                      color: JalapaoTheme.textMuted,
                      fontSize: 12,
                    ),
                  )
                else
                  Text(
                    'Sem limite de cap.',
                    style: const TextStyle(
                      color: JalapaoTheme.textMuted,
                      fontSize: 12,
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

/// Badge de ocupação em tempo real com gradiente de cores (1.5 + 1.6)
class _OccupancyBadge extends StatelessWidget {
  const _OccupancyBadge({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ratio = total > 0 ? current / total : 0.0;
    final badgeColor = JalapaoTheme.occupancyColor(current, total);
    final label =
        ratio >= 1.0 ? '$current / $total — LOTADO' : '$current / $total agora';

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (ratio >= 0.8) ...[
            Icon(Icons.warning_amber_rounded, size: 16, color: badgeColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: badgeColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
