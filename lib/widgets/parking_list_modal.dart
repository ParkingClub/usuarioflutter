import 'package:flutter/material.dart';

class ParkingListModal extends StatefulWidget {
  final List<Map<String, dynamic>> sucursales;
  final Function(int) onSucursalTap;

  const ParkingListModal({
    super.key,
    required this.sucursales,
    required this.onSucursalTap,
  });

  @override
  State<ParkingListModal> createState() => _ParkingListModalState();
}

class _ParkingListModalState extends State<ParkingListModal> {
  late List<Map<String, dynamic>> _filtradas;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filtradas = widget.sucursales; // lista completa al inicio
  }

  void _filtrar(String q) {
    q = q.trim();
    if (q.isEmpty) {
      setState(() => _filtradas = widget.sucursales);
      return;
    }

    // ¿es número? → filtra por precio; si no, por nombre
    final precio = double.tryParse(q.replaceAll(',', '.'));
    setState(() {
      _filtradas = widget.sucursales.where((s) {
        if (precio != null) {
          final p = (s['preciotarifa'] as num).toDouble();
          return p <= precio; // ≤ precio buscado
        } else {
          final nombre = (s['nombre'] as String).toLowerCase();
          return nombre.contains(q.toLowerCase());
        }
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Barra de búsqueda
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: 'Buscar por nombre o precio',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _search.clear();
                  _filtrar('');
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: _filtrar,
          ),
        ),

        const Divider(height: 0),

        // Lista
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _filtradas.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (_, i) {
              final s = _filtradas[i];
              final fotos =
              (s['fotografias'] as List? ?? []).cast<Map<String, dynamic>>();
              final img =
              fotos.isNotEmpty ? fotos.first['fotografia'] as String : '';

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
                  widget.onSucursalTap(s['id'] as int);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
