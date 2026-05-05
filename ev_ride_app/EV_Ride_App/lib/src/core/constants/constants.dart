import 'package:flutter/material.dart';

// API & Maps Configuration
const String kGoogleMapsKey =
    String.fromEnvironment('GOOGLE_MAPS_KEY', defaultValue: '');

// Is line ko update karein: 10.0.2.2 sirf emulator ke liye hota hai
const String kBaseUrl = "http://192.168.100.2:5000";

// App Colors
const Color kGreen = Color(0xFF22C55E);
const Color kGreenDark = Color(0xFF166534);
const Color kGreenLight = Color(0xFFDCFCE7);
const Color kBgColor = Color(0xFFF7F9FC);

// Auth Keys
const String kTokenKey = "auth_token";
const String kUserKey = "user_data";

// Text Styles
const TextStyle kHeaderStyle = TextStyle(
  fontSize: 18.0,
  fontWeight: FontWeight.bold,
  color: Color(0xFF0D1B2A),
);
