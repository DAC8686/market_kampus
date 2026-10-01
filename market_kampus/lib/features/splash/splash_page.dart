import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../../core/theme/mpus_theme.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/profile_service.dart';
import '../auth/login_page.dart';
import '../auth/complete_profile_page.dart';
import '../catalog/home_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();

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
        final userId = _authService.currentUserId;
        bool isComplete = true;
        if (userId != null) {
          isComplete = await _profileService.isProfileComplete(userId);
        }

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
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    double scaleW = screenWidth / 412;
    double scaleH = screenHeight / 920;

    return Scaffold(
      backgroundColor: MpusTheme.primaryColor,
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  'assets/LogoMpus.svg',
                  height: 120 * scaleW,
                  placeholderBuilder: (BuildContext context) => SizedBox(
                    width: 48 * scaleW,
                    height: 48 * scaleW,
                    child: LoadingAnimationWidget.staggeredDotsWave(
                      color: MpusTheme.textSecondaryColor,
                      size: 48 * scaleW,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 182 * scaleW,
            top: 818 * scaleH,
            child: SizedBox(
              width: 48 * scaleW,
              height: 48 * scaleW,
              child: LoadingAnimationWidget.staggeredDotsWave(
                color: MpusTheme.textSecondaryColor,
                size: 48 * scaleW,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
