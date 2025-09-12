// lib/services/notification_service.dart

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:parkingusers/services/auth_service.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final AuthService _authService = AuthService();

  static final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

  // --- NUEVA VARIABLE PARA EVITAR DUPLICADOS ---
  String? _lastShownMessageId;

  Future<void> initialize() async {
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final String? token = await _fcm.getToken();
    if (token != null) {
      print('--- FCM Token ---');
      print(token);
      print('-----------------');
      await _saveTokenToFirestore(token);
    }
    _fcm.onTokenRefresh.listen(_saveTokenToFirestore);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('¡Mensaje recibido con la app abierta!');

      final String? messageId = message.messageId;

      // --- VERIFICACIÓN PARA MOSTRAR LA NOTIFICACIÓN UNA SOLA VEZ ---
      // Si el ID del mensaje es el mismo que el último que mostramos, no hacemos nada.
      if (messageId != null && messageId == _lastShownMessageId) {
        print('Mensaje duplicado detectado. No se mostrará de nuevo.');
        return;
      }

      // Guardamos el ID de este mensaje para no volver a mostrarlo.
      _lastShownMessageId = messageId;

      if (message.data['type'] == 'welcome_message' && message.data['body'] != null) {
        final snackBar = SnackBar(
          content: Text(
            message.data['body'],
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFF920606),
          duration: const Duration(seconds: 5), // Duración de 5 segundos
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        );

        messengerKey.currentState?.showSnackBar(snackBar);
      }
    });
  }

  Future<void> _saveTokenToFirestore(String token) async {
    final user = _authService.currentUser;
    if (user == null) return;

    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

    await userRef.set({
      'fcmTokens': FieldValue.arrayUnion([token])
    }, SetOptions(merge: true));
  }
}