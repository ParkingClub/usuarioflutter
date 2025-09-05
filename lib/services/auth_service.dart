// lib/services/auth_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

// Clase auxiliar para devolver un resultado más completo
class GoogleSignInResult {
  final User? user;
  final bool isProfileComplete;
  GoogleSignInResult({this.user, this.isProfileComplete = false});
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // --- MÉTODO DE AUTENTICACIÓN MODIFICADO ---
  Future<GoogleSignInResult> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return GoogleSignInResult(user: null);

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user == null) return GoogleSignInResult(user: null);

      // Verificamos si el documento del usuario existe y si está completo
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        // Si el documento NO existe, es un usuario 100% nuevo.
        // Lo creamos con los datos de Google y marcamos el perfil como incompleto.
        _createUserDocument(user);
        return GoogleSignInResult(user: user, isProfileComplete: false);
      } else {
        // Si el documento SÍ existe, revisamos si tiene los datos del perfil.
        final data = userDoc.data();
        final bool isProfileComplete = data != null && data.containsKey('plateLastDigit') && data['plateLastDigit'] != null;
        return GoogleSignInResult(user: user, isProfileComplete: isProfileComplete);
      }
    } catch (e) {
      print("Error en signInWithGoogle: $e");
      return GoogleSignInResult(user: null);
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // --- MANEJO DE DATOS DE USUARIO EN FIRESTORE ---
  Future<void> _createUserDocument(User user) {
    // AHORA GUARDAMOS NOMBRE Y FOTO DE PERFIL
    return _firestore.collection('users').doc(user.uid).set({
      'email': user.email,
      'displayName': user.displayName, // Nombre de Google
      'photoURL': user.photoURL,     // Foto de perfil de Google
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