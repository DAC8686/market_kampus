import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MpusTheme {
  // Brand Colors
  static const Color primaryColor = Color(0xFFB4FFF9);
  static const Color cyanPrimary = Color(0xFFB4FFF9);
  static const Color cyanAccent = Color(0xFF00C4B4);
  static const Color cyanDark = Color(0xFF00838F);
  static const Color tealDark = Color(0xFF00838F);
  static const Color accentBlue = Color(0xFF43ABFF);

  // Neutral Colors
  static const Color backgroundColor = Color(0xFFF5F5F5);
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Colors.white;
  static const Color cardGray = Color(0xFFE5E5E5);
  static const Color borderGray = Color(0xFFB3B3B3);
  static const Color textSecondaryColor = Color(0xFFB3B3B3);
  static const Color textDark = Color(0xFF242D38);
  static const Color textDarkColor = Color(0xFF242D38);
  static const Color textPrimaryColor = Color(0xFF4A5568);
  static const Color textMuted = Color(0xFF8F8F8F);

  // Status Colors
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFED6C02);
  static const Color danger = Color(0xFFD32F2F);
  static const Color info = Color(0xFF0288D1);

  // Theme Data
  static ThemeData get lightTheme => ThemeData(
        scaffoldBackgroundColor: background,
        primaryColor: cyanPrimary,
        colorScheme: ColorScheme.fromSeed(
          seedColor: cyanAccent,
          primary: cyanAccent,
          secondary: cyanPrimary,
          surface: surface,
        ),
        useMaterial3: true,
      );

  // Text Styles
  static TextStyle get displayTitle => GoogleFonts.plusJakartaSans(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: textDark,
      );

  static TextStyle get heading => GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: textDark,
      );

  static TextStyle get subheading => GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: textDark,
      );

  static TextStyle get body => GoogleFonts.roboto(
        fontSize: 14,
        color: textDark,
      );

  static TextStyle get caption => GoogleFonts.roboto(
        fontSize: 12,
        color: textMuted,
      );

  static TextStyle get priceText => GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: cyanDark,
      );
}
