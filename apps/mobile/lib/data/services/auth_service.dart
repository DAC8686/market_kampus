import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';

class AuthService {
  final SupabaseClient _client = SupabaseConfig.client;
  final fb_auth.FirebaseAuth _fbAuth = fb_auth.FirebaseAuth.instance;

  User? get currentUser => _client.auth.currentUser;
  bool get isAuthenticated => currentUser != null;
  String? get currentUserId => currentUser?.id;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  // Sign Up with Email & Password + Firebase Email Verification
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String name,
    String? phone,
    String? nim,
    String? campusName,
  }) async {
    // 1. Kirim Email Verifikasi via Firebase Auth (Google Infrastructure)
    try {
      final fbCred = await _fbAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await fbCred.user?.sendEmailVerification();
      debugPrint("Firebase Auth verification email sent to ${email.trim()}");
    } catch (fbErr) {
      debugPrint("Firebase Auth create user / email send error: $fbErr");
      try {
        if (_fbAuth.currentUser != null) {
          await _fbAuth.currentUser?.sendEmailVerification();
        }
      } catch (_) {}
    }

    // 2. Registrasi & Simpan ke Supabase DB
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'name': name.trim(),
        'phone': phone?.trim() ?? '',
        'nim': nim?.trim() ?? '',
        'campus_name': campusName?.trim() ?? '',
        'is_ktm_verified': true,
        'verification_status': 'VERIFIED',
      },
    );
    return response;
  }

  // Sign In with Email & Password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    return response;
  }

  // Verify OTP token sent to Email
  Future<AuthResponse> verifyOtp({
    required String email,
    required String token,
    OtpType type = OtpType.signup,
  }) async {
    final response = await _client.auth.verifyOTP(
      email: email.trim(),
      token: token.trim(),
      type: type,
    );
    return response;
  }

  // Resend OTP token / Email Verification
  Future<ResendResponse?> resendOtp({
    required String email,
    OtpType type = OtpType.signup,
  }) async {
    try {
      if (_fbAuth.currentUser != null) {
        await _fbAuth.currentUser?.sendEmailVerification();
      }
    } catch (e) {
      debugPrint("Firebase resend error: $e");
    }

    try {
      final response = await _client.auth.resend(
        email: email.trim(),
        type: type,
      );
      return response;
    } catch (_) {
      return null;
    }
  }

  // Google Sign-In Shortcut integrated with Supabase Auth
  Future<AuthResponse> signInWithGoogle({String? serverClientId}) async {
    // 1. Trigger Google Sign-In account selector
    final GoogleSignIn googleSignIn = GoogleSignIn(
      serverClientId: serverClientId,
      scopes: ['email', 'profile'],
    );

    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      throw Exception("Login Google dibatalkan oleh pengguna.");
    }

    // 2. Obtain auth details (idToken & accessToken)
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;

    if (idToken == null) {
      throw Exception("Gagal mendapatkan ID Token dari Google. Pastikan Web Client ID & SHA-1 telah terdaftar di Google Cloud/Firebase Console.");
    }

    // 3. Authenticate with Supabase using the Google ID Token
    final AuthResponse response = await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );

    return response;
  }

  // Sign Out
  Future<void> signOut() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.signOut();
      }
    } catch (_) {}
    await _client.auth.signOut();
  }

  // Reset Password via Email
  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email.trim());
  }

  // Update Password
  Future<UserResponse> updatePassword(String newPassword) async {
    return await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }
}
