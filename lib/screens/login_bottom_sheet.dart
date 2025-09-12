// lib/screens/login_bottom_sheet.dart

import 'package:flutter/material.dart';
import 'package:parkingusers/screens/profile_screen.dart';
import 'package:parkingusers/services/auth_service.dart';
import 'package:parkingusers/services/notification_service.dart'; // <-- 1. IMPORTA EL SERVICIO

class LoginBottomSheet extends StatefulWidget {
  const LoginBottomSheet({super.key});

  @override
  State<LoginBottomSheet> createState() => _LoginBottomSheetState();
}

class _LoginBottomSheetState extends State<LoginBottomSheet> {
  bool _isLoading = false;
  final AuthService _authService = AuthService();
  // 2. Crea una instancia del servicio de notificaciones
  final NotificationService _notificationService = NotificationService();

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final result = await _authService.signInWithGoogle();

      if (result.user != null && mounted) {
        // --- 3. LLAMA AL SERVICIO DE NOTIFICACIONES AQUÍ ---
        // Después de un login exitoso, pedimos permiso y guardamos el token.
        await _notificationService.initialize();
        // ----------------------------------------------------

        Navigator.of(context).pop(); // Cierra el modal de login

        // Si el perfil NO está completo, muestra el ProfileScreen como otro modal
        if (!result.isProfileComplete) {
          await showModalBottomSheet(
            context: context,
            isDismissible: false,
            enableDrag: false,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const ProfileScreen(isFirstTime: true),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al iniciar con Google: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const double iconSize = 90;
    const double iconTopMargin = - (iconSize / 2);
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    return Wrap(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: EdgeInsets.only(
                top: iconSize / 2 + 10, left: 24, right: 24, bottom: 32 + bottomPadding,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40, height: 5,
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                  ),
                  const SizedBox(height: 24),
                  const Text('Inicia sesión en Parking Club', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  const Text('Conéctate para personalizar tu experiencia y recibir avisos exclusivos.', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Colors.grey)),
                  const SizedBox(height: 32),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    ElevatedButton.icon(
                      icon: Image.asset('assets/images/google_logo.png', height: 24.0),
                      label: const Text('Continuar con Google'),
                      onPressed: _signInWithGoogle,
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.black, backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Color(0xFFE0E0E0))),
                        elevation: 2,
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              top: iconTopMargin, left: 0, right: 0,
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(color: Theme.of(context).cardColor, shape: BoxShape.circle),
                  child: Image.asset('lib/screens/icons/MarkMapV.png', height: iconSize, width: iconSize),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}