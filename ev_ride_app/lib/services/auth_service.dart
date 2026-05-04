import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../core/constants.dart';

// ── Response wrapper ───────────────────────────────────────────────
class AuthResult {
  final bool success;
  final String message;
  final String? token;
  final Map<String, dynamic>? user;
  final String? email;        // returned on register for OTP screen pre-fill
  final bool requiresOtp;    // returned on login-before-verify

  const AuthResult({
    required this.success,
    required this.message,
    this.token,
    this.user,
    this.email,
    this.requiresOtp = false,
  });
}

class AuthService {
  // ── Register ─────────────────────────────────────────────────────
  Future<AuthResult> register({
    required String fullName,
    required String email,
    required String password,
    required String phoneNumber,
    required String role, // 'rider' | 'driver'
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$kBaseUrl/api/auth/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'fullName':    fullName,
              'email':       email,
              'password':    password,
              'phoneNumber': phoneNumber,
              'role':        role,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      return AuthResult(
        success: data['success'] == true,
        message: data['message'] ?? 'Unknown error',
        email:   data['email'],
      );
    } catch (e) {
      return AuthResult(success: false, message: 'Connection error: $e');
    }
  }

  // ── Verify OTP ───────────────────────────────────────────────────
  Future<AuthResult> verifyOtp({
    required String email,
    required String otp,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$kBaseUrl/api/auth/verify-otp'), // 🔥 Updated Link
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'otp': otp}),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      if (data['success'] == true && data['token'] != null) {
        await _saveSession(data['token'], data['user']);
      }

      return AuthResult(
        success: data['success'] == true,
        message: data['message'] ?? 'Unknown error',
        token:   data['token'],
        user:    data['user'],
      );
    } catch (e) {
      return AuthResult(success: false, message: 'Connection error: $e');
    }
  }

  // ── Login ────────────────────────────────────────────────────────
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$kBaseUrl/api/auth/login'), // 🔥 Updated Link
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (data['success'] == true && data['token'] != null) {
        await _saveSession(data['token'], data['user']);
      }

      return AuthResult(
        success:     data['success'] == true,
        message:     data['message'] ?? 'Unknown error',
        token:       data['token'],
        user:        data['user'],
        email:       data['email'],
        requiresOtp: data['requiresOtp'] == true,
      );
    } catch (e) {
      return AuthResult(success: false, message: 'Connection error: $e');
    }
  }

  // ── Resend OTP ───────────────────────────────────────────────────
  Future<AuthResult> resendOtp({required String email}) async {
    try {
      final response = await http
          .post(
            Uri.parse('$kBaseUrl/api/auth/resend-otp'), // 🔥 Updated Link
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email}),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      return AuthResult(
        success: data['success'] == true,
        message: data['message'] ?? 'Unknown error',
      );
    } catch (e) {
      return AuthResult(success: false, message: 'Connection error: $e');
    }
  }

  // ── Logout ───────────────────────────────────────────────────────
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kTokenKey);
    await prefs.remove(kUserKey);
  }

  // ── Check if logged in ───────────────────────────────────────────
  Future<String?> getSavedToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(kTokenKey);
  }

  // ── Private: Persist session ─────────────────────────────────────
  Future<void> _saveSession(String token, Map<String, dynamic>? user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kTokenKey, token);
    if (user != null) {
      await prefs.setString(kUserKey, jsonEncode(user));
    }
  }
}