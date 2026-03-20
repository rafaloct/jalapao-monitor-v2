import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/place.dart';
import '../providers/place_provider.dart';
import '../theme/jalapao_theme.dart';

class PlaceVisitsScreen extends StatefulWidget {
  const PlaceVisitsScreen({super.key});

  @override
  State<PlaceVisitsScreen> createState() => _PlaceVisitsScreenState();
}

class _PlaceVisitsScreenState extends State<PlaceVisitsScreen> {
  String? _selectedPlaceId;
  int _selectedPaxCount = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rastreio de Visitantes'),
        backgroundColor: JalapaoTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Consumer<PlaceProvider>(
        builder: (context, placeProvider, _) {
          final approvedPlaces = placeProvider.approvedPlaces;
          final activeVisits = placeProvider.activeVisits;

          if (approvedPlaces.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.location_off,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Nenhum local aprovado ainda.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Voltar'),
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Seletor de lugar
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Selecione o Local',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedPlaceId,
                        hint: const Text('Escolha um local'),
                        items: approvedPlaces.map((place) {
                          return DropdownMenuItem(
                            value: place.id,
                            child: Text(place.name),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedPlaceId = value;
                            _selectedPaxCount = 1;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Seletor de quantidade
              if (_selectedPlaceId != null)
                Card(
                  color: JalapaoTheme.cardWater,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Quantidade de Visitantes',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove),
                              onPressed: _selectedPaxCount > 1
                                  ? () =>
                                      setState(() => _selectedPaxCount--)
                                  : null,
                            ),
                            Expanded(
                              child: Container(
                                alignment: Alignment.center,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$_selectedPaxCount pessoa${_selectedPaxCount > 1 ? 's' : ''}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: () =>
                                  setState(() => _selectedPaxCount++),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _registerArrival(
                              context,
                              placeProvider,
                            ),
                            icon: const Icon(Icons.login),
                            label: const Text('Registrar Entrada'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 24),

              // Visitantes ativos
              if (activeVisits.isNotEmpty) ...[
                const Text(
                  'Visitantes Ativos',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                ...activeVisits.map((visit) {
                  final place = approvedPlaces.firstWhere(
                    (p) => p.id == visit.placeId,
                    orElse: () => Place(
                      id: '',
                      name: 'Desconhecido',
                      type: '',
                      latitude: 0,
                      longitude: 0,
                      capacityTotal: 0,
                      ownerName: '',
                      contactPhone: '',
                    ),
                  );

                  return _VisitCard(
                    visit: visit,
                    place: place,
                    onExit: () => _registerExit(context, placeProvider, visit.id),
                  );
                }).toList(),
              ] else
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      'Nenhum visitante ativo',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _registerArrival(
    BuildContext context,
    PlaceProvider placeProvider,
  ) async {
    if (_selectedPlaceId == null) return;

    await placeProvider.registerArrival(
      placeId: _selectedPlaceId!,
      paxQty: _selectedPaxCount,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Entrada registrada: $_selectedPaxCount visitante${_selectedPaxCount > 1 ? 's' : ''}',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _registerExit(
    BuildContext context,
    PlaceProvider placeProvider,
    String visitId,
  ) async {
    await placeProvider.registerExit(visitId);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Saída registrada'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

class _VisitCard extends StatelessWidget {
  final dynamic visit;
  final Place place;
  final VoidCallback onExit;

  const _VisitCard({
    required this.visit,
    required this.place,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final duration = DateTime.now().difference(visit.arrivalTime);
    final minutes = duration.inMinutes;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${visit.paxQty} visitante${visit.paxQty > 1 ? 's' : ''}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: JalapaoTheme.cardWater,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$minutes min',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onExit,
                icon: const Icon(Icons.logout),
                label: const Text('Registrar Saída'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
