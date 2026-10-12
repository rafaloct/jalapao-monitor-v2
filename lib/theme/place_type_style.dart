import 'package:material_ui/material_ui.dart';

import 'jalapao_theme.dart';

/// Ícone, cor e rótulo por tipo de local — fonte única (substitui emoji).
class PlaceTypeStyle {
  PlaceTypeStyle._();

  static const Map<String, IconData> _icons = {
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

  // Tons escuros: ≥ 4.5:1 sobre JalapaoTheme.background.
  static const Map<String, Color> _colors = {
    'fervedouro': JalapaoTheme.secondaryDeep,
    'cachoeira': Color(0xFF1B5E20),
    'atrativo_cultural': Color(0xFF5D4037),
    'camping': Color(0xFF37474F),
    'loja': Color(0xFFBF360C),
    'restaurante': JalapaoTheme.primaryDeep,
    'pousada': JalapaoTheme.accentDeep,
    'fazenda': Color(0xFF33691E),
    'chacaras': Color(0xFF004D40),
  };

  static const Map<String, String> _labels = {
    'fervedouro': 'Fervedouro',
    'cachoeira': 'Cachoeira',
    'atrativo_cultural': 'Atrativo Cultural',
    'camping': 'Camping',
    'loja': 'Loja',
    'restaurante': 'Restaurante',
    'pousada': 'Pousada',
    'fazenda': 'Fazenda',
    'chacaras': 'Chácara',
  };

  static const Map<String, String> _pluralLabels = {
    'fervedouro': 'Fervedouros',
    'cachoeira': 'Cachoeiras',
    'atrativo_cultural': 'Atrativos Culturais',
    'camping': 'Campings',
    'loja': 'Lojas',
    'restaurante': 'Restaurantes',
    'pousada': 'Pousadas',
    'fazenda': 'Fazendas',
    'chacaras': 'Chácaras',
  };

  static IconData icon(String type) => _icons[type] ?? Icons.place;
  static Color color(String type) => _colors[type] ?? JalapaoTheme.textFaint;
  static String label(String type) => _labels[type] ?? type;
  static String pluralLabel(String type) => _pluralLabels[type] ?? type;
  static List<Color> get allColors => _colors.values.toList();
}
