import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tema único do app (issue #60).
///
/// Todos os tokens de cor nomeados vivem aqui; screens não usam hex inline.
/// Os tokens `*Deep`, `text*`, `ok/warn/danger/info` formam a variante
/// `fieldHighContrast`: pensados para sol direto, mantêm contraste ≥ 4.5:1
/// (WCAG AA texto) sobre [background] e [surface] — verificado em
/// `test/theme/jalapao_theme_contrast_test.dart`.
class JalapaoTheme {
  JalapaoTheme._();

  // ── Superfícies ──────────────────────────────────────
  static const Color background = Color(0xFFFBE9E7); // Terra Suave
  static const Color surface = Color(0xFFFFFFFF); // cartões sobre terra
  static const Color surfaceMuted = Color(0xFFF3E0DC); // faixas/badges neutros
  static const Color outline = Color(0xFF8D6E63); // bordas (≥3:1 sobre terra)

  // ── Marca (preenchimentos) ───────────────────────────
  static const Color primary = Color(0xFFD87D4A); // Laranja Cerrado
  static const Color secondary = Color(0xFF00ACC1); // Azul Fervedouro
  static const Color accent = Color(0xFFFBC02D); // Capim Dourado

  // ── Marca em alto contraste (texto/ícone/CTA) ────────
  static const Color primaryDeep = Color(0xFF9C4A1E);
  static const Color secondaryDeep = Color(0xFF006064);
  static const Color accentDeep = Color(0xFF7A5A00);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // ── Texto ────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF3E2723); // Marrom Café
  static const Color textMuted = Color(0xFF5D4037);
  static const Color textFaint = Color(0xFF795548);

  /// Alias histórico de [textPrimary]; preservado para não quebrar imports.
  static const Color textSync = textPrimary;

  // ── Estados (semáforo de campo) ──────────────────────
  static const Color ok = Color(0xFF1B5E20);
  static const Color warn = Color(0xFF8D4E00);
  static const Color danger = Color(0xFFB71C1C);
  static const Color info = Color(0xFF0D47A1);

  /// Alias histórico de [danger].
  static const Color error = danger;

  // ── Cartões do fervedouro ────────────────────────────
  static const Color cardQueue = Color(0xFFFFCCBC); // Adobe
  static const Color cardWater = Color(0xFFB2EBF2); // Turquesa Claro

  /// Alvo mínimo de toque em campo (Material: 48dp).
  static const double minTouch = 48;

  /// Cor de estado por razão ocupação/capacidade.
  static Color occupancyColor(int occupancy, int capacity) {
    if (capacity <= 0) return info;
    final ratio = occupancy / capacity;
    if (ratio >= 1.0) return danger;
    if (ratio >= 0.8) return warn;
    return ok;
  }

  /// Variante de alto contraste: alias explícito do tema único.
  static ThemeData get fieldHighContrast => themeData;

  static ThemeData get themeData {
    final textTheme = TextTheme(
      displayLarge: GoogleFonts.outfit(
        color: textPrimary,
        fontWeight: FontWeight.bold,
        fontSize: 32,
      ),
      displayMedium: GoogleFonts.outfit(
        color: textPrimary,
        fontWeight: FontWeight.bold,
        fontSize: 24,
      ),
      displaySmall: GoogleFonts.outfit(color: textPrimary),
      headlineLarge: GoogleFonts.outfit(color: textPrimary),
      headlineMedium: GoogleFonts.outfit(color: textPrimary),
      headlineSmall: GoogleFonts.outfit(color: textPrimary),
      titleLarge: GoogleFonts.outfit(color: textPrimary),
      titleMedium: GoogleFonts.outfit(color: textPrimary),
      titleSmall: GoogleFonts.outfit(color: textPrimary),
      bodyLarge: GoogleFonts.outfit(color: textPrimary, fontSize: 18),
      bodyMedium: GoogleFonts.outfit(color: textPrimary, fontSize: 16),
      bodySmall: GoogleFonts.outfit(color: textMuted),
      labelLarge: GoogleFonts.outfit(
        color: textPrimary,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: GoogleFonts.outfit(color: textMuted),
      labelSmall: GoogleFonts.outfit(color: textMuted),
    );

    return ThemeData(
      useMaterial3: true,
      // Tablet em campo: nunca densidade compacta — alvos ≥ 48dp.
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primaryDeep,
        onPrimary: onPrimary,
        secondary: secondaryDeep,
        onSecondary: onPrimary,
        error: danger,
        surface: surface,
        onSurface: textPrimary,
        outline: outline,
      ),
      textTheme: textTheme,
      iconTheme: const IconThemeData(color: textPrimary, size: 24),
      dividerColor: outline.withValues(alpha: 0.4),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        shadowColor: textPrimary.withValues(alpha: 0.1),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryDeep,
        foregroundColor: onPrimary,
        elevation: 0,
        toolbarHeight: 56,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: onPrimary,
        unselectedLabelColor: Color(0xDDFFFFFF),
        indicatorColor: onPrimary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryDeep,
          foregroundColor: onPrimary,
          minimumSize: const Size(minTouch, minTouch),
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
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryDeep,
          minimumSize: const Size(minTouch, minTouch),
          side: const BorderSide(color: primaryDeep, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryDeep,
          minimumSize: const Size(minTouch, minTouch),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: textPrimary,
          minimumSize: const Size(minTouch, minTouch),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryDeep,
        foregroundColor: onPrimary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        labelStyle: const TextStyle(color: textMuted),
        hintStyle: const TextStyle(color: textFaint),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: outline, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: outline, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryDeep, width: 2.5),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: textTheme.displayMedium,
        contentTextStyle: textTheme.bodyMedium,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        textStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: textPrimary,
        contentTextStyle: TextStyle(color: onPrimary, fontSize: 15),
        behavior: SnackBarBehavior.floating,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceMuted,
        labelStyle: const TextStyle(color: textPrimary),
        side: const BorderSide(color: outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryDeep,
      ),
    );
  }
}
