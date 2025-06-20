import 'package:flutter/material.dart';

class AppThemes {
  static const Color primaryColor = Color(0xFF920606);

  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: const Color(0xFFF5F5F5), // Gris muy claro para el fondo de la app/modal
    cardColor: const Color(0xFFEEEEEE), // Gris perla para la tarjeta
    dividerColor: primaryColor.withOpacity(0.4),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.black87),
      bodyMedium: TextStyle(color: Colors.black54),
      titleLarge: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
    ),
    colorScheme: const ColorScheme.light(
      primary: primaryColor,
      secondary: Colors.blue,
      background: Color(0xFFF5F5F5), // Fondo general del modal
      surface: Color(0xFFEEEEEE), // Color de la tarjeta
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: const Color(0xFF121212), // Negro estándar de Material Design para fondos
    cardColor: const Color(0xFF1E1E1E), // Gris oscuro para la tarjeta
    dividerColor: primaryColor.withOpacity(0.7),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.white70),
      bodyMedium: TextStyle(color: Colors.white60),
      titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    ),
    colorScheme: const ColorScheme.dark(
      primary: primaryColor,
      secondary: Colors.lightBlueAccent,
      background: Color(0xFF121212), // Fondo general del modal
      surface: Color(0xFF1E1E1E), // Color de la tarjeta
    ),
  );
}