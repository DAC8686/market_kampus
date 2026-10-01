import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_svg/svg.dart';
import '../../core/theme/mpus_theme.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/profile_service.dart';
import '../../data/services/firebase_notification_service.dart';
import '../catalog/home_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _nimController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  @override
  void dispose() {
    _nimController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handlePostLoginNavigation() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomePage()),
    );
  }

  Future<void> _signIn() async {
    final nimInput = _nimController.text.trim();
    final password = _passwordController.text.trim();

    if (nimInput.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Harap isi NIM / Email dan Password")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String email = nimInput.contains('@') ? nimInput : "$nimInput@mpus.com";

      if (!nimInput.contains('@')) {
        try {
          final profile = await _profileService.findProfileByNim(nimInput);
          final registeredEmail = profile?['email']?.toString().trim();
          if (registeredEmail != null && registeredEmail.isNotEmpty) {
            email = registeredEmail;
          }
        } catch (_) {}
      }

      final response = await _authService.signIn(
        email: email,
        password: password,
      );

      // Sync FCM token
      try {
        await FirebaseNotificationService().syncTokenToProfile();
      } catch (_) {}

      if (response.user != null) {
        _handlePostLoginNavigation();
      }
    } catch (e) {
      if (!mounted) return;
      final errStr = e.toString();
      String message = "Gagal masuk: ${errStr.replaceAll('AuthException: ', '').replaceAll('Exception: ', '')}";
      
      if (errStr.contains('Invalid login credentials') || errStr.contains('invalid_credentials')) {
        message = "Kredensial tidak cocok. Jika akun Anda didaftarkan via Google, silakan masuk dengan tombol 'Masuk dengan Google' di bawah.";
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 4),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isGoogleLoading = true);

    try {
      final response = await _authService.signInWithGoogle();
      final user = response.user;

      if (user != null) {
        // 1. Sinkronisasi Profil Pengguna Google ke Golang Gateway
        try {
          final rawMeta = user.userMetadata ?? {};
          final name = rawMeta['name']?.toString() ??
              rawMeta['full_name']?.toString() ??
              user.email?.split('@').first ??
              'Pengguna Mpus';
          final avatar = rawMeta['avatar_url']?.toString() ??
              rawMeta['picture']?.toString();

          await _profileService.syncGoogleProfile(
            id: user.id,
            email: user.email ?? '',
            name: name,
            avatarUrl: avatar,
          );
        } catch (syncErr) {
          debugPrint("Google profile sync warning: $syncErr");
        }

        // 2. Sync FCM token
        try {
          await FirebaseNotificationService().syncTokenToProfile();
        } catch (_) {}

        // 3. Masuk ke Beranda
        _handlePostLoginNavigation();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Google Sign-In: ${e.toString().replaceAll('Exception: ', '')}")),
      );
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MpusTheme.primaryColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/LogoMpus.svg',
                    width: 98,
                    height: 119,
                    colorFilter: const ColorFilter.mode(
                      MpusTheme.textSecondaryColor,
                      BlendMode.srcIn,
                    ),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 30,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD9D9D9).withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: const Color(0xFFD9D9D9).withValues(alpha: 0.35),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              "Masuk",
                              style: TextStyle(
                                fontSize: 32,
                                fontFamily: "Roboto",
                                fontWeight: FontWeight.w700,
                                color: MpusTheme.textSecondaryColor,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Field NIM
                            SizedBox(
                              height: 44,
                              child: TextField(
                                controller: _nimController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(
                                  color: MpusTheme.textPrimaryColor,
                                  fontSize: 14,
                                  fontFamily: "Roboto",
                                ),
                                textAlignVertical: TextAlignVertical.center,
                                decoration: InputDecoration(
                                  isDense: true,
                                  labelText: 'NIM',
                                  floatingLabelBehavior: FloatingLabelBehavior.auto,
                                  floatingLabelStyle: const TextStyle(
                                    color: Color(0xFF8F8F8F),
                                    fontSize: 14,
                                    fontFamily: "Roboto",
                                  ),
                                  labelStyle: const TextStyle(
                                    color: MpusTheme.textSecondaryColor,
                                    fontSize: 14,
                                    fontFamily: "Roboto",
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 10,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(22),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Field Password
                            SizedBox(
                              height: 44,
                              child: TextField(
                                controller: _passwordController,
                                obscureText: true,
                                style: const TextStyle(
                                  color: MpusTheme.textPrimaryColor,
                                  fontSize: 14,
                                  fontFamily: "Roboto",
                                ),
                                textAlignVertical: TextAlignVertical.center,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  floatingLabelBehavior: FloatingLabelBehavior.auto,
                                  floatingLabelStyle: const TextStyle(
                                    color: Color(0xFF8F8F8F),
                                    fontSize: 14,
                                    fontFamily: "Roboto",
                                  ),
                                  labelStyle: const TextStyle(
                                    color: MpusTheme.textSecondaryColor,
                                    fontSize: 14,
                                    fontFamily: "Roboto",
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 10,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(22),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Tombol Masuk
                            SizedBox(
                              width: 150,
                              height: 40,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _signIn,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD9D9D9),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF8F8F8F)),
                                      )
                                    : const Text(
                                        "MASUK",
                                        style: TextStyle(
                                          color: Color(0xFF8F8F8F),
                                          fontSize: 15,
                                          fontFamily: "Roboto",
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Tombol Pintas Google Sign-In
                            SizedBox(
                              width: double.infinity,
                              height: 40,
                              child: OutlinedButton.icon(
                                onPressed: _isGoogleLoading ? null : _signInWithGoogle,
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  side: const BorderSide(color: Color(0xFFE0E0E0)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                icon: _isGoogleLoading
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.g_mobiledata_rounded, color: Color(0xFFEA4335), size: 24),
                                label: const Text(
                                  "Masuk dengan Google",
                                  style: TextStyle(
                                    color: MpusTheme.textPrimaryColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: "Roboto",
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  "Belum memiliki akun? ",
                                  style: TextStyle(
                                    color: MpusTheme.textSecondaryColor,
                                    fontFamily: "Roboto",
                                    fontSize: 13,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const RegisterPage(),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    "Daftar",
                                    style: TextStyle(
                                      fontFamily: "Roboto",
                                      color: MpusTheme.accentBlue,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
