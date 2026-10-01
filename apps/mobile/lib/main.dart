import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/config/supabase_config.dart';
import 'core/theme/mpus_theme.dart';
import 'data/services/firebase_notification_service.dart';
import 'features/splash/splash_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Inisialisasi Supabase Backend
  await SupabaseConfig.initialize();

  // 2. Inisialisasi Firebase & FCM Notifikasi (Graceful fallback)
  try {
    await Firebase.initializeApp();
    await FirebaseNotificationService.initialize();
  } catch (e) {
    debugPrint("Firebase init note: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mpus — Market Kampus',
      debugShowCheckedModeBanner: false,
      theme: MpusTheme.lightTheme,
      home: const SplashPage(),
    );
  }
}
