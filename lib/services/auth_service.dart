// lib/services/auth_service.dart

import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Resultado enriquecido para el flujo de Google
class GoogleSignInResult {
  final User? user;
  final bool isProfileComplete;
  final String? error; // útil para debug
  GoogleSignInResult({
    this.user,
    this.isProfileComplete = false,
    this.error,
  });
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Suele bastar con la instancia por defecto; scopes explícitos ayudan a consistencia.
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>['email', 'profile'],
  );

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  /// Login con Google (robustecido para iOS/Android)
  Future<GoogleSignInResult> signInWithGoogle() async {
    try {
      // 1) Lanzar el selector de cuenta
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // Usuario canceló el login
        return GoogleSignInResult(user: null, error: 'cancelled');
      }

      // 2) Tokens de Google
      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      // ⚠️ En iOS, si el URL Scheme/CLIENT_ID está mal configurado,
      // es común que idToken llegue nulo. Dejamos trazas claras:
      if (Platform.isIOS && (googleAuth.idToken == null || googleAuth.idToken!.isEmpty)) {
        // Devolvemos error “clave” para que la UI pueda loguearlo.
        return GoogleSignInResult(
          user: null,
          error:
          'ios_idtoken_null', // indicaré abajo cómo corregirlo en Info.plist
        );
      }

      // 3) Credencial Firebase
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken, // <-- imprescindible en iOS
      );

      // 4) Login Firebase
      final UserCredential userCredential =
      await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user == null) {
        return GoogleSignInResult(user: null, error: 'no_firebase_user');
      }

      // 5) Perfil en Firestore (esperar el write para evitar “carreras” de UI)
      final userRef = _firestore.collection('users').doc(user.uid);
      final userDoc = await userRef.get();

      if (!userDoc.exists) {
        await _createUserDocument(user); // <-- ahora sí, con await
        return GoogleSignInResult(user: user, isProfileComplete: false);
      } else {
        final data = userDoc.data();
        final bool hasPlate =
            data != null && data['plateLastDigit'] != null && '${data['plateLastDigit']}'.isNotEmpty;
        final bool hasBirthday = data != null && data['birthday'] != null;
        final bool isProfileComplete = hasPlate && hasBirthday;

        return GoogleSignInResult(user: user, isProfileComplete: isProfileComplete);
      }
    } on FirebaseAuthException catch (e) {
      // Errores típicos cuando el idToken no llega o credencial mal formada
      return GoogleSignInResult(user: null, error: 'firebase_auth_${e.code}');
    } catch (e) {
      return GoogleSignInResult(user: null, error: 'unexpected_${e.runtimeType}');
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut(); // cierra sesión de Google
    } finally {
      await _auth.signOut(); // y de Firebase
    }
  }

  // -- Firestore

  Future<void> _createUserDocument(User user) {
    return _firestore.collection('users').doc(user.uid).set({
      'email': user.email,
      'displayName': user.displayName,
      'photoURL': user.photoURL,
      'createdAt': FieldValue.serverTimestamp(),
      'plateLastDigit': null,
      'birthday': null,
    });
  }

  Future<void> updateUserData({String? plateLastDigit, DateTime? birthday}) async {
    if (currentUser == null) return;
    final Map<String, dynamic> dataToUpdate = {};
    if (plateLastDigit != null) {
      dataToUpdate['plateLastDigit'] = plateLastDigit;
    }
    if (birthday != null) {
      dataToUpdate['birthday'] = Timestamp.fromDate(birthday);
    }
    if (dataToUpdate.isNotEmpty) {
      await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .set(dataToUpdate, SetOptions(merge: true));
    }
  }
}
