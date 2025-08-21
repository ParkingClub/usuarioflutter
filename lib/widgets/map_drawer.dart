import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class MapDrawer extends StatelessWidget {
  final VoidCallback onIrMasCercano;
  final VoidCallback onListarParqueaderos;
  final VoidCallback onContactanos;

  const MapDrawer({
    super.key,
    required this.onIrMasCercano,
    required this.onListarParqueaderos,
    required this.onContactanos,
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
