import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class JalapaoTheme {
  static const Color primaryColor = Color(0xFF00B050);  // Verde Jalapão
  static const Color secondaryColor = Color(0xFF0070C0); // Azul
  static const Color backgroundColor = Color(0xFFF5F5F5);

  // ── Colors ───────────────────────────────────────────
  static const Color background = Color(0xFFFBE9E7); // Terra Suave
  static const Color primary = Color(0xFFD87D4A);    // Laranja Cerrado
  static const Color secondary = Color(0xFF00ACC1);  // Azul Fervedouro
  static const Color accent = Color(0xFFFBC02D);     // Capim Dourado
  static const Color textSync = Color(0xFF3E2723);   // Marrom Café
  static const Color error = Color(0xFFD32F2F);      // Vermelho Arara
  
  // Card Backgrounds
  static const Color cardQueue = Color(0xFFFFCCBC);  // Creme mais escuro (Adobe)
  static const Color cardWater = Color(0xFFB2EBF2);  // Azul Turquesa Claro

  // ── Theme Data ───────────────────────────────────────
  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        background: background,
        primary: primary,
        secondary: secondary,
        error: error,
        surface: cardQueue, 
      ),
      
      // Text Theme
      textTheme: GoogleFonts.outfitTextTheme().copyWith(
        displayLarge: GoogleFonts.outfit(
          color: textSync,
          fontWeight: FontWeight.bold,
          fontSize: 32,
        ),
        displayMedium: GoogleFonts.outfit(
          color: textSync,
          fontWeight: FontWeight.bold,
          fontSize: 24,
        ),
        bodyLarge: GoogleFonts.outfit(
          color: textSync,
          fontSize: 18,
        ),
        bodyMedium: GoogleFonts.outfit(
          color: textSync,
          fontSize: 16,
        ),
        labelLarge: GoogleFonts.outfit(
          color: textSync,
          fontWeight: FontWeight.w600,
        ),
      ),

      // Card Theme
      // Card Theme
      cardTheme: CardThemeData(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        shadowColor: textSync.withOpacity(0.1),
      ),

      // Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      
      // Icon Theme
      iconTheme: const IconThemeData(
        color: textSync,
        size: 24,
      ),
    );
  }
}
