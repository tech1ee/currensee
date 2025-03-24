import 'package:flutter/material.dart';

class ThemeConstants {
  // Main colors - more subdued and minimalistic palette
  static const Color _primaryLight = Color(0xFF7A9E9F); // Muted teal
  static const Color _primaryDark = Color(0xFF5D7F80);  // Darker muted teal
  static const Color _accentLight = Color(0xFFC2C5AA); // Soft sage
  static const Color _accentDark = Color(0xFFA3A88C);  // Darker sage
  
  // Background colors - softer and easier on the eyes
  static const Color _backgroundLight = Color(0xFFF8F8F6); // Off-white
  static const Color _backgroundDark = Color(0xFF1D2327);  // Dark slate
  static const Color _surfaceLight = Color(0xFFFFFFFF);    // Pure white
  static const Color _surfaceDark = Color(0xFF252A30);     // Dark charcoal
  
  // Text colors - better contrast and readability
  static const Color _textPrimaryLight = Color(0xFF2E3538); // Almost black
  static const Color _textSecondaryLight = Color(0xFF5F6B70); // Medium gray
  static const Color _textPrimaryDark = Color(0xFFE8E9EA);    // Almost white
  static const Color _textSecondaryDark = Color(0xFFADB5BD);  // Light gray

  // Light Theme
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary: _primaryLight,
      onPrimary: Colors.white,
      secondary: _accentLight,
      onSecondary: _textPrimaryLight,
      tertiary: Color(0xFFB09398),       // Soft mauve as a subtle accent
      background: _backgroundLight,
      onBackground: _textPrimaryLight,
      surface: _surfaceLight,
      onSurface: _textPrimaryLight,
      surfaceVariant: Color(0xFFF0F0ED), // Slightly darker for cards
      outline: Color(0xFFDCDCD5),        // Subtle border color
    ),
    scaffoldBackgroundColor: _backgroundLight,
    dividerColor: Color(0xFFE5E5E0),
    appBarTheme: AppBarTheme(
      backgroundColor: _backgroundLight,
      foregroundColor: _textPrimaryLight,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardTheme(
      color: _surfaceLight,
      surfaceTintColor: Colors.transparent,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    textTheme: TextTheme(
      headlineMedium: TextStyle(
        color: _textPrimaryLight,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: TextStyle(
        color: _textPrimaryLight,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(
        color: _textPrimaryLight,
      ),
      bodyMedium: TextStyle(
        color: _textSecondaryLight,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Color(0xFFF5F5F2),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _primaryLight),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryLight,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    iconTheme: IconThemeData(
      color: _primaryLight,
    ),
  );

  // Dark Theme
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: _primaryDark,
      onPrimary: Colors.white,
      secondary: _accentDark,
      onSecondary: _textPrimaryDark,
      tertiary: Color(0xFF8A7175),       // Darker mauve as a subtle accent
      background: _backgroundDark,
      onBackground: _textPrimaryDark,
      surface: _surfaceDark,
      onSurface: _textPrimaryDark,
      surfaceVariant: Color(0xFF2A3035), // Slightly lighter for cards
      outline: Color(0xFF3F454C),        // Subtle border color
    ),
    scaffoldBackgroundColor: _backgroundDark,
    dividerColor: Color(0xFF333840),
    appBarTheme: AppBarTheme(
      backgroundColor: _backgroundDark,
      foregroundColor: _textPrimaryDark,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardTheme(
      color: _surfaceDark,
      surfaceTintColor: Colors.transparent,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    textTheme: TextTheme(
      headlineMedium: TextStyle(
        color: _textPrimaryDark,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: TextStyle(
        color: _textPrimaryDark,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(
        color: _textPrimaryDark,
      ),
      bodyMedium: TextStyle(
        color: _textSecondaryDark,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Color(0xFF202529),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _primaryDark),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    iconTheme: IconThemeData(
      color: _primaryDark,
    ),
  );
} 