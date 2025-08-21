import 'dart:async';
import 'package:flutter/material.dart';
import 'map_screen.dart'; // Asegúrate de que esta ruta sea correcta

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Controlador de animación para gestionar la duración y el estado
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Animación de desvanecimiento (fade-in)
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );

    // Animación de deslizamiento (slide-up) para el indicador
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    // Iniciar la animación
    _animationController.forward();

    // Navegar a la siguiente pantalla después de un retraso
    Timer(const Duration(seconds: 4), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const MapScreen(),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Imagen de fondo
          Image.asset(
            'lib/screens/icons/parkingv2.jpg', // Confirma que esta ruta es correcta
            fit: BoxFit.cover,
          ),

          // 2. Capa de degradado oscuro para mejorar la legibilidad
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.7),
                  const Color(0xFF1A1A1A).withOpacity(0.8),
                  Colors.black.withOpacity(0.95),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // 3. Contenido centrado y animado
          FadeTransition(
            opacity: _fadeAnimation,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo con animación de escala sutil
                  ScaleTransition(
                    scale: CurvedAnimation(
                      parent: _animationController,
                      curve: Curves.elasticOut,
                    ),
                    child: Image.asset(
                      'lib/screens/icons/logoSplash2.png', // Confirma la ruta
                      width: 250,
                      height: 250,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 45), // Espacio ajustado

                  // Spinner con animación de deslizamiento
                  SlideTransition(
                    position: _slideAnimation,
                    child: const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(Color(0xFFE53935)),
                      strokeWidth: 3.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}