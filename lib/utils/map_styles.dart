import 'package:flutter/services.dart';

class MapStyles {
  static String? _darkMapStyle;

  static Future<void> loadMapStyles() async {
    try {
      _darkMapStyle = await rootBundle.loadString('assets/map_styles/dark_map_style.json');
    } catch (e) {
      print("Error cargando estilo del mapa: $e");
    }
  }

  static String? get darkMapStyle => _darkMapStyle;
}
