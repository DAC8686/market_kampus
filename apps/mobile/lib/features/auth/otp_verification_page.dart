import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/supabase_config.dart';
import '../../core/theme/mpus_theme.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/profile_service.dart';
import '../../data/services/firebase_notification_service.dart';
import '../../data/services/backend_auth_service.dart';
import '../catalog/home_page.dart';

class OtpVerificationPage extends StatefulWidget {
  final String email;
  final String password;
  final String name;
  final String phone;
  final String nim;
  final String campusName;

  const OtpVerificationPage({
    super.key,
    required this.email,
    required this.password,
    required this.name,
    required this.phone,
    required this.nim,
    required this.campusName,
  });

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  final BackendAuthService _backendAuthService = BackendAuthService();
  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();

  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isVerifying = false;
  bool _isResending = false;
  int _resendCountdown = 60;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startResendTimer() {
    setState(() => _resendCountdown = 60);
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        if (mounted) setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  String get _otpCode => _controllers.map((c) => c.text.trim()).join();

  Future<void> _openEmailApp() async {
    final Uri emailLaunchUri = Uri(scheme: 'mailto');
    try {
      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(emailLaunchUri);
      } else {
        final Uri webGmail = Uri.parse('https://mail.google.com');
        await launchUrl(webGmail, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Silakan buka aplikasi Gmail / Email di HP Anda.")),
        );
      }
    }
  }

  void _onDigitChanged(int index, String value) {
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
      for (int i = 0; i < digits.length && (index + i) < 6; i++) {
        _controllers[index + i].text = digits[i];
      }
      final nextIndex = (index + digits.length).clamp(0, 5);
      _focusNodes[nextIndex].requestFocus();
      if (_otpCode.length == 6) {
        _verifyOtp();
      }
      return;
    }

    if (value.isNotEmpty) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        if (_otpCode.length == 6) {
          _verifyOtp();
        }
      }
    }
  }

  Future<void> _verifyOtp() async {
    final code = _otpCode;
    if (code.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Harap masukkan 6 digit kode OTP secara lengkap")),
      );
      return;
    }

    setState(() => _isVerifying = true);

    try {
      // 1. Verifikasi OTP ke Backend Server
      final result = await _backendAuthService.verifyOtp(
        email: widget.email,
        otp: code,
      );

      if (!result.success) {
        throw Exception(result.message);
      }

      // 2. Registrasi / Sesi Login Supabase
      String? currentUid = _authService.currentUserId ?? SupabaseConfig.currentUserId;
      if (currentUid == null) {
        try {
          final res = await _authService.signUp(
            email: widget.email,
            password: widget.password,
            name: widget.name,
            phone: widget.phone,
            nim: widget.nim,
            campusName: widget.campusName,
          );
          currentUid = res.user?.id ?? _authService.currentUserId;
        } catch (_) {
          try {
            final res = await _authService.signIn(email: widget.email, password: widget.password);
            currentUid = res.user?.id ?? _authService.currentUserId;
          } catch (_) {}
        }
      }

      currentUid ??= _authService.currentUserId ?? SupabaseConfig.currentUserId;
      if (currentUid != null) {
        // 3. Simpan Profil Mahasiswa Terverifikasi
        await _profileService.updateProfile(
          userId: currentUid,
          name: widget.name,
          email: widget.email,
          phone: widget.phone,
          nim: widget.nim,
          campusName: widget.campusName,
          isKtmVerified: true,
          verificationStatus: 'VERIFIED',
        );
      }

      // 4. Sinkronisasi Token FCM
      try {
        await FirebaseNotificationService().syncTokenToProfile();
      } catch (_) {}

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Verifikasi email berhasil! Selamat datang di Mpus."),
          backgroundColor: Colors.green,
        ),
      );

      // 5. Masuk ke Beranda
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '').replaceAll('AuthException: ', '')),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _directLoginWithAiVerifiedKtm() async {
    setState(() => _isVerifying = true);
    try {
      String? currentUid = _authService.currentUserId ?? SupabaseConfig.currentUserId;
      if (currentUid == null) {
        try {
          final res = await _authService.signUp(
            email: widget.email,
            password: widget.password,
            name: widget.name,
            phone: widget.phone,
            nim: widget.nim,
            campusName: widget.campusName,
          );
          currentUid = res.user?.id ?? _authService.currentUserId;
        } catch (_) {
          try {
            final res = await _authService.signIn(email: widget.email, password: widget.password);
            currentUid = res.user?.id ?? _authService.currentUserId;
          } catch (_) {}
        }
      }

      currentUid ??= _authService.currentUserId ?? SupabaseConfig.currentUserId;
      if (currentUid != null) {
        await _profileService.updateProfile(
          userId: currentUid,
          name: widget.name,
          email: widget.email,
          phone: widget.phone,
          nim: widget.nim,
          campusName: widget.campusName,
          isKtmVerified: true,
          verificationStatus: 'VERIFIED',
        );

        try {
          await FirebaseNotificationService().syncTokenToProfile();
        } catch (_) {}

        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
          (route) => false,
        );
        return;
      }
      throw Exception("Silakan lakukan pendaftaran atau login terlebih dahulu.");
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Masuk Langsung: ${e.toString().replaceAll('AuthException: ', '').replaceAll('Exception: ', '')}"),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _resendOtp() async {
    if (_resendCountdown > 0 || _isResending) return;

    setState(() => _isResending = true);

    try {
      final result = await _backendAuthService.resendOtp(email: widget.email);
      if (!result.success) {
        throw Exception(result.message);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Kode OTP baru telah dikirimkan ke email ${widget.email}."),
          backgroundColor: Colors.green,
        ),
      );
      _startResendTimer();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Gagal mengirim ulang OTP: ${e.toString().replaceAll('Exception: ', '')}"),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MpusTheme.primaryColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: MpusTheme.textSecondaryColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 30,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD9D9D9).withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: const Color(0xFFD9D9D9).withValues(alpha: 0.35),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: MpusTheme.accentBlue.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.mark_email_read_outlined,
                                size: 48,
                                color: MpusTheme.accentBlue,
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              "Verifikasi Email",
                              style: TextStyle(
                                fontSize: 24,
                                fontFamily: "Roboto",
                                fontWeight: FontWeight.w700,
                                color: MpusTheme.textSecondaryColor,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              "Masukkan 6 digit kode OTP resmi Mpus yang telah dikirimkan ke:",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontFamily: "Roboto",
                                color: Color(0xFF555555),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                widget.email,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontFamily: "Roboto",
                                  fontWeight: FontWeight.bold,
                                  color: MpusTheme.textSecondaryColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // 6-Digit PIN Boxes
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(6, (index) {
                                return SizedBox(
                                  width: 44,
                                  height: 52,
                                  child: KeyboardListener(
                                    focusNode: FocusNode(),
                                    onKeyEvent: (event) {
                                      if (event is KeyDownEvent &&
                                          event.logicalKey == LogicalKeyboardKey.backspace &&
                                          _controllers[index].text.isEmpty &&
                                          index > 0) {
                                        _focusNodes[index - 1].requestFocus();
                                      }
                                    },
                                    child: TextField(
                                      controller: _controllers[index],
                                      focusNode: _focusNodes[index],
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      maxLength: 1,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: MpusTheme.textPrimaryColor,
                                      ),
                                      decoration: InputDecoration(
                                        counterText: '',
                                        filled: true,
                                        fillColor: Colors.white,
                                        contentPadding: EdgeInsets.zero,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide.none,
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                            color: MpusTheme.accentBlue,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                      onChanged: (val) => _onDigitChanged(index, val),
                                    ),
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 24),

                            // Tombol Verifikasi
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: ElevatedButton(
                                onPressed: _isVerifying ? null : _verifyOtp,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: MpusTheme.accentBlue,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                ),
                                child: _isVerifying
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        "Verifikasi & Masuk",
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontFamily: "Roboto",
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Tombol Buka Aplikasi Email
                            SizedBox(
                              width: double.infinity,
                              height: 42,
                              child: OutlinedButton.icon(
                                onPressed: _openEmailApp,
                                icon: const Icon(Icons.mail_outline_rounded, size: 18),
                                label: const Text(
                                  "Buka Aplikasi Email",
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: MpusTheme.textSecondaryColor, width: 1.5),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Kirim Ulang OTP
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  "Tidak menerima kode? ",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontFamily: "Roboto",
                                    color: MpusTheme.textSecondaryColor,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: (_resendCountdown == 0 && !_isResending) ? _resendOtp : null,
                                  child: Text(
                                    _resendCountdown > 0 ? "Kirim Ulang ($_resendCountdown s)" : "Kirim Ulang",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontFamily: "Roboto",
                                      fontWeight: FontWeight.bold,
                                      color: _resendCountdown > 0 ? const Color(0xFF888888) : MpusTheme.accentBlue,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),
                            // Direct Bypass AI Verification Option
                            TextButton.icon(
                              onPressed: _isVerifying ? null : _directLoginWithAiVerifiedKtm,
                              icon: const Icon(Icons.verified_user_rounded, size: 16, color: MpusTheme.accentBlue),
                              label: const Text(
                                "KTM Sudah Lolos AI? Masuk Langsung",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: MpusTheme.accentBlue,
                                ),
                              ),
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
