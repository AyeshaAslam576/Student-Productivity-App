import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';

class AuthRepository {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _googleSignIn = GoogleSignIn();

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // ─── Email / Password ────────────────────────────────────────────────────

  Future<UserModel> signInWithEmail(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
        email: email, password: password);
    return _getOrCreateUserDoc(cred.user!);
  }

  Future<UserModel> signUpWithEmail(
    String name,
    String email,
    String password, {
    String? university,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
    await cred.user!.updateDisplayName(name);

    final user = UserModel(
      uid: cred.user!.uid,
      name: name,
      email: email,
      university: university?.trim().isEmpty ?? true ? null : university?.trim(),
      createdAt: DateTime.now(),
    );
    await _db.collection('users').doc(user.uid).set(user.toMap());
    return user;
  }

  // ─── Google Sign-In ───────────────────────────────────────────────────────

  Future<UserModel> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw Exception('Google sign-in cancelled');

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final cred = await _auth.signInWithCredential(credential);
    return _getOrCreateUserDoc(cred.user!);
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  /// Fetches user doc from Firestore, or creates one for first-time sign-ins.
  Future<UserModel> _getOrCreateUserDoc(User firebaseUser) async {
    final doc = await _db.collection('users').doc(firebaseUser.uid).get();
    if (doc.exists) {
      return UserModel.fromMap(firebaseUser.uid, doc.data()!);
    }
    // First login via Google (or missing doc) — create it
    final user = UserModel(
      uid: firebaseUser.uid,
      name: firebaseUser.displayName ?? '',
      email: firebaseUser.email ?? '',
      photoUrl: firebaseUser.photoURL,
      createdAt: DateTime.now(),
    );
    await _db.collection('users').doc(user.uid).set(user.toMap());
    return user;
  }

  // ─── Sign Out ─────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  // ─── Password Reset ───────────────────────────────────────────────────────

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // ─── Firestore User CRUD ─────────────────────────────────────────────────

  Future<UserModel?> fetchUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(uid, doc.data()!);
  }

  Future<void> updateUser(UserModel user) async {
    await _db.collection('users').doc(user.uid).update(user.toMap());
  }

  // ─── Delete Account ───────────────────────────────────────────────────────

  /// Permanently deletes all user data from Firestore then removes the
  /// Firebase Auth account.
  ///
  /// Re-authentication is always required before deletion:
  ///   - Email/password users must supply [password].
  ///   - Google users trigger a silent Google sign-in to obtain a fresh token.
  ///
  /// Throws [FirebaseAuthException] on wrong credentials or cancelled sign-in.
  Future<void> deleteAccount({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not signed in');

    final isEmailUser =
        user.providerData.any((p) => p.providerId == 'password');

    // ── Re-authenticate ──────────────────────────────────────────────────────
    if (isEmailUser) {
      if (password == null || password.isEmpty) {
        throw Exception('Password is required to delete an email account');
      }
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
    } else {
      // Google — obtain fresh credentials
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw FirebaseAuthException(
          code: 'sign_in_cancelled',
          message: 'Google sign-in was cancelled',
        );
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await user.reauthenticateWithCredential(credential);
    }

    // ── Delete Firestore data ────────────────────────────────────────────────
    // Firestore doesn't recursively delete — subcollections must be cleared
    // before their parent documents, otherwise orphaned subcollection docs
    // remain readable (violating user privacy) until security rules block them.
    await _deleteUserData(user.uid);

    // ── Delete Firebase Auth account ─────────────────────────────────────────
    await user.delete();
    await _googleSignIn.signOut();
  }

  /// Deletes all subcollections under [users/{uid}] then the profile document.
  Future<void> _deleteUserData(String uid) async {
    final userRef = _db.collection('users').doc(uid);

    // Collections with nested subcollections — delete children first.
    final attSnap = await userRef.collection('attendance').get();
    for (final doc in attSnap.docs) {
      await _deleteDocs(doc.reference.collection('records'));
      await doc.reference.delete();
    }

    final semSnap = await userRef.collection('semesters').get();
    for (final doc in semSnap.docs) {
      await _deleteDocs(doc.reference.collection('subjects'));
      await doc.reference.delete();
    }

    final ttSnap = await userRef.collection('timetables').get();
    for (final doc in ttSnap.docs) {
      await _deleteDocs(doc.reference.collection('lectures'));
      await doc.reference.delete();
    }

    // Flat collections — no nested subcollections.
    for (final name in const [
      'tasks',
      'ai_sessions',
      'study_sessions',
      'documents',
    ]) {
      await _deleteDocs(userRef.collection(name));
    }

    // Remove the root user profile document last.
    await userRef.delete();
  }

  /// Deletes all documents in [col] using batches of ≤ 500 writes.
  Future<void> _deleteDocs(CollectionReference col) async {
    const batchSize = 500;
    QuerySnapshot snap;
    do {
      snap = await col.limit(batchSize).get();
      if (snap.docs.isEmpty) break;
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } while (snap.docs.length == batchSize);
  }
}
