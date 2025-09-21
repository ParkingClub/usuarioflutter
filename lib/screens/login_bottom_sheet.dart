import 'package:flutter/material.dart';
import 'package:parkingusers/screens/profile_screen.dart';
import 'package:parkingusers/services/auth_service.dart';
import 'package:parkingusers/services/notification_service.dart';

class LoginBottomSheet extends StatefulWidget {
  const LoginBottomSheet({super.key});

  @override
  State<LoginBottomSheet> createState() => _LoginBottomSheetState();
}

class _LoginBottomSheetState extends State<LoginBottomSheet> {
  bool _isLoading = false;
  final AuthService _authService = AuthService();
  final NotificationService _notificationService = NotificationService();

  Future<void> _signInWithGoogle() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final result = await _authService.signInWithGoogle();

      if (!mounted) return;

      if (result.user == null) {
        // Si falló (por ejemplo idToken nulo en iOS), muestra mensaje y no intentes abrir modales
        final msg = (result.error == 'ios_idtoken_null')
            ? 'Revisa el URL Scheme (REVERSED_CLIENT_ID) y GIDClientID en Info.plist.'
            : 'No se pudo iniciar sesión. Inténtalo de nuevo.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        return;
      }

      // 1) Cierra este bottom sheet usando el root navigator
      Navigator.of(context, rootNavigator: true).pop();

      // 2) Da un respiro para que termine la transición del pop (iOS es sensible)
      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;

      // 3) Presenta el modal de registro si falta completar el perfil
      if (!result.isProfileComplete) {
        await showModalBottomSheet(
          context: context,
          useRootNavigator: true,        // asegura que vaya sobre navegadores anidados
          isDismissible: false,
          enableDrag: false,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const ProfileScreen(isFirstTime: true),
        );
        // 4) Luego de que el usuario está en el perfil (o al cerrarlo), pide permisos (evita choques de diálogos)
        try {
          await _notificationService.initialize();
        } catch (_) {}
      } else {
        // Perfil ya completo: pide permisos directamente si quieres
        try {
          await _notificationService.initialize();
        } catch (_) {}
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al iniciar con Google: $e')),
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
    const double iconTopMargin = -(iconSize / 2);
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    return Wrap(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: EdgeInsets.only(
                top: iconSize / 2 + 10,
                left: 24,
                right: 24,
                bottom: 32 + bottomPadding,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Inicia sesión en Parking Club',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Conéctate para personalizar tu experiencia y recibir avisos exclusivos.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Colors.grey),
                  ),
                  const SizedBox(height: 32),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    ElevatedButton.icon(
                      icon: Image.asset('assets/images/google_logo.png', height: 24.0),
                      label: const Text('Continuar con Google'),
                      onPressed: _signInWithGoogle,
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.black,
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: Color(0xFFE0E0E0)),
                        ),
                        elevation: 2,
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              top: iconTopMargin,
              left: 0,
              right: 0,
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    shape: BoxShape.circle,
                  ),
                  child: Image.asset(
                    'lib/screens/icons/MarkMapV.png',
                    height: iconSize,
                    width: iconSize,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
