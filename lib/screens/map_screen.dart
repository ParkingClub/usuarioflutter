// lib/screens/map_screen.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:io' show Platform;
import 'dart:ui' as ui;
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';



import '../models/sucursal.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController _mapController;
  final Set<Marker> _markers = {};
  late BitmapDescriptor _sucursalIcon;
  bool _loadError = false;


  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(-0.19284, -78.49038),
    zoom: 12,
  );

  @override
  void initState() {
    super.initState();
    _loadMarkerIcon().then((_) {
      _initLocationAndData();
    });
  }



  Future<void> _loadMarkerIcon() async {
    // decide asset según plataforma
    final assetName = Platform.isIOS
        ? 'lib/screens/icons/mi_marker.png'
        : 'lib/screens/icons/mi_marker_android.png';

    final dpr = ui.window.devicePixelRatio;
    _sucursalIcon = await BitmapDescriptor.fromAssetImage(
      ImageConfiguration(devicePixelRatio: dpr),
      assetName,
    );
  }

  Future<void> _openSucursalDetail(int sucursalId) async {
    final resp = await http.get(
      Uri.parse('https://parking-club.com/api/api/sucursales/$sucursalId/modal'),
    );
    if (resp.statusCode != 200) return;

    final jsonData = json.decode(resp.body) as Map<String, dynamic>;
    final nombre = jsonData['nombre'] as String;
    final precio = (jsonData['preciotarifa'] as num).toStringAsFixed(2);
    final plazas = jsonData['plazasdisponibles'].toString();
    final ubicacion = jsonData['ubicacion'] as String;
    String _formatHora(String h) {
      final parts = h.split(':').map(int.parse).toList();
      final date = DateTime(0, 0, 0, parts[0], parts[1]);
      return DateFormat.jm().format(date);
    }
    final apertura = _formatHora(jsonData['horaApertura']);
    final cierre = _formatHora(jsonData['horaCierre']);
    final fotos = (jsonData['fotografias'] as List).cast<String>();

    //calculo de disponibilidad
      // Determina la hora actual en formato “HH:mm:ss”
      final now = TimeOfDay.now();
      bool fueraDeHorario() {
        // parsea strings de apertura y cierre
        final openParts  = (jsonData['horaApertura'] as String).split(':').map(int.parse).toList();
        final closeParts = (jsonData['horaCierre']  as String).split(':').map(int.parse).toList();
        final openTime  = TimeOfDay(hour: openParts[0], minute: openParts[1]);
        final closeTime = TimeOfDay(hour: closeParts[0], minute: closeParts[1]);
        // si before open OR after close → fuera de horario
        if (now.hour < openTime.hour ||
            (now.hour == openTime.hour && now.minute < openTime.minute)) return true;
        if (now.hour > closeTime.hour ||
            (now.hour == closeTime.hour && now.minute > closeTime.minute)) return true;
        return false;
      }

    // bandera general
      final bool disponible = (int.parse(plazas) > 0) && !fueraDeHorario();


    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,  // arranca al 70% de la pantalla
        minChildSize: 0.40,
        maxChildSize: 0.95,

        expand: false,
        // dentro de showModalBottomSheet → DraggableScrollableSheet:
        builder: (_, ctrl) => Container(
          decoration: BoxDecoration(
            color: disponible ? Colors.white : Colors.grey.shade900,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          // ya no necesitas padding aquí, lo pasamos al ScrollView
          child: Stack(
            children: [
              // 1) Contenido principal scrollable
              SingleChildScrollView(
                controller: ctrl,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header row: nombre + Ir button
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            nombre,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            final dest = Uri.encodeComponent(ubicacion);
                            final url = Uri.parse(
                                'https://www.google.com/maps/dir/?api=1&destination=$dest&travelmode=driving'
                            );
                            launchUrl(url, mode: LaunchMode.externalApplication);
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.directions,
                                color: Color(0xFF920606),
                                size: 32,
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Ir',
                                style: TextStyle(
                                  color: Color(0xFF920606),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Image carousel
                    SizedBox(
                      height: 200,
                      child: _ImageCarousel(fotos: fotos),
                    ),
                    const SizedBox(height: 24),

                    // — Primer Card: datos básicos
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            // Precio destacado
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  const Icon(Icons.attach_money, size: 28, color: Color(0xFF920606)),
                                  const SizedBox(width: 12),
                                  Text(
                                    '\$$precio',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF920606),
                                    ),
                                  ),
                                  const Spacer(),
                                  const Text(
                                    'Tarifa',
                                    style: TextStyle(fontSize: 16, color: Colors.black87),
                                  ),
                                ],
                              ),
                            ),
                            // Plazas destacadas
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  const Icon(Icons.local_parking, size: 28, color: Color(0xFF920606)),
                                  const SizedBox(width: 12),
                                  Text(
                                    plazas,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF920606),
                                    ),
                                  ),
                                  const Spacer(),
                                  const Text(
                                    'Plazas disponibles',
                                    style: TextStyle(fontSize: 16, color: Colors.black87),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Resto de filas
                            _buildInfoRow(Icons.location_on, 'Ubicación:', ubicacion),
                            const SizedBox(height: 12),
                            _buildInfoRow(Icons.access_time, 'Horario:', '$apertura – $cierre'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // — Segundo Card: descripción
                    if ((jsonData['descripcion'] as String?)?.isNotEmpty ?? false)
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.info, color: Color(0xFF920606)),
                                  SizedBox(width: 8),
                                  Text(
                                    'Descripción',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                jsonData['descripcion'] as String,
                                style: const TextStyle(color: Colors.black54, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),

                    // — Botones al final: Ir + Cerrar
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              final dest = Uri.encodeComponent(ubicacion);
                              final url = Uri.parse(
                                  'https://www.google.com/maps/dir/?api=1&destination=$dest&travelmode=driving'
                              );
                              launchUrl(url, mode: LaunchMode.externalApplication);
                            },
                            icon: const Icon(Icons.directions, color: Colors.white),
                            label: const Text('Ir', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF920606),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cerrar'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              side: const BorderSide(color: Color(0xFF920606)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),

              // 2) Banner “No está disponible”
              if (!disponible)
                Positioned.fill(
                  child: Container(
                    color: Color.fromRGBO(53, 52, 52, 0.4627450980392157),
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        //color: Colors.grey.shade800.withOpacity(0.9),
                        color: Color.fromRGBO(2, 2, 2, 0.4), // 20% de negro
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Cerrado o No disponible!!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }


// helper para cada fila
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0x1A920606),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF920606), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.black87, fontSize: 16),
              children: [
                TextSpan(text: '$label ' , style: const TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }





  /// Obtiene ubicación, añade marcador de usuario, luego sucursales
  Future<void> _initLocationAndData() async {
    try {
      final pos = await _determinePosition();

      // Centra la cámara en tu ubicación
      _mapController.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(pos.latitude, pos.longitude),
          14,
        ),
      );

      // Carga y añade marcadores de sucursales
      await _cargarSucursales();

      // Refresca el mapa con todos los marcadores
      setState(() {});
    } catch (e) {
      debugPrint('Error inicializando mapa: $e');
    }
  }

  /// Consume la API y añade un Marker por cada sucursal
  Future<void> _cargarSucursales() async {
    final resp = await http.get(
      Uri.parse('https://parking-club.com/api/api/sucursales/ubicaciones'),
    );
    if (resp.statusCode != 200) {
      debugPrint('Error cargando sucursales: ${resp.statusCode}');
      return;
    }

    final List<dynamic> data = json.decode(resp.body) as List<dynamic>;
    setState(() {
      for (final item in data) {
        final suc = Sucursal.fromJson(item as Map<String, dynamic>);
        _markers.add(
          Marker(
            markerId: MarkerId('sucursal_${suc.id}'),
            position: LatLng(suc.lat, suc.lng),
            infoWindow: InfoWindow(title: 'Parqueadero'),
            icon: _sucursalIcon,
            onTap: () => _openSucursalDetail(suc.id),
          ),
        );
      }
    });


  }

  /// Solicita permisos y devuelve la posición actual
  Future<Position> _determinePosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw 'Servicios de ubicación deshabilitados.';
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) {
        throw 'Permiso de ubicación denegado.';
      }
    }
    if (perm == LocationPermission.deniedForever) {
      throw 'Permiso de ubicación denegado permanentemente.';
    }
    return await Geolocator.getCurrentPosition();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //
      key: _scaffoldKey,  // ← añade aquí

      // ← AÑADE ESTE DRAWER
      drawer: SizedBox(
        width: MediaQuery.of(context).size.width * 0.6,
        child: Drawer(
          child: Column(
            children: [
              // Header (igual que tu AppBar pero más grande)
              Container(
                width: double.infinity,
                color: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
                child: Row(
                  children: [
                    const Text(
                      'Parking',
                      style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFF920606), borderRadius: BorderRadius.circular(6)),
                      child: const Text(
                        'Club',
                        style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 28),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              // Opciones
              ListTile(
                leading: const Icon(Icons.place),
                title: const Text('Ir más cercano'),
                onTap: () { /* tu lógica */ },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.list),
                title: const Text('Listar Parqueaderos'),
                onTap: () { /* tu lógica */ },
              ),
              const Spacer(),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout, color: const Color(0xFF920606)),
                title: const Text('Cerrar sesión', style: TextStyle(color: const Color(0xFF920606))),
                onTap: () { /* tu lógica */ },
              ),
            ],
          ),
        ),
      ),
      //
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        // Eliminamos el leading de menú aquí
        title: Row(
          children: [
            const Text(
              'Parking',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF920606),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Club',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          // 1) Tu mapa ocupa toda la pantalla
          GoogleMap(
            initialCameraPosition: _initialPosition,
            onMapCreated: (controller) {
              _mapController = controller;
              // Tan pronto como el mapa esté listo, cargamos ubicación y marcadores:
              _initLocationAndData();
            },
            myLocationEnabled: true,
            zoomControlsEnabled: false,
            markers: _markers,
          ),


          // 2) El botón de menú sobre el mapa, posicionándolo abajo-izquierda
          Positioned(
            bottom: 16,
            left: 16,
            child: GestureDetector(

              onTap: () => _scaffoldKey.currentState?.openDrawer(),
              child: Container(
                width: 53,
                height: 53,
                padding: const EdgeInsets.all(9),
                child: Image.asset(
                  'lib/screens/icons/icono_menu.png',
                  color: const Color(0xE0920606), // pintamos de blanco
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

}


// Carousel widget
class _ImageCarousel extends StatefulWidget {
  final List<String> fotos;
  const _ImageCarousel({required this.fotos, super.key});
  @override
  State<_ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<_ImageCarousel> {
  int _current = 0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        PageView.builder(
          itemCount: widget.fotos.length,
          onPageChanged: (i) => setState(() => _current = i),
          itemBuilder: (_, i) => ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: CachedNetworkImage(
              imageUrl: widget.fotos[i],
              fit: BoxFit.cover,
              placeholder: (_, __) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image, size: 40)),
            ),
          ),
        ),
        Positioned(
          bottom: 8,
          child: Row(
            children: List.generate(widget.fotos.length, (i) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _current == i ? 12 : 8,
                height: 4,
                decoration: BoxDecoration(
                  color: _current == i ? const Color(0xFF920606) : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}