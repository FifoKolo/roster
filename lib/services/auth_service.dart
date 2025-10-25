import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authState$ => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
  }

  Future<UserCredential> signUp(String email, String password, {String? displayName}) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    if (displayName != null && displayName.isNotEmpty) {
      await cred.user?.updateDisplayName(displayName);
    }
    await cred.user?.sendEmailVerification();
    return cred;
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> resendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not signed in');
    await user.sendEmailVerification();
  }

  Future<void> refreshUser() async {
    final user = _auth.currentUser;
    if (user != null) await user.reload();
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
