import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/directions_helper.dart';
import '../widgets/image_carousel.dart';
import 'package:geolocator/geolocator.dart';

class ParkingDetailModal extends StatelessWidget {
  final Map<String, dynamic> data;
  final double lat;
  final double lng;
  final Position? currentPosition;

  const ParkingDetailModal({
    super.key,
    required this.data,
    required this.lat,
    required this.lng,
    this.currentPosition,
  });

  @override
  Widget build(BuildContext context) {
    final nombre = data['nombre'] as String? ?? 'Sin nombre';
    final precio = (data['preciotarifa'] as num? ?? 0).toStringAsFixed(2);
    final plazas = (data['plazasdisponibles'] ?? 0).toString();
    final ubicacion = data['ubicacion'] as String? ?? 'Ubicación no disponible';
    final descripcion = data['descripcion'] as String? ?? '';
    final fotos = (data['fotografias'] as List? ?? []).cast<String>();

    final apertura = _formatHora(data['horaApertura'] ?? '00:00');
    final cierre = _formatHora(data['horaCierre'] ?? '23:59');
    final estaAbierto = _calcularSiEstaAbierto(data['horaApertura'], data['horaCierre']);
    final estadoTexto = estaAbierto ? 'Abierto' : 'Cerrado';
    final estadoColor = estaAbierto ? Colors.green : Colors.red;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.65,
      maxChildSize: 0.9,
      builder: (_, scrollController) => Stack(
        children: [
          Container(
            color: Theme.of(context).colorScheme.background,
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Stack(
                      children: [
                        ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                          children: [
                            _buildParkingDetails(
                              context: context,
                              fotos: fotos,
                              nombre: nombre,
                              precio: precio,
                              plazas: plazas,
                              estadoTexto: estadoTexto,
                              estadoColor: estadoColor,
                              apertura: apertura,
                              cierre: cierre,
                              ubicacion: ubicacion,
                              descripcion: descripcion,
                            ),
                          ],
                        ),
                        Positioned(
                          top: 16,
                          right: 16,
                          child: GestureDetector(
                            onTap: () => _openDirections(context),
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: const Color(0xFF920606),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
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
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Text(
                      'CERRADO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildParkingDetails({
    required BuildContext context,
    required List<String> fotos,
    required String nombre,
    required String precio,
    required String plazas,
    required String estadoTexto,
    required Color estadoColor,
    required String apertura,
    required String cierre,
    required String ubicacion,
    required String descripcion,
  }) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (fotos.isNotEmpty)
          Container(
            height: 220,
            margin: const EdgeInsets.only(bottom: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ImageCarousel(fotos: fotos),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(right: 60.0),
          child: Text(
            nombre,
            style: textTheme.titleLarge?.copyWith(fontSize: 26),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: estadoColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            estadoTexto,
            style: TextStyle(
              color: estadoColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildInfoColumn(
              context: context,
              icon: Icons.attach_money,
              label: 'Tarifa/hora',
              value: '\$$precio',
              iconColor: textTheme.bodyLarge!.color!,
            ),
            _buildInfoColumn(
              context: context,
              icon: Icons.local_parking,
              label: 'Disponibles',
              value: plazas,
              iconColor: Colors.blue.shade400,
            ),
            _buildInfoColumn(
              context: context,
              icon: Icons.access_time_rounded,
              label: 'Horario',
              value: '$apertura - $cierre',
              iconColor: Colors.orange.shade400,
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0),
          child: Divider(
            color: Theme.of(context).dividerColor,
            thickness: 1,
          ),
        ),
        _buildDetailRow(
          context: context,
          icon: Icons.location_on_outlined,
          label: 'Ubicación',
          value: ubicacion,
        ),
        if (descripcion.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildDetailRow(
            context: context,
            icon: Icons.info_outline,
            label: 'Descripción',
            value: descripcion,
          ),
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
          onPressed: () => _openDirections(context),
          icon: const Icon(Icons.directions, size: 22),
          label: const Text('CÓMO LLEGAR'),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: textTheme.bodyMedium?.color,
            minimumSize: const Size(double.infinity, 50),
          ),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }

  Widget _buildInfoColumn({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
  }) {
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

  String _formatHora(String h) {
    try {
      final parts = h.split(':').map(int.parse).toList();
      return DateFormat('HH:mm').format(DateTime(0, 0, 0, parts[0], parts[1]));
    } catch (e) {
      return h;
    }
  }

  bool _calcularSiEstaAbierto(String? horaApertura, String? horaCierre) {
    try {
      final now = TimeOfDay.fromDateTime(DateTime.now());
      final openParts = (horaApertura ?? '00:00').split(':').map(int.parse).toList();
      final closeParts = (horaCierre ?? '23:59').split(':').map(int.parse).toList();
      final openTime = TimeOfDay(hour: openParts[0], minute: openParts[1]);
      final closeTime = TimeOfDay(hour: closeParts[0], minute: closeParts[1]);

      final nowInMinutes = now.hour * 60 + now.minute;
      final openInMinutes = openTime.hour * 60 + openTime.minute;
      final closeInMinutes = closeTime.hour * 60 + closeTime.minute;

      if (openInMinutes <= closeInMinutes) {
        return nowInMinutes >= openInMinutes && nowInMinutes <= closeInMinutes;
      } else {
        return nowInMinutes >= openInMinutes || nowInMinutes <= closeInMinutes;
      }
    } catch (e) {
      return true;
    }
  }

  void _openDirections(BuildContext context) async {
    try {
      await DirectionsHelper.openDirections(lat, lng, currentPosition);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al abrir direcciones: $e')),
        );
      }
    }
  }
}
