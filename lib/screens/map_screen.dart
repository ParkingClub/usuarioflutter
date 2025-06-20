import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:io' show Platform;
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

// Asegúrate de que las rutas sean correctas
import '../models/sucursal.dart';
import '../providers/theme_provider.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;

  final Set<Marker> _markers = {};
  BitmapDescriptor? _sucursalIcon;
  BitmapDescriptor? _userLocationIcon;
  bool _loadError = false;
  Position? _currentPosition;

  Timer? _markerAnimationTimer;
  bool _isUserMarkerFaded = false;

  String? _darkMapStyle;

  final Map<int, LatLng> _sucursalCoordinates = {};
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(-0.19284, -78.49038),
    zoom: 12,
  );

  @override
  void initState() {
    super.initState();
    _loadMarkerIcons();
    _loadMapStyles();

    _markerAnimationTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      _isUserMarkerFaded = !_isUserMarkerFaded;
      if (_currentPosition != null) {
        _updateUserMarker();
      }
    });
  }

  @override
  void dispose() {
    _markerAnimationTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setMapStyle();
  }

  Future<void> _loadMapStyles() async {
    try {
      _darkMapStyle = await rootBundle.loadString('assets/map_styles/dark_map_style.json');
      if (_mapController != null) {
        _setMapStyle();
      }
    } catch (e) {
      debugPrint("Error cargando estilo del mapa: $e");
    }
  }

  void _setMapStyle() {
    if (_mapController == null) return;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    if (isDarkMode) {
      _mapController!.setMapStyle(_darkMapStyle);
    } else {
      _mapController!.setMapStyle(null);
    }
  }

  Future<void> _loadMarkerIcons() async {
    try {
      final assetName = Platform.isIOS
          ? 'lib/screens/icons/mi_marker.png'
          : 'lib/screens/icons/mi_marker_android.png';

      final sucursalIconData = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(devicePixelRatio: 1.5),
        assetName,
      );
      final userIconBytes = await _createUserLocationIcon();
      final userIconData = BitmapDescriptor.fromBytes(userIconBytes);

      if (mounted) {
        setState(() {
          _sucursalIcon = sucursalIconData;
          _userLocationIcon = userIconData;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sucursalIcon = BitmapDescriptor.defaultMarker;
          _userLocationIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
        });
      }
    }
  }

  Future<Uint8List> _createUserLocationIcon() async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    const double size = 120.0;
    const double haloRadius = size / 2;
    const double dotRadius = size / 4;

    final Paint haloPaint = Paint()..color = Colors.blue.withOpacity(0.2)..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(haloRadius, haloRadius), haloRadius, haloPaint);

    final Paint outerPaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(haloRadius, haloRadius), dotRadius, outerPaint);

    final Paint innerPaint = Paint()..color = const Color(0xFF920606)..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(haloRadius, haloRadius), dotRadius / 2, innerPaint);

    final ui.Picture picture = recorder.endRecording();
    final ui.Image img = await picture.toImage(size.toInt(), size.toInt());
    final ByteData? byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _setMapStyle();
    _initLocationAndData();
  }

  Future<void> _initLocationAndData() async {
    int attempts = 0;
    while ((_sucursalIcon == null || _userLocationIcon == null) && attempts < 50) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }

    await _cargarSucursales();

    await _updateUserPosition(moveCamera: false);

    if (!mounted || _currentPosition == null || _markers.isEmpty) {
      if(_currentPosition != null) {
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(_currentPosition!.latitude, _currentPosition!.longitude), 15));
      }
      return;
    }

    final userLocation = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    Marker? nearestMarker;
    double minDistance = double.infinity;

    for (final marker in _markers) {
      if (marker.markerId.value == 'user_location') continue;

      final distance = Geolocator.distanceBetween(
        userLocation.latitude,
        userLocation.longitude,
        marker.position.latitude,
        marker.position.longitude,
      );

      if (distance < minDistance) {
        minDistance = distance;
        nearestMarker = marker;
      }
    }

    if (nearestMarker != null) {
      final parkingLocation = nearestMarker.position;
      final LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(
          min(userLocation.latitude, parkingLocation.latitude),
          min(userLocation.longitude, parkingLocation.longitude),
        ),
        northeast: LatLng(
          max(userLocation.latitude, parkingLocation.latitude),
          max(userLocation.longitude, parkingLocation.longitude),
        ),
      );

      _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80.0));

    } else {
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(userLocation, 15));
    }
  }

  Future<void> _cargarSucursales() async {
    try {
      final resp = await http.get(Uri.parse('https://parking-club.com/api/api/sucursales/ubicaciones'), headers: {'Accept': 'application/json', 'Content-Type': 'application/json; charset=UTF-8'});
      if (resp.statusCode != 200) throw 'Error cargando sucursales: ${resp.statusCode}';
      final List<dynamic> data = json.decode(utf8.decode(resp.bodyBytes));
      final newMarkers = <Marker>{};
      for (final item in data) {
        try {
          final suc = Sucursal.fromJson(item as Map<String, dynamic>);
          _sucursalCoordinates[suc.id] = LatLng(suc.lat, suc.lng);
          final marker = Marker(markerId: MarkerId('sucursal_${suc.id}'), position: LatLng(suc.lat, suc.lng), infoWindow: const InfoWindow(title: 'Parqueadero'), icon: _sucursalIcon!, onTap: () => _openSucursalDetail(suc.id));
          newMarkers.add(marker);
        } catch (e) { debugPrint('Error procesando sucursal: $e'); }
      }
      if (mounted) {
        setState(() {
          _markers.removeWhere((m) => m.markerId.value.startsWith('sucursal_'));
          _markers.addAll(newMarkers);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadError = true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error cargando sucursales: $e')));
      }
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return Future.error('Los servicios de ubicación están deshabilitados.');
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return Future.error('Los permisos de ubicación fueron denegados.');
    }
    if (permission == LocationPermission.deniedForever) return Future.error('Los permisos de ubicación están permanentemente denegados.');
    return await Geolocator.getCurrentPosition();
  }

  void _updateUserMarker() {
    if (!mounted || _currentPosition == null || _userLocationIcon == null) return;

    final userMarker = Marker(
      markerId: const MarkerId('user_location'),
      position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
      icon: _userLocationIcon!,
      alpha: _isUserMarkerFaded ? 0.7 : 1.0,
      zIndex: 10,
      anchor: const Offset(0.5, 0.5),
    );

    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'user_location');
      _markers.add(userMarker);
    });
  }

  Future<void> _updateUserPosition({bool moveCamera = true}) async {
    try {
      final pos = await _determinePosition();
      _currentPosition = pos;

      _updateUserMarker();

      if (moveCamera && _mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(pos.latitude, pos.longitude),
            16.0,
          ),
        );
      }
    } catch(e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo obtener la ubicación: $e')));
      }
    }
  }

  Future<void> _openDirections(double destLat, double destLng) async {
    try {
      Position currentPos = _currentPosition ?? await _determinePosition();
      final String mapsUrl = Platform.isIOS ? 'https://maps.apple.com/?saddr=${currentPos.latitude},${currentPos.longitude}&daddr=$destLat,$destLng&dirflg=d' : 'https://www.google.com/maps/dir/?api=1&origin=${currentPos.latitude},${currentPos.longitude}&destination=$destLat,$destLng&travelmode=driving';
      final Uri url = Uri.parse(mapsUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'No se pudo abrir la aplicación de mapas';
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al abrir direcciones: $e')));
    }
  }

  Future<void> _openSucursalDetail(int sucursalId) async {
    final localContext = context;
    if (!mounted) return;

    try {
      final resp = await http.get(Uri.parse('https://parking-club.com/api/api/sucursales/$sucursalId/modal'), headers: {'Accept': 'application/json', 'Content-Type': 'application/json; charset=UTF-8'});
      if (!mounted) return;
      if (resp.statusCode != 200) throw 'Error obteniendo detalles: ${resp.statusCode}';

      final jsonData = json.decode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      final nombre = jsonData['nombre'] as String? ?? 'Sin nombre';
      final precio = (jsonData['preciotarifa'] as num? ?? 0).toStringAsFixed(2);
      final plazas = (jsonData['plazasdisponibles'] ?? 0).toString();
      final ubicacion = jsonData['ubicacion'] as String? ?? 'Ubicación no disponible';
      final descripcion = jsonData['descripcion'] as String? ?? '';
      final fotos = (jsonData['fotografias'] as List? ?? []).cast<String>();
      final coordinates = _sucursalCoordinates[sucursalId];
      final lat = coordinates?.latitude ?? 0.0;
      final lng = coordinates?.longitude ?? 0.0;

      String formatHora(String h) {
        try {
          final parts = h.split(':').map(int.parse).toList();
          return DateFormat('HH:mm').format(DateTime(0, 0, 0, parts[0], parts[1]));
        } catch (e) { return h; }
      }
      final apertura = formatHora(jsonData['horaApertura'] ?? '00:00');
      final cierre = formatHora(jsonData['horaCierre'] ?? '23:59');

      bool estaAbierto;
      try {
        final now = TimeOfDay.fromDateTime(DateTime.now());
        final openParts = (jsonData['horaApertura'] as String? ?? '00:00').split(':').map(int.parse).toList();
        final closeParts = (jsonData['horaCierre'] as String? ?? '23:59').split(':').map(int.parse).toList();
        final openTime = TimeOfDay(hour: openParts[0], minute: openParts[1]);
        final closeTime = TimeOfDay(hour: closeParts[0], minute: closeParts[1]);
        final nowInMinutes = now.hour * 60 + now.minute;
        final openInMinutes = openTime.hour * 60 + openTime.minute;
        final closeInMinutes = closeTime.hour * 60 + closeTime.minute;
        if (openInMinutes <= closeInMinutes) {
          estaAbierto = nowInMinutes >= openInMinutes && nowInMinutes <= closeInMinutes;
        } else {
          estaAbierto = nowInMinutes >= openInMinutes || nowInMinutes <= closeInMinutes;
        }
      } catch (e) { estaAbierto = true; }

      final String estadoTexto = estaAbierto ? 'Abierto' : 'Cerrado';
      final Color estadoColor = estaAbierto ? Colors.green : Colors.red;

      showModalBottomSheet(
        context: localContext,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        isDismissible: estaAbierto,
        enableDrag: estaAbierto,
        builder: (modalContext) => DraggableScrollableSheet(
          initialChildSize: 0.65, minChildSize: 0.65, maxChildSize: 0.9,
          builder: (_, scrollController) => Stack(
            children: [
              Container(
                color: Theme.of(modalContext).colorScheme.background,
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      width: 40, height: 4,
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                    ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(modalContext).cardColor,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                        ),
                        child: Stack(
                          children: [
                            ListView(
                              controller: scrollController,
                              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                              children: [
                                _buildParkingDetails(
                                  fotos: fotos, nombre: nombre, precio: precio, plazas: plazas,
                                  estadoTexto: estadoTexto, estadoColor: estadoColor,
                                  apertura: apertura, cierre: cierre, ubicacion: ubicacion,
                                  descripcion: descripcion, lat: lat, lng: lng,
                                ),
                              ],
                            ),
                            Positioned(
                              top: 16, right: 16,
                              child: GestureDetector(
                                onTap: () => _openDirections(lat, lng),
                                child: Container(
                                  width: 50, height: 50,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF920606),
                                    shape: BoxShape.circle,
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 4))],
                                  ),
                                  child: const Icon(Icons.directions, color: Colors.white, size: 28),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!estaAbierto)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24)
                        ),
                        child: const Text(
                          'CERRADO',
                          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(localContext).showSnackBar(SnackBar(content: Text('Error abriendo detalles: $e')));
    }
  }

  Widget _buildParkingDetails({
    required List<String> fotos, required String nombre, required String precio, required String plazas,
    required String estadoTexto, required Color estadoColor, required String apertura, required String cierre,
    required String ubicacion, required String descripcion, required double lat, required double lng,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (fotos.isNotEmpty)
          Container(
            height: 220, margin: const EdgeInsets.only(bottom: 16),
            child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _ImageCarousel(fotos: fotos)
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(right: 60.0),
          child: Text(nombre, style: textTheme.titleLarge?.copyWith(fontSize: 26)),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: estadoColor.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
          child: Text(
            estadoTexto,
            style: TextStyle(color: estadoColor, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildInfoColumn(icon: Icons.attach_money, label: 'Tarifa/hora', value: '\$$precio', iconColor: textTheme.bodyLarge!.color!),
            _buildInfoColumn(icon: Icons.local_parking, label: 'Disponibles', value: plazas, iconColor: Colors.blue.shade400),
            _buildInfoColumn(icon: Icons.access_time_rounded, label: 'Horario', value: '$apertura - $cierre', iconColor: Colors.orange.shade400),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0),
          child: Divider(
            color: Theme.of(context).dividerColor,
            thickness: 1,
          ),
        ),
        _buildDetailRow(icon: Icons.location_on_outlined, label: 'Ubicación', value: ubicacion),
        if (descripcion.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildDetailRow(icon: Icons.info_outline, label: 'Descripción', value: descripcion),
        ],
        const SizedBox(height: 32),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          onPressed: () => _openDirections(lat, lng),
          icon: const Icon(Icons.directions, size: 22),
          label: const Text('CÓMO LLEGAR'),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: textTheme.bodyMedium?.color, minimumSize: const Size(double.infinity, 50)),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }

  Widget _buildInfoColumn({
    required IconData icon, required String label, required String value, required Color iconColor,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18)),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildDetailRow({required IconData icon, required String label, required String value}) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: textTheme.bodyMedium?.color, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: textTheme.bodyMedium),
              const SizedBox(height: 4),
              Text(value, style: textTheme.bodyLarge),
            ],
          ),
        ),
      ],
    );
  }

  void _irMasCercano() async {
    final localContext = context;
    if (!mounted) return;
    Navigator.of(localContext).pop();

    if (_markers.isEmpty) return;

    try {
      final pos = await _determinePosition();
      if (!mounted) return;

      _currentPosition = pos;
      Marker? nearest;
      double minDist = double.infinity;
      for (var m in _markers) {
        if (m.markerId.value == 'user_location') continue;
        final d = Geolocator.distanceBetween(pos.latitude, pos.longitude, m.position.latitude, m.position.longitude);
        if (d < minDist) {
          minDist = d;
          nearest = m;
        }
      }
      if (nearest != null) {
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(nearest.position, 16));
        final id = int.parse(nearest.markerId.value.split('_').last);
        _openSucursalDetail(id);
      }
    } catch(e) {
      if(mounted) {
        ScaffoldMessenger.of(localContext).showSnackBar(SnackBar(content: Text('Error obteniendo tu ubicación: $e')));
      }
    }
  }

  void _listarParqueaderos() async {
    final localContext = context;
    if(!mounted) return;
    Navigator.of(localContext).pop();

    try {
      final resp = await http.get(Uri.parse('https://parking-club.com/api/api/sucursales/listar_sucursalesMovil'), headers: {'Accept': 'application/json', 'Content-Type': 'application/json; charset=UTF-8'});
      if (!mounted || resp.statusCode != 200) return;

      final list = json.decode(utf8.decode(resp.bodyBytes)) as List<dynamic>;

      showModalBottomSheet(
        context: localContext,
        builder: (_) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (_, i) {
            final s = list[i] as Map<String, dynamic>;
            final fotos = (s['fotografias'] as List? ?? []).cast<Map<String, dynamic>>();
            final img = fotos.isNotEmpty ? fotos.first['fotografia'] as String : '';
            return ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: img.isNotEmpty ? Image.network(img, width: 56, height: 56, fit: BoxFit.cover) : const Icon(Icons.local_parking, size: 56, color: Color(0xFF920606)),
              ),
              title: Text(s['nombre'] as String),
              subtitle: Text(s['ubicacion'] as String),
              trailing: Text('\$${(s['preciotarifa'] as num).toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF920606), fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.of(localContext).pop();
                _openSucursalDetail(s['id'] as int);
              },
            );
          },
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(localContext).showSnackBar(SnackBar(content: Text('Error listando sucursales: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        backgroundColor: Theme.of(context).cardColor,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: Colors.black,
              padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 16, 16, 16),
              child: Row(
                children: [
                  const Text('Parking', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFF920606), borderRadius: BorderRadius.circular(6)),
                    child: const Text('Club', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            ListTile(leading: const Icon(Icons.place_outlined), title: const Text('Ir al más cercano'), onTap: _irMasCercano),
            const Divider(height: 1),
            ListTile(leading: const Icon(Icons.view_list_outlined), title: const Text('Listar Parqueaderos'), onTap: _listarParqueaderos),
            const Divider(height: 1),
            SwitchListTile(
              title: const Text("Modo Oscuro"),
              value: Provider.of<ThemeProvider>(context).themeMode == ThemeMode.dark,
              onChanged: (value) {
                Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
              },
              secondary: const Icon(Icons.dark_mode_outlined),
            ),
            const Spacer(),
            const Divider(height: 1),
            ListTile(leading: const Icon(Icons.logout, color: Color(0xFF920606)), title: const Text('Cerrar sesión', style: TextStyle(color: Color(0xFF920606))), onTap: () {}),
          ],
        ),
      ),
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        title: Row(
          children: [
            const Text('Parking', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFF920606), borderRadius: BorderRadius.circular(4)),
              child: const Text('Club', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
      body: GoogleMap(
        initialCameraPosition: _initialPosition,
        onMapCreated: _onMapCreated,
        myLocationEnabled: false,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        markers: _markers,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await _updateUserPosition(moveCamera: true);
        },
        backgroundColor: const Color(0xFF920606),
        tooltip: 'Mi Ubicación',
        child: const Icon(Icons.my_location, color: Colors.white),
      ),
    );
  }
}

class _ImageCarousel extends StatefulWidget {
  final List<String> fotos;
  const _ImageCarousel({super.key, required this.fotos});
  @override
  State<_ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<_ImageCarousel> {
  int _current = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.fotos.isEmpty) {
      return const SizedBox.shrink();
    }
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        PageView.builder(
          itemCount: widget.fotos.length,
          onPageChanged: (i) => setState(() => _current = i),
          itemBuilder: (_, i) => CachedNetworkImage(
            imageUrl: widget.fotos[i],
            fit: BoxFit.cover,
            placeholder: (_, __) => const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF920606))),
            errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image, size: 40)),
          ),
        ),
        if (widget.fotos.length > 1)
          Positioned(
            bottom: 8,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.fotos.length, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _current == i ? 12 : 8,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _current == i ? const Color(0xFF920606) : Colors.white.withAlpha(178),
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