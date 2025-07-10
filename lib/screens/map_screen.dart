import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:io' show Platform;

import '../models/sucursal.dart';
import '../services/parking_service.dart';
import '../services/location_service.dart';
import '../utils/map_styles.dart';
import '../widgets/map_drawer.dart';
import '../widgets/parking_detail_modal.dart';
import '../widgets/parking_list_modal.dart';

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
  final Map<int, LatLng> _sucursalCoordinates = {};
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(-0.19284, -78.49038),
    zoom: 12,
  );

  @override
  void initState() {
    super.initState();
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
        }
      },
    );
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
    // Wait for icons to load
    int attempts = 0;
    while ((_sucursalIcon == null || _userLocationIcon == null) && attempts < 50) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }

    await _cargarSucursales();
    await _updateUserPosition(moveCamera: false);
    await _focusOnNearestParking();
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

    for (final marker in _markers) {
      if (marker.markerId.value == 'user_location') continue;

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
      final sucursales = await ParkingService.getSucursalesUbicaciones();
      final newMarkers = <Marker>{};

      for (final suc in sucursales) {
        _sucursalCoordinates[suc.id] = LatLng(suc.lat, suc.lng);
        final marker = Marker(
          markerId: MarkerId('sucursal_${suc.id}'),
          position: LatLng(suc.lat, suc.lng),
          infoWindow: const InfoWindow(title: 'Parqueadero'),
          icon: _sucursalIcon!,
          onTap: () => _openSucursalDetail(suc.id),
        );
        newMarkers.add(marker);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando sucursales: $e')),
        );
      }
    }
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
      final pos = await LocationService.determinePosition();
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
        if (m.markerId.value == 'user_location') continue;
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
      final sucursales = await ParkingService.listarSucursales();
      if (!mounted) return;

      showModalBottomSheet(
        context: localContext,
        builder: (_) => ParkingListModal(
          sucursales: sucursales,
          onSucursalTap: (id) => _openSucursalDetail(id),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(localContext).showSnackBar(
          SnackBar(content: Text('Error listando sucursales: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: MapDrawer(
        onIrMasCercano: _irMasCercano,
        onListarParqueaderos: _listarParqueaderos,
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
