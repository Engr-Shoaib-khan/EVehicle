import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ── API ───────────────────────────────────────────────────────────
// Use your machine's local IP for physical devices.
const String _myIP = '192.168.1.5'; 
final String kBaseUrl = kIsWeb 
    ? 'http://localhost:5000' 
    : (defaultTargetPlatform == TargetPlatform.android ? 'http://10.0.2.2:5000' : 'http://$_myIP:5000');

// ── Brand Colors ──────────────────────────────────────────────────
const Color kGreen        = Color(0xFF00C853);
const Color kGreenDark    = Color(0xFF00897B);
const Color kGreenLight   = Color(0xFFE8F5E9);
const Color kBg           = Color(0xFFFFFFFF);
const Color kSurface      = Color(0xFFF7F9FC);
const Color kTextPrimary  = Color(0xFF0D1B2A);
const Color kTextSecondary= Color(0xFF6B7280);
const Color kBorder       = Color(0xFFE5E7EB);
const Color kError        = Color(0xFFEF4444);

// ── Shared Prefs Keys ─────────────────────────────────────────────
const String kTokenKey    = 'auth_token';
const String kUserKey     = 'auth_user';

// ── App Theme ─────────────────────────────────────────────────────
ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: kGreen,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: kBg,
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: kBg,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: kTextPrimary),
      titleTextStyle: TextStyle(
        color: kTextPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kGreen, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kError),
      ),
      hintStyle: const TextStyle(color: kTextSecondary, fontSize: 14),
      labelStyle: const TextStyle(color: kTextSecondary),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kTextPrimary,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: kBorder, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
    ),
  );
}
