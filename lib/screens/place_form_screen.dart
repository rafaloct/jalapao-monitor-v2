import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/place.dart';
import '../providers/place_provider.dart';
import '../theme/jalapao_theme.dart';

class PlaceFormScreen extends StatefulWidget {
  const PlaceFormScreen({super.key});

  @override
  State<PlaceFormScreen> createState() => _PlaceFormScreenState();
}

class _PlaceFormScreenState extends State<PlaceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameTEC = TextEditingController();
  final _capacityTEC = TextEditingController();
  final _ownerNameTEC = TextEditingController();
  final _phoneTC = TextEditingController();
  final _descriptionTEC = TextEditingController();
  final _hoursTC = TextEditingController();
  final _latTEC = TextEditingController();
  final _lonTEC = TextEditingController();

  String _selectedType = 'fervedouro';
  double? _latitude;
  double? _longitude;
  bool _locatingGPS = false;
  List<String> _photoPaths = [];

  static const List<String> placeTypes = [
    'fervedouro',
    'cachoeira',
    'restaurante',
    'pousada',
    'fazenda',
    'chacaras',
    'loja',
    'atrativo_cultural'
  ];

  static const Map<String, String> typeLabels = {
    'fervedouro': '🌊 Fervedouro',
    'cachoeira': '💧 Cachoeira',
    'restaurante': '🍽️ Restaurante',
    'pousada': '🏨 Pousada',
    'fazenda': '🌾 Fazenda',
    'chacaras': '🏡 Chácara',
    'loja': '🏪 Loja',
    'atrativo_cultural': '🎭 Atrativo Cultural',
  };

  @override
  void initState() {
    super.initState();
    // GPS solicitado somente ao toque em "Obter Localização" — não no initState,
    // para evitar que o dialog de permissão apareça antes do usuário interagir.
  }

  /// Localização GPS em dois estágios: baixa precisão imediata → alta precisão em background
  Future<void> _getGPS() async {
    setState(() => _locatingGPS = true);

    try {
      // 1. Verifica se o serviço de localização está ativo
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('GPS desativado. Ative a localização no dispositivo.'),
            duration: Duration(seconds: 3),
          ),
        );
        setState(() => _locatingGPS = false);
        return;
      }

      // 2. Verifica/solicita permissão via Geolocator (sem permission_handler)
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permissão de localização negada.'),
              duration: Duration(seconds: 3),
            ),
          );
          setState(() => _locatingGPS = false);
          return;
        }
      }

      // 3. Permissão permanentemente negada — direciona para configurações
      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Localização bloqueada nas configurações do app.',
            ),
            action: SnackBarAction(
              label: 'Configurações',
              onPressed: () => Geolocator.openAppSettings(),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
        setState(() => _locatingGPS = false);
        return;
      }

      // 4. Estágio 1: baixa precisão (resposta imediata)
      final coarse = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 5),
      );

      if (!mounted) return;
      setState(() {
        _latitude = coarse.latitude;
        _longitude = coarse.longitude;
        _latTEC.text = coarse.latitude.toString();
        _lonTEC.text = coarse.longitude.toString();
        // mantém _locatingGPS = true para indicar refinamento em andamento
      });

      // 5. Estágio 2: alta precisão em background
      final precise = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 20),
      );

      if (!mounted) return;
      setState(() {
        _latitude = precise.latitude;
        _longitude = precise.longitude;
        _latTEC.text = precise.latitude.toString();
        _lonTEC.text = precise.longitude.toString();
        _locatingGPS = false;
      });
    } catch (e) {
      // Se refinamento falhar mas já temos coordenada grosseira, mantemos
      if (!mounted) return;
      if (_latitude == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao obter GPS: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      setState(() => _locatingGPS = false);
    }
  }

  /// Abre câmera ou galeria para adicionar fotos
  Future<void> _pickImage() async {
    if (_photoPaths.length >= 5) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Máximo de 5 fotos permitidas'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Câmera'),
              onTap: () async {
                Navigator.pop(context);
                final image = await picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 60,
                  maxWidth: 1920,
                );
                if (image != null) {
                  setState(() => _photoPaths.add(image.path));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Galeria'),
              onTap: () async {
                Navigator.pop(context);
                final image = await picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 60,
                  maxWidth: 1920,
                );
                if (image != null) {
                  setState(() => _photoPaths.add(image.path));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Remove uma foto da lista
  void _removePhoto(int index) {
    setState(() => _photoPaths.removeAt(index));
  }

  /// Salva o lugar offline
  Future<void> _savePlace() async {
    if (!_formKey.currentState!.validate()) return;
    
    final lat = double.tryParse(_latTEC.text);
    final lon = double.tryParse(_lonTEC.text);

    if (lat == null || lon == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('GPS não informado ou inválido. Tente buscar ou digite manualmente (ex: -10.5, -46.6).'),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    // Validação geográfica do Jalapão (espelhando a regra do PocketBase)
    if (lat >= 10.0 || lon >= -40.0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Coordenadas fora da região do Jalapão! Verifique se esqueceu o sinal de menos (Ex: Lat -10.5, Lon -46.6)'),
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    final place = Place(
      id: '', // PlaceProvider gera
      name: _nameTEC.text,
      type: _selectedType,
      latitude: lat,
      longitude: lon,
      capacityTotal: int.parse(_capacityTEC.text),
      ownerName: _ownerNameTEC.text,
      contactPhone: _phoneTC.text,
      description: _descriptionTEC.text,
      operatingHours: _hoursTC.text.isEmpty ? null : _hoursTC.text,
      photoIds: const [], // upload de fotos não implementado — paths locais não vão ao PocketBase
    );

    if (!mounted) return;
    await context.read<PlaceProvider>().addPlace(place);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Local cadastrado com sucesso! Será sincronizado em breve.'),
        duration: Duration(seconds: 3),
      ),
    );

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Novo Local'),
        backgroundColor: JalapaoTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nome
              TextFormField(
                controller: _nameTEC,
                decoration: InputDecoration(
                  labelText: 'Nome do Local *',
                  prefixIcon: const Icon(Icons.location_on),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (v) => v?.isEmpty ?? true ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 12),

              // Tipo
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: InputDecoration(
                  labelText: 'Tipo de Local *',
                  prefixIcon: const Icon(Icons.category),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: placeTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(typeLabels[type] ?? type),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedType = value ?? 'fervedouro'),
              ),
              const SizedBox(height: 12),

              // Capacidade
              TextFormField(
                controller: _capacityTEC,
                decoration: InputDecoration(
                  labelText: 'Capacidade Máxima *',
                  prefixIcon: const Icon(Icons.groups),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v?.isEmpty ?? true ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 12),

              // GPS
              Card(
                color: JalapaoTheme.cardWater,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Localização GPS',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _locatingGPS ? null : _getGPS,
                            icon: const Icon(Icons.my_location),
                            label: Text(_locatingGPS ? 'Buscando...' : 'Obter Localização'),
                          ),
                          if (_locatingGPS) ...[
                            const SizedBox(width: 16),
                            const SizedBox(
                              width: 20, 
                              height: 20, 
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _latTEC,
                              decoration: InputDecoration(
                                labelText: 'Latitude',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _lonTEC,
                              decoration: InputDecoration(
                                labelText: 'Longitude',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Proprietário
              TextFormField(
                controller: _ownerNameTEC,
                decoration: InputDecoration(
                  labelText: 'Nome do Proprietário *',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (v) => v?.isEmpty ?? true ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 12),

              // Telefone
              TextFormField(
                controller: _phoneTC,
                decoration: InputDecoration(
                  labelText: 'Telefone (opcional)',
                  prefixIcon: const Icon(Icons.phone),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Horário de funcionamento
              TextFormField(
                controller: _hoursTC,
                decoration: InputDecoration(
                  labelText: 'Horário (ex: 08:00-18:00)',
                  prefixIcon: const Icon(Icons.access_time),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Descrição
              TextFormField(
                controller: _descriptionTEC,
                decoration: InputDecoration(
                  labelText: 'Descrição (opcional)',
                  prefixIcon: const Icon(Icons.description),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // Fotos
              const Text(
                'Fotos (Máximo 5)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (_photoPaths.isEmpty)
                ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Adicionar Foto'),
                )
              else
                Column(
                  children: [
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: _photoPaths.asMap().entries.map((entry) {
                        return Stack(
                          children: [
                            Image.file(
                              File(entry.value),
                              fit: BoxFit.cover,
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () => _removePhoto(entry.key),
                                child: Container(
                                  color: Colors.red,
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    if (_photoPaths.length < 5)
                      ElevatedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.add_a_photo),
                        label: const Text('Adicionar mais'),
                      ),
                  ],
                ),
              const SizedBox(height: 24),

              // Botão Salvar
              ElevatedButton(
                onPressed: _savePlace,
                style: ElevatedButton.styleFrom(
                  backgroundColor: JalapaoTheme.primaryColor,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text(
                  'Salvar Local Offline',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameTEC.dispose();
    _capacityTEC.dispose();
    _ownerNameTEC.dispose();
    _phoneTC.dispose();
    _descriptionTEC.dispose();
    _hoursTC.dispose();
    _latTEC.dispose();
    _lonTEC.dispose();
    super.dispose();
  }
}
