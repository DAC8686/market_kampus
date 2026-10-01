import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../../core/theme/mpus_theme.dart';
import '../../data/services/auth_service.dart';
import '../auth/login_page.dart';
import '../catalog/home_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  // Check internet & Supabase session
  Future<void> _checkConnection() async {
    await Future.delayed(const Duration(milliseconds: 1800));

    if (!mounted) return;

    try {
      final connectivityResults = await Connectivity().checkConnectivity();
      if (connectivityResults.contains(ConnectivityResult.none) && connectivityResults.length == 1) {
        if (mounted) _showNoInternetDialog();
        return;
      }

      if (!mounted) return;

      if (_authService.isAuthenticated) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  void _showNoInternetDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Tidak Ada Internet'),
        content: const Text(
          'Pastikan wifi atau data seluler Anda aktif lalu coba lagi.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _checkConnection();
            },
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MpusTheme.primaryColor,
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),
              SvgPicture.asset(
                'assets/LogoMpus.svg',
                height: 120,
                placeholderBuilder: (BuildContext context) => SizedBox(
                  width: 48,
                  height: 48,
                  child: LoadingAnimationWidget.staggeredDotsWave(
                    color: MpusTheme.textSecondaryColor,
                    size: 48,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "MPUS",
                style: TextStyle(
                  fontFamily: "Roboto",
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: MpusTheme.textSecondaryColor,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "Marketplace Kampus Terpercaya",
                style: TextStyle(
                  fontFamily: "Roboto",
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF555555),
                ),
              ),
              const Spacer(flex: 3),
              SizedBox(
                width: 40,
                height: 40,
                child: LoadingAnimationWidget.staggeredDotsWave(
                  color: MpusTheme.textSecondaryColor,
                  size: 40,
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
