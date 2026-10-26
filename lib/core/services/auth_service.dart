import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Centralized Firebase Authentication service.
///
/// This supports:
/// - Email/password sign in
/// - Email/password account creation
/// - Google sign in on Android/iOS and web
/// - Password reset
/// - Anonymous guest accounts
/// - Linking a guest account to a real account so existing Firebase data
///   stays under the same UID when the guest creates an account.
class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  static Future<void>? _googleInitialization;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  bool get isSignedIn => _auth.currentUser != null;

  bool get isGuest => _auth.currentUser?.isAnonymous ?? false;

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> createAccountWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final credential = EmailAuthProvider.credential(
      email: email.trim(),
      password: password,
    );

    final existingUser = _auth.currentUser;

    UserCredential result;

    // Keep existing guest data when the guest creates an account.
    if (existingUser?.isAnonymous ?? false) {
      try {
        result = await existingUser!.linkWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        // The email may already belong to an existing account. In that case
        // signing into that account is the correct fallback instead of
        // attempting to create a duplicate identity.
        if (e.code == 'credential-already-in-use' ||
            e.code == 'email-already-in-use') {
          result = await _auth.signInWithEmailAndPassword(
            email: email.trim(),
            password: password,
          );
        } else {
          rethrow;
        }
      }
    } else {
      result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    }

    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) {
      await result.user?.updateDisplayName(name);
      await result.user?.reload();
    }

    return result;
  }

  Future<UserCredential> signInWithGoogle() async {
    // Flutter web should use Firebase's web Google provider instead of the
    // native google_sign_in flow.
    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      return _auth.signInWithPopup(provider);
    }

    await _initializeGoogleSignIn();

    final googleUser = await _googleSignIn.authenticate();
    final googleAuth = googleUser.authentication;

    final idToken = googleAuth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw FirebaseAuthException(
        code: 'google-id-token-missing',
        message: 'Google sign-in did not return an ID token.',
      );
    }

    final credential = GoogleAuthProvider.credential(
      idToken: idToken,
    );

    final existingUser = _auth.currentUser;

    // Keep guest data when a guest connects a Google account.
    if (existingUser?.isAnonymous ?? false) {
      try {
        return await existingUser!.linkWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        // If that Google account already exists, continue by signing into it.
        if (e.code == 'credential-already-in-use' ||
            e.code == 'provider-already-linked') {
          return _auth.signInWithCredential(credential);
        }
        rethrow;
      }
    }

    return _auth.signInWithCredential(credential);
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<UserCredential> continueAsGuest() {
    return _auth.signInAnonymously();
  }

  /// Backward-compatible helper for older app startup code.
  ///
  /// New startup code should NOT call this automatically, because that would
  /// skip the LoginPage. Use AuthGate instead and let the user choose
  /// Continue as Guest when needed.
  Future<void> ensureSignedIn() async {
    if (_auth.currentUser == null) {
      await continueAsGuest();
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();

    if (!kIsWeb) {
      try {
        await _googleSignIn.signOut();
      } catch (_) {
        // Firebase has already signed the user out. A Google SDK sign-out
        // failure should not block the app from returning to LoginPage.
      }
    }
  }

  Future<void> _initializeGoogleSignIn() async {
    _googleInitialization ??= _googleSignIn.initialize();
    await _googleInitialization;
  }

  String messageForException(Object error) {
    if (error is GoogleSignInException) {
      switch (error.code) {
        case GoogleSignInExceptionCode.canceled:
          return 'Google sign-in was cancelled.';
        default:
          return error.description ?? 'Google sign-in failed.';
      }
    }

    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          return 'Incorrect email or password.';

        case 'invalid-email':
          return 'Please enter a valid email address.';

        case 'email-already-in-use':
        case 'credential-already-in-use':
          return 'An account already exists with these credentials.';

        case 'weak-password':
          return 'Password is too weak. Use at least 6 characters.';

        case 'operation-not-allowed':
          return 'This sign-in method is not enabled in Firebase.';

        case 'network-request-failed':
          return 'Network error. Check your internet connection.';

        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';

        case 'google-id-token-missing':
          return error.message ?? 'Google sign-in failed.';

        default:
          return error.message ?? 'Authentication failed.';
      }
    }

    return error.toString().replaceFirst('Exception: ', '');
  }
}
