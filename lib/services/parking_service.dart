import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/sucursal.dart';

class ParkingService {
  static const String baseUrl = 'https://parking-club.com/api/api';

  static const Map<String, String> _headers = {
    'Accept': 'application/json',
    'Content-Type': 'application/json; charset=UTF-8',
  };

  static Future<List<Sucursal>> getSucursalesUbicaciones() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sucursales/ubicaciones'),
        headers: _headers,
      );

      if (response.statusCode != 200) {
        throw 'Error cargando sucursales: ${response.statusCode}';
      }

      final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      return data.map((item) => Sucursal.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      throw 'Error cargando sucursales: $e';
    }
  }

  static Future<Map<String, dynamic>> getSucursalDetail(int sucursalId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sucursales/$sucursalId/modal'),
        headers: _headers,
      );

      if (response.statusCode != 200) {
        throw 'Error obteniendo detalles: ${response.statusCode}';
      }

      return json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (e) {
      throw 'Error obteniendo detalles: $e';
    }
  }

  static Future<List<Map<String, dynamic>>> listarSucursales() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sucursales/listar_sucursalesMovil'),
        headers: _headers,
      );

      if (response.statusCode != 200) {
        throw 'Error listando sucursales: ${response.statusCode}';
      }

      return (json.decode(utf8.decode(response.bodyBytes)) as List<dynamic>)
          .cast<Map<String, dynamic>>();
    } catch (e) {
      throw 'Error listando sucursales: $e';
    }
  }
}
