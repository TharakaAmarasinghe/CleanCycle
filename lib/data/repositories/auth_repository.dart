import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants.dart';
import '../../domain/models/app_user.dart';

/// Wraps Firebase Auth for credentials, and Firestore for the profile
/// fields Firebase Auth doesn't have — name and role. Role is written
/// once, at registration, and never changes.
class AuthRepository {
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<fb.User?> get authStateChanges => _auth.authStateChanges();

  fb.User? get currentFirebaseUser => _auth.currentUser;

  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = credential.user!.uid;

    final user = AppUser(id: uid, name: name, email: email, role: role);
    await _firestore.collection('users').doc(uid).set(user.toMap());
    return user;
  }

  Future<AppUser> signIn({required String email, required String password}) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = credential.user!.uid;
    return getUserProfile(uid);
  }

  Future<AppUser> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) {
      throw Exception('User profile not found for $uid — this should never happen for a registered user.');
    }
    return AppUser.fromMap(doc.data()!);
  }

  Future<void> signOut() => _auth.signOut();
}