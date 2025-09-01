import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:io' show Platform;
import 'package:url_launcher/url_launcher.dart';

import '../models/sucursal.dart';
import '../services/parking_service.dart';
import '../services/location_service.dart';
import '../utils/map_styles.dart';
import '../widgets/map_drawer.dart';
import '../widgets/parking_detail_modal.dart';
import '../widgets/parking_list_modal.dart';
import '../widgets/contact_modal.dart';

enum MarkerFilter { all, verified, unverified }

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;

  final Set<Marker> _markers = {};
  final Set<Marker> _verifiedMarkers = {};
  final Set<Marker> _unverifiedMarkers = {};
  Marker? _userMarker;

  MarkerFilter _currentFilter = MarkerFilter.all;

  // Iconos para parqueaderos verificados
  BitmapDescriptor? _verifiedParkingIconSmall;
  BitmapDescriptor? _verifiedParkingIconMedium;
  BitmapDescriptor? _verifiedParkingIconLarge;
  BitmapDescriptor? _verifiedParkingIconXLarge;

  // Iconos para parqueaderos no verificados
  BitmapDescriptor? _unverifiedParkingIconSmall;
  BitmapDescriptor? _unverifiedParkingIconMedium;
  BitmapDescriptor? _unverifiedParkingIconLarge;
  BitmapDescriptor? _unverifiedParkingIconXLarge;

  BitmapDescriptor? _userLocationIcon;

  double _currentZoom = 12.0;

  List<Sucursal> _sucursalesData = [];
  List<Map<String, dynamic>> _unverifiedLocationsData = [];

  bool _loadError = false;
  Position? _currentPosition;
  Timer? _markerAnimationTimer;
  bool _isUserMarkerFaded = false;
  final Map<int, LatLng> _sucursalCoordinates = {};
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(-0.19284, -78.49038),
    zoom: 12,
  );

  @override
  void initState() {
    super.initState();
    _currentZoom = _initialPosition.zoom;
    _initializeMap();
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

  Future<void> _initializeMap() async {
    await MapStyles.loadMapStyles();
    await _loadMarkerIcons();
    _startMarkerAnimation();
  }

  void _startMarkerAnimation() {
    _markerAnimationTimer = Timer.periodic(
      const Duration(milliseconds: 1200),
          (_) {
        _isUserMarkerFaded = !_isUserMarkerFaded;
        if (_currentPosition != null) {
          _updateUserMarker();
          _applyFilter();
        }
      },
    );
  }

  void _applyFilter() {
    final Set<Marker> visibleMarkers = {};

    switch (_currentFilter) {
      case MarkerFilter.all:
        visibleMarkers.addAll(_verifiedMarkers);
        visibleMarkers.addAll(_unverifiedMarkers);
        break;
      case MarkerFilter.verified:
        visibleMarkers.addAll(_verifiedMarkers);
        break;
      case MarkerFilter.unverified:
        visibleMarkers.addAll(_unverifiedMarkers);
        break;
    }

    if (_userMarker != null) {
      visibleMarkers.add(_userMarker!);
    }

    setState(() {
      _markers.clear();
      _markers.addAll(visibleMarkers);
    });
  }

  void _onFilterChanged(MarkerFilter newFilter) {
    if (_currentFilter == newFilter) {
      _scaffoldKey.currentState?.closeDrawer();
      return;
    }

    _currentFilter = newFilter;
    _applyFilter();

    _scaffoldKey.currentState?.closeDrawer();
  }

  void _setMapStyle() {
    if (_mapController == null) return;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    if (isDarkMode) {
      _mapController!.setMapStyle(MapStyles.darkMapStyle);
    } else {
      _mapController!.setMapStyle(null);
    }
  }

  Future<BitmapDescriptor> _bitmapDescriptorFromAsset(
      String assetPath, {
        int targetWidth = 72,
      }) async {
    final byteData = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(
      byteData.buffer.asUint8List(),
      targetWidth: targetWidth,
    );
    final frameInfo = await codec.getNextFrame();
    final resizedBytes = (await frameInfo.image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!
        .buffer
        .asUint8List();
    return BitmapDescriptor.fromBytes(resizedBytes);
  }

  Future<void> _loadMarkerIcons() async {
    try {
      const verifiedAssetName = 'lib/screens/icons/MarkMapV.png';
      const unverifiedAssetName = 'lib/screens/icons/MarkMapSV.png';

      // Cargar íconos verificados
      _verifiedParkingIconSmall = await _bitmapDescriptorFromAsset(verifiedAssetName, targetWidth: 80);
      _verifiedParkingIconMedium = await _bitmapDescriptorFromAsset(verifiedAssetName, targetWidth: 100);
      _verifiedParkingIconLarge = await _bitmapDescriptorFromAsset(verifiedAssetName, targetWidth: 125);
      _verifiedParkingIconXLarge = await _bitmapDescriptorFromAsset(verifiedAssetName, targetWidth: 150);

      // Cargar íconos no verificados
      _unverifiedParkingIconSmall = await _bitmapDescriptorFromAsset(unverifiedAssetName, targetWidth: 70);
      _unverifiedParkingIconMedium = await _bitmapDescriptorFromAsset(unverifiedAssetName, targetWidth: 85);
      _unverifiedParkingIconLarge = await _bitmapDescriptorFromAsset(unverifiedAssetName, targetWidth: 100);
      _unverifiedParkingIconXLarge = await _bitmapDescriptorFromAsset(unverifiedAssetName, targetWidth: 125);

      _userLocationIcon = BitmapDescriptor.fromBytes(await _createUserLocationIcon());

      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() {
          final defaultIcon = BitmapDescriptor.defaultMarker;
          _verifiedParkingIconSmall = defaultIcon;
          _verifiedParkingIconMedium = defaultIcon;
          _verifiedParkingIconLarge = defaultIcon;
          _verifiedParkingIconXLarge = defaultIcon;
          _unverifiedParkingIconSmall = defaultIcon;
          _unverifiedParkingIconMedium = defaultIcon;
          _unverifiedParkingIconLarge = defaultIcon;
          _unverifiedParkingIconXLarge = defaultIcon;
          _userLocationIcon = BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueBlue,
          );
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

    final Paint haloPaint = Paint()
      ..color = Colors.blue.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(haloRadius, haloRadius), haloRadius, haloPaint);

    final Paint outerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(haloRadius, haloRadius), dotRadius, outerPaint);

    final Paint innerPaint = Paint()
      ..color = const Color(0xFF920606)
      ..style = PaintingStyle.fill;
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
    while ((_verifiedParkingIconSmall == null || _userLocationIcon == null) && attempts < 50) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }

    await Future.wait([
      _cargarSucursales(),
      _cargarUbicacionesNoAceptadas(),
    ]);

    _rebuildMarkersOnZoom();

    await _updateUserPosition(moveCamera: false);
    await _focusOnNearestParking();
  }

  BitmapDescriptor get _currentVerifiedParkingIcon {
    if (_currentZoom >= 16.0) {
      return _verifiedParkingIconXLarge ?? _verifiedParkingIconLarge!;
    }
    if (_currentZoom >= 14.5) {
      return _verifiedParkingIconLarge ?? _verifiedParkingIconMedium!;
    }
    if (_currentZoom >= 13.0) {
      return _verifiedParkingIconMedium ?? _verifiedParkingIconSmall!;
    }
    return _verifiedParkingIconSmall ?? BitmapDescriptor.defaultMarker;
  }

  BitmapDescriptor get _currentUnverifiedParkingIcon {
    if (_currentZoom >= 16.0) {
      return _unverifiedParkingIconXLarge ?? _unverifiedParkingIconLarge!;
    }
    if (_currentZoom >= 14.5) {
      return _unverifiedParkingIconLarge ?? _unverifiedParkingIconMedium!;
    }
    if (_currentZoom >= 13.0) {
      return _unverifiedParkingIconMedium ?? _unverifiedParkingIconSmall!;
    }
    return _unverifiedParkingIconSmall ?? BitmapDescriptor.defaultMarker;
  }

  void _rebuildMarkersOnZoom() {
    _verifiedMarkers.clear();
    for (final suc in _sucursalesData) {
      _verifiedMarkers.add(Marker(
        markerId: MarkerId('sucursal_${suc.id}'),
        position: LatLng(suc.lat, suc.lng),
        infoWindow: const InfoWindow(title: 'Parqueadero'),
        icon: _currentVerifiedParkingIcon,
        onTap: () => _openSucursalDetail(suc.id),
        zIndex: 2,
      ));
    }

    _unverifiedMarkers.clear();
    for (var i = 0; i < _unverifiedLocationsData.length; i++) {
      final loc = _unverifiedLocationsData[i];
      final lat = (loc['latitude'] as num?)?.toDouble();
      final lng = (loc['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        final position = LatLng(lat, lng);
        _unverifiedMarkers.add(Marker(
          markerId: MarkerId('unverified_$i'),
          position: position,
          icon: _currentUnverifiedParkingIcon,
          zIndex: 1,
          anchor: const Offset(0.5, 0.5),
          onTap: () => _openUnverifiedAsDetail(position),
        ));
      }
    }
    _applyFilter();
  }

  Future<void> _focusOnNearestParking() async {
    if (!mounted || _currentPosition == null || _markers.isEmpty) {
      if (_currentPosition != null) {
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            15,
          ),
        );
      }
      return;
    }

    final userLocation = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    Marker? nearestMarker;
    double minDistance = double.infinity;

    for (final marker in _verifiedMarkers) {
      final distance = LocationService.calculateDistance(
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
          userLocation.latitude < parkingLocation.latitude
              ? userLocation.latitude
              : parkingLocation.latitude,
          userLocation.longitude < parkingLocation.longitude
              ? userLocation.longitude
              : parkingLocation.longitude,
        ),
        northeast: LatLng(
          userLocation.latitude > parkingLocation.latitude
              ? userLocation.latitude
              : parkingLocation.latitude,
          userLocation.longitude > parkingLocation.longitude
              ? userLocation.longitude
              : parkingLocation.longitude,
        ),
      );

      _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80.0));
    } else {
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(userLocation, 15));
    }
  }

  Future<void> _cargarSucursales() async {
    try {
      _sucursalesData = await ParkingService.getSucursalesUbicaciones();
      _sucursalCoordinates.clear();
      for (final suc in _sucursalesData) {
        _sucursalCoordinates[suc.id] = LatLng(suc.lat, suc.lng);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadError = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando sucursales: $e')),
        );
      }
    }
  }

  Future<void> _cargarUbicacionesNoAceptadas() async {
    try {
      _unverifiedLocationsData = await ParkingService.getUnverifiedParkingLocations();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudieron cargar ubicaciones extra: $e')),
        );
      }
    }
  }

  void _updateUserMarker() {
    if (!mounted || _currentPosition == null || _userLocationIcon == null) return;

    _userMarker = Marker(
      markerId: const MarkerId('user_location'),
      position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
      icon: _userLocationIcon!,
      alpha: _isUserMarkerFaded ? 0.7 : 1.0,
      zIndex: 10,
      anchor: const Offset(0.5, 0.5),
    );
  }

  Future<void> _updateUserPosition({bool moveCamera = true}) async {
    try {
      final pos = await LocationService.determinePosition();
      _currentPosition = pos;
      _updateUserMarker();
      _applyFilter();

      if (moveCamera && _mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(pos.latitude, pos.longitude),
            16.0,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo obtener la ubicación: $e')),
        );
      }
    }
  }

  Future<void> _openSucursalDetail(int sucursalId) async {
    final localContext = context;
    if (!mounted) return;

    try {
      final data = await ParkingService.getSucursalDetail(sucursalId);
      if (!mounted) return;

      final coordinates = _sucursalCoordinates[sucursalId];
      final lat = coordinates?.latitude ?? 0.0;
      final lng = coordinates?.longitude ?? 0.0;

      showModalBottomSheet(
        context: localContext,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        isDismissible: true,
        enableDrag: true,
        builder: (modalContext) => ParkingDetailModal(
          data: data,
          lat: lat,
          lng: lng,
          currentPosition: _currentPosition,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(localContext).showSnackBar(
          SnackBar(content: Text('Error abriendo detalles: $e')),
        );
      }
    }
  }

  void _openUnverifiedAsDetail(LatLng position) {
    final placeholderData = {
      'nombre': 'Parqueadero Publico',
      'imagenes': [
        {'url': 'assets/images/ImgDefault.png'}
      ],
      'servicios': [],
      'es_verificado': false,
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (modalContext) => ParkingDetailModal(
        data: placeholderData,
        lat: position.latitude,
        lng: position.longitude,
        currentPosition: _currentPosition,
      ),
    );
  }

  Future<void> _launchMapsNavigation(LatLng position) async {
    final url = Uri.parse('http://googleusercontent.com/maps.google.com/7{position.latitude},${position.longitude}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir la aplicación de mapas.')),
        );
      }
    }
  }

  void _irMasCercano() async {
    final localContext = context;
    if (!mounted) return;
    Navigator.of(localContext).pop();

    if (_markers.isEmpty) return;

    try {
      final pos = await LocationService.determinePosition();
      if (!mounted) return;

      _currentPosition = pos;
      Marker? nearest;
      double minDist = double.infinity;

      for (var m in _markers) {
        if (m.markerId.value == 'user_location' || m.markerId.value.startsWith('unverified_')) continue;
        final d = LocationService.calculateDistance(
          pos.latitude,
          pos.longitude,
          m.position.latitude,
          m.position.longitude,
        );
        if (d < minDist) {
          minDist = d;
          nearest = m;
        }
      }

      if (nearest != null) {
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(nearest.position, 16),
        );
        final id = int.parse(nearest.markerId.value.split('_').last);
        _openSucursalDetail(id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(localContext).showSnackBar(
          SnackBar(content: Text('Error obteniendo tu ubicación: $e')),
        );
      }
    }
  }

  void _listarParqueaderos() async {
    final localContext = context;
    if (!mounted) return;
    Navigator.of(localContext).pop();

    try {
      final pos = await LocationService.determinePosition();
      if (!mounted) return;

      final sucursales = await ParkingService.listarSucursales();
      if (!mounted) return;

      final sucursalesConDistancia = sucursales.map((s) {
        final distancia = LocationService.calculateDistance(
          pos.latitude,
          pos.longitude,
          (s['latitud'] as num).toDouble(),
          (s['longitud'] as num).toDouble(),
        );
        return {'sucursal': s, 'distancia': distancia};
      }).toList();

      sucursalesConDistancia.sort((a, b) => (a['distancia'] as double).compareTo(b['distancia'] as double));

      final sucursalesOrdenadas = sucursalesConDistancia.map((s) => s['sucursal'] as Map<String, dynamic>).toList();

      showModalBottomSheet(
        context: localContext,
        builder: (_) => ParkingListModal(
          sucursales: sucursalesOrdenadas,
          onSucursalTap: (id) => _openSucursalDetail(id),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(localContext).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _mostrarContacto() {
    final localContext = context;
    if (!mounted) return;
    Navigator.of(localContext).pop();

    showModalBottomSheet(
      context: localContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ContactModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: MapDrawer(
        onIrMasCercano: _irMasCercano,
        onListarParqueaderos: _listarParqueaderos,
        onContactanos: _mostrarContacto,
        currentFilter: _currentFilter,
        onFilterChanged: _onFilterChanged,
      ),
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        title: Row(
          children: [
            const Text(
              'Parking',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
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
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
        onCameraMove: (position) {
          _currentZoom = position.zoom;
        },
        onCameraIdle: () {
          _rebuildMarkersOnZoom();
        },
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