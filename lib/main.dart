// lib/main.dart

import 'dart:async';
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
import 'firebase_options.dart';

// Nota: Si tienes un NotificationService que requiera init(), lo invocamos
// de forma segura con try/catch más abajo para NO romper Android/iOS
// import 'package:parkingusers/services/notification_service.dart';

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa Firebase con las opciones correctas para cada plataforma
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Localización (Intl)
  await initializeDateFormatting();

  // Inicialización opcional de notificaciones (si existe y está configurado)
  // try {
  //   await NotificationService.instance.initialize();
  // } catch (_) {
  //   // Evita que un fallo en notificaciones bloquee el arranque
  // }
}

void main() {
  // Manejo global de errores (sincrónicos/async)
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    // Aquí podrías enviar el error a tu crashlytics si lo usas.
  };

  runZonedGuarded(() async {
    await _bootstrap();

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          // Stream de sesión FirebaseAuth
          StreamProvider<User?>.value(
            value: AuthService().authStateChanges,
            initialData: null,
          ),
        ],
        child: const MyApp(),
      ),
    );
  }, (Object error, StackTrace stack) {
    // Captura errores fuera del árbol de Flutter
    // En producción, envía esto a tu sistema de reportes/crashlytics
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Parking Users',
      theme: AppThemes.lightTheme,
      darkTheme: AppThemes.darkTheme,
      themeMode: themeProvider.themeMode,
      home: const SplashScreen(),
      // Localización
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('es'),
      ],
    );
  }
}
