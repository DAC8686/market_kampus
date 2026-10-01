import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_svg/svg.dart';
import '../../core/theme/mpus_theme.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/profile_service.dart';
import '../../data/services/firebase_notification_service.dart';
import '../catalog/home_page.dart';
import 'complete_profile_page.dart';
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

  Future<void> _handlePostLoginNavigation(String userId) async {
    final isComplete = await _profileService.isProfileComplete(userId);

    if (!mounted) return;

    if (isComplete) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const CompleteProfilePage()),
      );
    }
  }

  Future<void> _signIn() async {
    final nimInput = _nimController.text.trim();
    final password = _passwordController.text.trim();

    if (nimInput.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Harap isi NIM dan Password")),
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
      await FirebaseNotificationService().syncTokenToProfile();

      if (response.user != null) {
        await _handlePostLoginNavigation(response.user!.id);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal masuk: ${e.toString().replaceAll('AuthException: ', '')}")),
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
        // 🛡️ Security Guard: Cek apakah akun Google sudah terdaftar di Mpus
        final profile = await _profileService.getProfile(user.id);
        final phone = profile?['phone']?.toString().trim() ?? '';
        final nim = profile?['nim']?.toString().trim() ?? '';
        final ktmUrl = profile?['ktm_image_url']?.toString().trim() ?? '';

        final isRegistered = phone.isNotEmpty || nim.isNotEmpty || ktmUrl.isNotEmpty;

        if (!isRegistered) {
          // Akun belum terdaftar -> Batalkan sesi login & arahkan ke registrasi
          await _authService.signOut();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Akun Google Anda belum terdaftar di Mpus. Silakan daftar terlebih dahulu."),
              action: SnackBarAction(
                label: "Daftar",
                textColor: MpusTheme.accentBlue,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RegisterPage()),
                  );
                },
              ),
            ),
          );
          return;
        }

        // Akun sudah terdaftar -> Sinkronkan token & navigasi
        await FirebaseNotificationService().syncTokenToProfile();
        await _handlePostLoginNavigation(user.id);
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
    double screenWidth = MediaQuery.of(context).size.width;
    double scaleW = screenWidth / 412;

    return Scaffold(
      backgroundColor: MpusTheme.primaryColor,
      body: SingleChildScrollView(
        child: SizedBox(
          height: 920 * scaleW,
          width: double.infinity,
          child: Stack(
            children: [
              Positioned(
                left: 157 * scaleW,
                top: 400 * scaleW,
                child: SvgPicture.asset(
                  'assets/LogoMpus.svg',
                  width: 98 * scaleW,
                  height: 119 * scaleW,
                  colorFilter: const ColorFilter.mode(
                    MpusTheme.textSecondaryColor,
                    BlendMode.srcIn,
                  ),
                ),
              ),

              Positioned(
                left: 38 * scaleW,
                top: 200 * scaleW,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24 * scaleW),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      width: 336 * scaleW,
                      height: 420 * scaleW,
                      padding: EdgeInsets.only(
                        top: 10 * scaleW,
                        left: 25 * scaleW,
                        right: 25 * scaleW,
                        bottom: 10 * scaleW,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD9D9D9).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(24 * scaleW),
                        border: Border.all(
                          color: const Color(0xFFD9D9D9).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            "Masuk",
                            style: TextStyle(
                              fontSize: 36 * scaleW,
                              fontFamily: "Roboto",
                              fontWeight: FontWeight.w700,
                              color: MpusTheme.textSecondaryColor,
                            ),
                          ),

                          SizedBox(height: 25 * scaleW),
                          SizedBox(
                            width: 250 * scaleW,
                            height: 38 * scaleW,
                            child: TextField(
                              controller: _nimController,
                              keyboardType: TextInputType.number,
                              style: TextStyle(
                                color: MpusTheme.textPrimaryColor,
                                fontSize: 14 * scaleW,
                                fontFamily: "Roboto",
                              ),
                              textAlignVertical: TextAlignVertical.center,
                              decoration: InputDecoration(
                                isDense: true,
                                labelText: 'NIM',
                                floatingLabelBehavior: FloatingLabelBehavior.auto,
                                floatingLabelStyle: TextStyle(
                                  color: const Color(0xFF8F8F8F),
                                  fontSize: 14 * scaleW,
                                  fontFamily: "Roboto",
                                ),
                                labelStyle: TextStyle(
                                  color: MpusTheme.textSecondaryColor,
                                  fontSize: 14 * scaleW,
                                  fontFamily: "Roboto",
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 18 * scaleW,
                                  vertical: 8 * scaleW,
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(25 * scaleW),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 16 * scaleW),
                          SizedBox(
                            width: 250 * scaleW,
                            height: 38 * scaleW,
                            child: TextField(
                              controller: _passwordController,
                              obscureText: true,
                              style: TextStyle(
                                color: MpusTheme.textPrimaryColor,
                                fontSize: 14 * scaleW,
                                fontFamily: "Roboto",
                              ),
                              textAlignVertical: TextAlignVertical.center,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                floatingLabelBehavior: FloatingLabelBehavior.auto,
                                floatingLabelStyle: TextStyle(
                                  color: const Color(0xFF8F8F8F),
                                  fontSize: 14 * scaleW,
                                  fontFamily: "Roboto",
                                ),
                                labelStyle: TextStyle(
                                  color: MpusTheme.textSecondaryColor,
                                  fontSize: 14 * scaleW,
                                  fontFamily: "Roboto",
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 18 * scaleW,
                                  vertical: 8 * scaleW,
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(25 * scaleW),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 24 * scaleW),
                          SizedBox(
                            width: 140 * scaleW,
                            height: 35 * scaleW,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _signIn,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD9D9D9),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30 * scaleW),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF8F8F8F)),
                                    )
                                  : Text(
                                      "MASUK",
                                      style: TextStyle(
                                        color: const Color(0xFF8F8F8F),
                                        fontSize: 16 * scaleW,
                                        fontFamily: "Roboto",
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                          SizedBox(height: 14 * scaleW),

                          // Tombol Pintas Google Sign-In
                          SizedBox(
                            width: 250 * scaleW,
                            height: 36 * scaleW,
                            child: OutlinedButton.icon(
                              onPressed: _isGoogleLoading ? null : _signInWithGoogle,
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white,
                                side: const BorderSide(color: Color(0xFFE0E0E0)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25 * scaleW),
                                ),
                              ),
                              icon: _isGoogleLoading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.g_mobiledata_rounded, color: Color(0xFFEA4335), size: 24),
                              label: Text(
                                "Masuk dengan Google",
                                style: TextStyle(
                                  color: MpusTheme.textPrimaryColor,
                                  fontSize: 13 * scaleW,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: "Roboto",
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: 14 * scaleW),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Belum memiliki akun? ",
                                style: TextStyle(
                                  color: MpusTheme.textSecondaryColor,
                                  fontFamily: "Roboto",
                                  fontSize: 14 * scaleW,
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
                                child: Text(
                                  "Daftar",
                                  style: TextStyle(
                                    fontFamily: "Roboto",
                                    color: MpusTheme.accentBlue,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14 * scaleW,
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
