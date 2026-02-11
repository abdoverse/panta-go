import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors
  static const Color primaryGreen = Color(0xFF0F5132); // Darker, richer green (Forest)
  static const Color primaryLight = Color(0xFF198754); // Vibrant interaction color
  static const Color accentLeaf = Color(0xFFD1E7DD); // Soft pastel green for backgrounds
  static const Color darkBackground = Color(0xFF1B1B1B);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color surfaceGrey = Color(0xFFFAFAFA); // Warmer/Lighter grey
  static const Color textPrimary = Color(0xFF212529); // Almost black
  static const Color textSecondary = Color(0xFF6C757D); // Muted grey

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryGreen,
        primary: primaryGreen,
        secondary: primaryLight,
        background: surfaceGrey,
        surface: surfaceWhite,
        error: const Color(0xFFDC3545),
        tertiary: const Color(0xFFE9F5EF), // Very light green for cards
      ),
      scaffoldBackgroundColor: surfaceGrey,
      textTheme: GoogleFonts.outfitTextTheme().copyWith( // Switching to Outfit for a more modern tech/clean look
        displayLarge: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: -1.5, color: textPrimary),
        displayMedium: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.5, color: textPrimary),
        titleLarge: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.1, color: textPrimary),
        bodyLarge: const TextStyle(color: textPrimary, letterSpacing: 0.2),
        bodyMedium: const TextStyle(color: textSecondary, letterSpacing: 0.1),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceGrey, // Transparent look
        scrolledUnderElevation: 0,
        centerTitle: false, // Align left for modern feel
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 24, // Larger title
          fontWeight: FontWeight.bold,
          fontFamily: 'Outfit', // Ensure font matches
          letterSpacing: -0.5,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          elevation: 4, // Subtle elevation
          shadowColor: primaryGreen.withOpacity(0.4),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryGreen,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          side: const BorderSide(color: primaryGreen, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0, // Zero default elevation for clean look
        color: surfaceWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFF0F0F0)), // Very subtle border
        ),
        margin: const EdgeInsets.only(bottom: 16),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFEEEEEE), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
           borderRadius: BorderRadius.circular(16),
           borderSide: const BorderSide(color: Color(0xFFF8D7DA)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        labelStyle: TextStyle(color: textSecondary.withOpacity(0.8)),
        floatingLabelStyle: const TextStyle(color: primaryGreen),
        hintStyle: TextStyle(color: textSecondary.withOpacity(0.5)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: primaryGreen.withOpacity(0.1),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: primaryGreen);
          }
           return const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: textSecondary);
        }),
        iconTheme: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
             return const IconThemeData(color: primaryGreen);
          }
          return const IconThemeData(color: textSecondary);
        }),
        elevation: 10,
        shadowColor: const Color(0x11000000), // Very slight shadow
      )
    );
  }
}
