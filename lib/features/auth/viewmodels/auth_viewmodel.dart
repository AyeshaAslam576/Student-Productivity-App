import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';

enum AuthState { initial, loading, authenticated, unauthenticated, error }

class AuthViewModel extends ChangeNotifier {
  final AuthRepository _repo;

  AuthState _state = AuthState.initial;
  UserModel? _user;
  String? _error;

  AuthViewModel(this._repo) {
    _repo.authStateChanges.listen(_onAuthChange);
  }

  AuthState get state => _state;
  UserModel? get user => _user;
  String? get error => _error;
  bool get isLoading => _state == AuthState.loading;
  bool get isAuthenticated => _state == AuthState.authenticated;

  bool get isEmailPasswordUser {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    return user.providerData.any((p) => p.providerId == 'password');
  }

  // ─── Auth State Listener ──────────────────────────────────────────────────

  Future<void> _onAuthChange(User? firebaseUser) async {
    if (firebaseUser == null) {
      _user = null;
      _state = AuthState.unauthenticated;
      notifyListeners();
      return;
    }
    try {
      final user = await _repo.fetchUser(firebaseUser.uid);
      _user = user ??
          UserModel(
            uid: firebaseUser.uid,
            name: firebaseUser.displayName ?? '',
            email: firebaseUser.email ?? '',
            photoUrl: firebaseUser.photoURL,
            createdAt: DateTime.now(),
          );
      _state = AuthState.authenticated;
    } catch (_) {
      _state = AuthState.authenticated;
    }
    notifyListeners();
  }

  // ─── Email / Password ────────────────────────────────────────────────────

  Future<bool> signIn(String email, String password) async {
    _setLoading();
    try {
      _user = await _repo.signInWithEmail(email, password);
      _state = AuthState.authenticated;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_mapFirebaseError(e.code));
      return false;
    } catch (e) {
      _setError('Authentication failed. Please try again');
      return false;
    }
  }

  Future<bool> signUp(
    String name,
    String email,
    String password, {
    String? university,
  }) async {
    _setLoading();
    try {
      _user = await _repo.signUpWithEmail(
        name,
        email,
        password,
        university: university,
      );
      _state = AuthState.authenticated;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_mapFirebaseError(e.code));
      return false;
    } catch (e) {
      _setError('Registration failed. Please try again');
      return false;
    }
  }

  // ─── Google Sign-In ───────────────────────────────────────────────────────

  Future<bool> signInWithGoogle() async {
    _setLoading();
    try {
      _user = await _repo.signInWithGoogle();
      _state = AuthState.authenticated;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_mapFirebaseError(e.code));
      return false;
    } catch (e) {
      final msg = e.toString();
      // User cancelled — silently go back to unauthenticated
      if (msg.contains('cancelled') || msg.contains('sign_in_cancelled')) {
        _state = AuthState.unauthenticated;
        _error = null;
        notifyListeners();
        return false;
      }
      _setError('Google sign-in failed. Please try again');
      return false;
    }
  }

  // ─── Sign Out ─────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _repo.signOut();
    _user = null;
    _state = AuthState.unauthenticated;
    notifyListeners();
  }

  // ─── Password Reset ───────────────────────────────────────────────────────

  Future<bool> resetPassword(String email) async {
    try {
      await _repo.resetPassword(email);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final firebaseUser = _repo.currentUser;
    if (firebaseUser == null) throw Exception('Not signed in');
    final credential = EmailAuthProvider.credential(
      email: firebaseUser.email!,
      password: currentPassword,
    );
    await firebaseUser.reauthenticateWithCredential(credential);
    await firebaseUser.updatePassword(newPassword);
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  /// Updates in-memory [user] immediately (e.g. after profile save).
  void setUser(UserModel user) {
    _user = user;
    notifyListeners();
  }

  /// Re-fetches the user document from Firestore and updates [user].
  /// Call this after updating profile data (e.g. photoBase64).
  Future<void> reloadUser() async {
    final firebaseUser = _repo.currentUser;
    if (firebaseUser == null) return;
    try {
      final updated = await _repo.fetchUser(firebaseUser.uid);
      if (updated != null) {
        _user = updated;
        notifyListeners();
      }
    } catch (_) {}
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setLoading() {
    _state = AuthState.loading;
    _error = null;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    _state = AuthState.error;
    notifyListeners();
  }

  String _mapFirebaseError(String code) {
    return switch (code) {
      'user-not-found' => 'No account found with this email',
      'wrong-password' => 'Incorrect password',
      'invalid-credential' => 'Invalid email or password',
      'email-already-in-use' => 'Email is already registered',
      'weak-password' => 'Password must be at least 6 characters',
      'invalid-email' => 'Invalid email address',
      'too-many-requests' => 'Too many attempts. Try again later',
      'user-disabled' => 'This account has been disabled',
      'network-request-failed' => 'No internet connection',
      _ => 'Authentication failed. Please try again',
    };
  }
}
