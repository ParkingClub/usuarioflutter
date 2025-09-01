import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../screens/map_screen.dart'; // Asegúrate de importar esto para usar MarkerFilter

class MapDrawer extends StatelessWidget {
  final VoidCallback onIrMasCercano;
  final VoidCallback onListarParqueaderos;
  final VoidCallback onContactanos;

  // --- PARÁMETROS NUEVOS PARA EL FILTRO ---
  final MarkerFilter currentFilter;
  final ValueChanged<MarkerFilter> onFilterChanged;

  const MapDrawer({
    super.key,
    required this.onIrMasCercano,
    required this.onListarParqueaderos,
    required this.onContactanos,
    // --- AÑADIR ESTOS PARÁMETROS REQUERIDOS ---
    required this.currentFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Theme.of(context).cardColor,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.black,
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.of(context).padding.top + 16,
              16,
              16,
            ),
            child: Row(
              children: [
                const Text(
                  'Parking',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF920606),
                    borderRadius: BorderRadius.circular(6),
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

          // --- INICIO: SECCIÓN DE FILTRO AÑADIDA ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mostrar en el mapa:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 10),
                ToggleButtons(
                  isSelected: [
                    currentFilter == MarkerFilter.all,
                    currentFilter == MarkerFilter.verified,
                    currentFilter == MarkerFilter.unverified,
                  ],
                  onPressed: (index) {
                    if (index == 0) onFilterChanged(MarkerFilter.all);
                    if (index == 1) onFilterChanged(MarkerFilter.verified);
                    if (index == 2) onFilterChanged(MarkerFilter.unverified);
                  },
                  borderRadius: BorderRadius.circular(8.0),
                  selectedColor: Colors.white,
                  fillColor: const Color(0xFF920606),
                  color: const Color(0xFF920606),
                  constraints: const BoxConstraints(minHeight: 40.0, minWidth: 80.0),
                  children: const <Widget>[
                    Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Todos')),
                    Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Verificados')),
                    Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('No Verif.')),
                  ],
                ),
              ],
            ),
          ),
          // --- FIN: SECCIÓN DE FILTRO AÑADIDA ---

          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.place_outlined),
            title: const Text('Ir al más cercano'),
            onTap: onIrMasCercano,
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.view_list_outlined),
            title: const Text('Listar Parqueaderos'),
            onTap: onListarParqueaderos,
          ),
          const Divider(height: 1),
          SwitchListTile(
            title: const Text("Modo Oscuro"),
            value: Provider.of<ThemeProvider>(context).themeMode == ThemeMode.dark,
            onChanged: (value) {
              Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
            },
            secondary: const Icon(Icons.dark_mode_outlined),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.contact_support_outlined),
            title: const Text('Contáctanos'),
            onTap: onContactanos,
          ),
          const Spacer(),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout, color: Color(0xFF920606)),
            title: const Text(
              'Cerrar sesión',
              style: TextStyle(color: Color(0xFF920606)),
            ),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}