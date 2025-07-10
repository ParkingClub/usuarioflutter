import 'package:flutter/material.dart';

class ParkingListModal extends StatelessWidget {
  final List<Map<String, dynamic>> sucursales;
  final Function(int) onSucursalTap;

  const ParkingListModal({
    super.key,
    required this.sucursales,
    required this.onSucursalTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sucursales.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (_, i) {
        final s = sucursales[i];
        final fotos = (s['fotografias'] as List? ?? []).cast<Map<String, dynamic>>();
        final img = fotos.isNotEmpty ? fotos.first['fotografia'] as String : '';

        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: img.isNotEmpty
                ? Image.network(
              img,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
            )
                : const Icon(
              Icons.local_parking,
              size: 56,
              color: Color(0xFF920606),
            ),
          ),
          title: Text(s['nombre'] as String),
          subtitle: Text(s['ubicacion'] as String),
          trailing: Text(
            '\$${(s['preciotarifa'] as num).toStringAsFixed(2)}',
            style: const TextStyle(
              color: Color(0xFF920606),
              fontWeight: FontWeight.bold,
            ),
          ),
          onTap: () {
            Navigator.of(context).pop();
            onSucursalTap(s['id'] as int);
          },
        );
      },
    );
  }
}
