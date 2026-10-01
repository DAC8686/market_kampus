import 'otp_verification_page.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../../core/theme/mpus_theme.dart';
import '../../data/services/backend_auth_service.dart';

class ValidationWaitingPage extends StatefulWidget {
  final String name;
  final String email;
  final String nim;
  final String phone;
  final String password;
  final File ktmFile;

  const ValidationWaitingPage({
    super.key,
    required this.name,
    required this.email,
    required this.nim,
    required this.phone,
    required this.password,
    required this.ktmFile,
  });

  @override
  State<ValidationWaitingPage> createState() => _ValidationWaitingPageState();
}

class _ValidationWaitingPageState extends State<ValidationWaitingPage> {
  final BackendAuthService _backendAuthService = BackendAuthService();

  String _statusMessage = "Memindai KTM dengan AI...";
  String _subMessage = "Mohon tunggu sebentar, AI Gemini sedang memverifikasi KTM dan menyiapkan kode OTP.";

  @override
  void initState() {
    super.initState();
    _startValidationProcess();
  }

  Future<void> _startValidationProcess() async {
    await Future.delayed(const Duration(milliseconds: 600));

    try {
      setState(() {
        _statusMessage = "Menganalisis Dokumen KTM...";
        _subMessage = "AI Gemini sedang mencocokkan data NIM dan instansi kampus.";
      });

      final result = await _backendAuthService.registerWithKtm(
        name: widget.name,
        email: widget.email,
        password: widget.password,
        nim: widget.nim,
        phone: widget.phone,
        ktmFile: widget.ktmFile,
      );

      if (!result.success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Validasi Ditolak: ${result.message}"),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.pop(context);
        return;
      }

      if (!mounted) return;

      setState(() {
        _statusMessage = "Mengirim Email OTP Resmi...";
        _subMessage = "KTM Terverifikasi (${result.campusName ?? 'Kampus'}). Email OTP resmi telah dikirim ke ${widget.email}.";
      });

      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      // Pindahkan ke Halaman Input OTP
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => OtpVerificationPage(
            email: widget.email,
            password: widget.password,
            name: widget.name,
            phone: widget.phone,
            nim: widget.nim,
            campusName: result.campusName ?? "Kampus",
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Terjadi kesalahan: ${e.toString().replaceAll('Exception: ', '')}"),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 4),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: MpusTheme.primaryColor,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 36,
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
                        SvgPicture.asset(
                          'assets/LogoMpus.svg',
                          width: 80,
                          height: 98,
                          colorFilter: const ColorFilter.mode(
                            MpusTheme.textSecondaryColor,
                            BlendMode.srcIn,
                          ),
                        ),
                        const SizedBox(height: 28),
                        LoadingAnimationWidget.staggeredDotsWave(
                          color: MpusTheme.textSecondaryColor,
                          size: 46,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _statusMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontFamily: "Roboto",
                            fontWeight: FontWeight.w700,
                            color: MpusTheme.textSecondaryColor,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _subMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            fontFamily: "Roboto",
                            color: Color(0xFF555555),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
