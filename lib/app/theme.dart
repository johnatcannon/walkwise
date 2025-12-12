import 'package:flutter/material.dart';

/// WalkWise App Theme
/// 
/// Green color palette inspired by the WalkWise logo gradient:
/// - Darker teal-green (#007070) to lighter aqua-green (#00BBBB)
/// - Uses TimeBurner font family for consistent branding
class WalkWiseTheme {
  // Brand Colors (from WalkWise green logo)
  static const Color primaryGreen = Color(0xFF00A896); // Mid-range teal-green
  static const Color secondaryGreen = Color(0xFF02C39A); // Lighter accent green
  static const Color darkGreen = Color(0xFF007070); // Darker emphasis green
  static const Color lightGreen = Color(0xFF4ECDC4); // Very light green for backgrounds
  static const Color accentGreen = Color(0xFF00BBBB); // Aqua-green from logo gradient
  
  // Supporting Colors
  static const Color backgroundColor = Color(0xFFF5F5F5); // Light gray background
  static const Color cardColor = Color(0xFFFFFFFF); // White cards
  static const Color textColor = Color(0xFF212121); // Dark text
  static const Color textSecondaryColor = Color(0xFF757575); // Secondary text
  
  // Status Colors
  static const Color successColor = Color(0xFF4CAF50); // Green for success
  static const Color warningColor = Color(0xFFFFA726); // Orange for warnings
  static const Color errorColor = Color(0xFFF44336); // Red for errors
  
  /// TimeBurner font family name (matches assets/fonts/ in pubspec.yaml)
  static const String timeBurnerFont = 'TimeBurner';
  
  /// Main app theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryGreen,
        primary: primaryGreen,
        secondary: secondaryGreen,
        tertiary: darkGreen,
        brightness: Brightness.light,
      ),
      
      // Typography - TimeBurner for headings, system font for body
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: timeBurnerFont,
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
        displayMedium: TextStyle(
          fontFamily: timeBurnerFont,
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
        displaySmall: TextStyle(
          fontFamily: timeBurnerFont,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
        headlineLarge: TextStyle(
          fontFamily: timeBurnerFont,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
        headlineMedium: TextStyle(
          fontFamily: timeBurnerFont,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
        titleLarge: TextStyle(
          fontFamily: timeBurnerFont,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
        // Body text uses default system font for readability
        bodyLarge: TextStyle(
          fontSize: 16,
          color: textColor,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: textColor,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          color: textSecondaryColor,
        ),
      ),
      
      // App Bar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: timeBurnerFont,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      
      // Card Theme
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 2,
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      
      // Button Themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontFamily: timeBurnerFont,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryGreen,
          side: const BorderSide(color: primaryGreen, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontFamily: timeBurnerFont,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryGreen,
          textStyle: const TextStyle(
            fontFamily: timeBurnerFont,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryGreen, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      
      // Floating Action Button Theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: secondaryGreen,
        foregroundColor: Colors.white,
      ),
      
      // Progress Indicator Theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryGreen,
      ),
      
      // Scaffold Background
      scaffoldBackgroundColor: backgroundColor,
      
      // Drawer Theme
      drawerTheme: const DrawerThemeData(
        backgroundColor: Colors.white,
      ),
    );
  }
  
  /// Helper method to get a lighter shade of a color
  static Color lighten(Color color, [double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(color);
    final lightness = (hsl.lightness + amount).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  }
  
  /// Helper method to get a darker shade of a color
  static Color darken(Color color, [double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(color);
    final lightness = (hsl.lightness - amount).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  }
}

