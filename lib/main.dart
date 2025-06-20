import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:parkingusers/config/app_themes.dart';
import 'package:parkingusers/providers/theme_provider.dart';
import 'package:parkingusers/screens/splash_screen.dart';

// --- CORRECCIÓN: Se envuelve la app con el Provider aquí en la función main() ---
void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) { // Renombré 'ctx' a 'context' por convención

    // --- AHORA ESTO FUNCIONA ---
    // porque el Provider está por encima de MyApp en el árbol de widgets.
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ParkingClub',

      // La configuración de temas que ya tenías está perfecta
      theme: AppThemes.lightTheme,
      darkTheme: AppThemes.darkTheme,
      themeMode: themeProvider.themeMode,

      home: const SplashScreen(),
    );
  }
}