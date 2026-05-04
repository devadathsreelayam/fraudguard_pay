import 'package:flutter/material.dart';

const primaryDark = Color(0xFF0A1C3A);
const secondaryDark = Color(0xFF1E3A6F);
const accentOrange = Color(0xFFF5821F);
const textPrimary = Color(0xFFF0F4FA);
const textSecondary = Color(0xFFA0B8D4);
const borderColor = Color(0xFF2A4070);
const cardBg = Color(0xFF122B4A);

class AppTheme {
  static ThemeData darkTheme = ThemeData(
    scaffoldBackgroundColor: primaryDark,
    primaryColor: secondaryDark,
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryDark,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      iconTheme: IconThemeData(color: textPrimary),
    ),
    colorScheme: const ColorScheme.dark(
      primary: accentOrange,
      secondary: accentOrange,
      surface: cardBg,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      labelStyle: TextStyle(color: textSecondary),
      hintStyle: TextStyle(color: textSecondary),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: accentOrange),
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: textPrimary),
      bodyMedium: TextStyle(color: textSecondary),
    ),
  );
}
