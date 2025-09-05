// lib/widgets/map_drawer.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../providers/theme_provider.dart';
import '../screens/map_screen.dart';
import '../services/auth_service.dart';
import '../screens/view_profile_bottom_sheet.dart';
import '../screens/login_bottom_sheet.dart';

class MapDrawer extends StatelessWidget {
  final VoidCallback onIrMasCercano;
  final VoidCallback onListarParqueaderos;
  final VoidCallback onContactanos;
  final MarkerFilter currentFilter;
  final ValueChanged<MarkerFilter> onFilterChanged;

  const MapDrawer({
    super.key,
    required this.onIrMasCercano,
    required this.onListarParqueaderos,
    required this.onContactanos,
    required this.currentFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User?>(context);
    final bool isLoggedIn = user != null;

    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    const TextStyle activeFilterStyle = TextStyle(
      fontWeight: FontWeight.bold,
      color: Color(0xFF920606),
    );

    return Drawer(
      backgroundColor: Theme.of(context).cardColor,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: Column(
          children: [
            // Cabecera de la marca (sin cambios)
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

            // --- SECCIÓN DINÁMICA DE USUARIO ---
            if (!isLoggedIn)
            // Si NO está logueado, muestra el botón de Iniciar Sesión
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: const Icon(Icons.login),
                title: const Text('Iniciar Sesión / Registrarse'),
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context, isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const LoginBottomSheet(),
                  );
                },
              )
            else
            // Si SÍ está logueado, muestra la nueva cabecera de usuario
              Column(
                children: [
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => const ViewProfileBottomSheet(),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.grey.shade300,
                            backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
                            child: user.photoURL == null
                                ? const Icon(Icons.person, size: 24, color: Colors.grey)
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.displayName ?? 'Usuario',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  user.email ?? 'Ver Perfil',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      leading: const Icon(Icons.filter_list),
                      title: const Text('Mostrar en el mapa'),
                      children: <Widget>[
                        ListTile(
                          contentPadding: const EdgeInsets.only(left: 72),
                          title: Text('Todos', style: currentFilter == MarkerFilter.all ? activeFilterStyle : null),
                          onTap: () => onFilterChanged(MarkerFilter.all),
                        ),
                        ListTile(
                          contentPadding: const EdgeInsets.only(left: 72),
                          title: Text('Con Información', style: currentFilter == MarkerFilter.verified ? activeFilterStyle : null),
                          onTap: () => onFilterChanged(MarkerFilter.verified),
                        ),
                        ListTile(
                          contentPadding: const EdgeInsets.only(left: 72),
                          title: Text('Info. Limitada', style: currentFilter == MarkerFilter.unverified ? activeFilterStyle : null),
                          onTap: () => onFilterChanged(MarkerFilter.unverified),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

            // --- RESTO DE OPCIONES DEL MENÚ ---
            const Divider(height: 1),
            ListTile(leading: const Icon(Icons.place_outlined), title: const Text('Ir al más cercano'), onTap: onIrMasCercano),
            const Divider(height: 1),
            ListTile(leading: const Icon(Icons.view_list_outlined), title: const Text('Listar Parqueaderos'), onTap: onListarParqueaderos),
            const Divider(height: 1),
            SwitchListTile(
              title: const Text("Modo Oscuro"),
              value: Provider.of<ThemeProvider>(context).themeMode == ThemeMode.dark,
              onChanged: (value) => Provider.of<ThemeProvider>(context, listen: false).toggleTheme(),
              secondary: const Icon(Icons.dark_mode_outlined),
            ),
            const Divider(height: 1),
            ListTile(leading: const Icon(Icons.contact_support_outlined), title: const Text('Contáctanos'), onTap: onContactanos),

            const Spacer(),

            // Botón de cerrar sesión
            if (isLoggedIn)
              Column(
                children: [
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Cerrar sesión'),
                    onTap: () async {
                      Navigator.pop(context);
                      await AuthService().signOut();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Has cerrado sesión.')),
                      );
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}