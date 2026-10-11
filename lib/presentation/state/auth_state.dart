import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../core/constants.dart';
import '../../data/repositories/auth_repository.dart';
import '../../domain/models/app_user.dart';

enum AuthStatus { unknown, signedOut, signedIn }

/// The single source of truth for "who is signed in" across the app.
/// Screens read this via `context.watch<AuthState>()`and call its methods
/// rather than touching AuthRepository or FirebaseAuth directly.
class AuthState extends ChangeNotifier {
  final AuthRepository _repo = AuthRepository();

  AuthStatus status = AuthStatus.unknown;
  AppUser? currentUser;
  bool isLoading = false;
  String? errorMessage;

  AuthState() {
    _repo.authStateChanges.listen(_onFirebaseAuthChanged);
  }

  Future<void> _onFirebaseAuthChanged(fb.User? fbUser) async {
    if (fbUser == null) {
      currentUser = null;
      status = AuthStatus.signedOut;
      notifyListeners();
      return;
    }
    try {
      currentUser = await _repo.getUserProfile(fbUser.uid);
      status = AuthStatus.signedIn;
    } catch (_) {
      // Profile doc missing/unreadable (e.g. offline on first-ever launch
      // after a fresh install) — treat as signed out rather than crash.
      status = AuthStatus.signedOut;
    }
    notifyListeners();
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      currentUser = await _repo.register(
        name: name,
        email: email,
        password: password,
        role: role,
      );
      status = AuthStatus.signedIn;
      return true;
    } catch (e) {
      errorMessage = _friendlyError(e);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signIn({required String email, required String password}) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      currentUser = await _repo.signIn(email: email, password: password);
      status = AuthStatus.signedIn;
      return true;
    } catch (e) {
      errorMessage = _friendlyError(e);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _repo.signOut();
    currentUser = null;
    status = AuthStatus.signedOut;
    notifyListeners();
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('email-already-in-use')) {
      return 'That email is already registered.';
    }
    if (msg.contains('weak-password')) {
      return 'Password should be at least 6 characters.';
    }
    if (msg.contains('user-not-found') || msg.contains('wrong-password')) {
      return 'Incorrect email or password.';
    }
    if (msg.contains('network-request-failed')) {
      return 'No connection — check your network and try again.';
    }
    return 'Something went wrong. Please try again.';
  }
}
