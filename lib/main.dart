// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:parkingusers/config/app_themes.dart';
import 'package:parkingusers/providers/theme_provider.dart';
import 'package:parkingusers/screens/splash_screen.dart';
import 'package:parkingusers/services/auth_service.dart';
import 'package:parkingusers/services/notification_service.dart'; // <-- 1. IMPORTA EL SERVICIO
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await initializeDateFormatting();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        StreamProvider<User?>.value(
          value: AuthService().authStateChanges,
          initialData: null,
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      // --- 2. CONECTA LA CLAVE GLOBAL AQUÍ ---
      scaffoldMessengerKey: NotificationService.messengerKey,

      debugShowCheckedModeBanner: false,
      title: 'ParkingClub',
      theme: AppThemes.lightTheme,
      darkTheme: AppThemes.darkTheme,
      themeMode: themeProvider.themeMode,
      home: const SplashScreen(),

      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''),
        Locale('es', ''),
      ],
    );
  }
}