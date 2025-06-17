// lib/screens/splash_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'map_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MapScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1) Imagen de fondo
          Image.asset(
            'lib/screens/icons/parkingv2.jpg',
            fit: BoxFit.cover,
          ),

          // 2) Capa semitransparente para contraste
          Container(color: Colors.black45),

          // 3) Contenido centrado
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icono generado
              Image.asset(
                'lib/screens/icons/logoChat.png',
                width: 160,
              ),
              const SizedBox(height: 16),
              const Text(
                'ParkingClub',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Encuentra tu espacio perfecto',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Color(0xFF920606)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
