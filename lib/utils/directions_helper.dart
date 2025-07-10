import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class DirectionsHelper {
  static Future<void> openDirections(double destLat, double destLng, Position? currentPosition) async {
    try {
      Position currentPos = currentPosition ?? await Geolocator.getCurrentPosition();

      final String mapsUrl = Platform.isIOS
          ? 'https://maps.apple.com/?saddr=${currentPos.latitude},${currentPos.longitude}&daddr=$destLat,$destLng&dirflg=d'
          : 'https://www.google.com/maps/dir/?api=1&origin=${currentPos.latitude},${currentPos.longitude}&destination=$destLat,$destLng&travelmode=driving';

      final Uri url = Uri.parse(mapsUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'No se pudo abrir la aplicación de mapas';
      }
    } catch (e) {
      throw 'Error al abrir direcciones: $e';
    }
  }
}
