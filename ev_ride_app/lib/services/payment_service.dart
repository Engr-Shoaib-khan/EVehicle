import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';

class PaymentService {
  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(kTokenKey);
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── Get Wallet Details ─────────────────────────────────────────────
  Future<Map<String, dynamic>> getWalletDetails() async {
    try {
      final response = await http.get(
        Uri.parse('$kBaseUrl/api/payments/wallet'),
        headers: await _getHeaders(),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // ── Create Stripe Checkout Session ────────────────────────────────
  Future<Map<String, dynamic>> createStripeCheckoutSession(
      double amount) async {
    try {
      final response = await http.post(
        Uri.parse('$kBaseUrl/api/payments/wallet/topup-session'),
        headers: await _getHeaders(),
        body: jsonEncode({'amount': amount}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // ── Top Up Wallet (Manual/Internal) ───────────────────────────────
  Future<Map<String, dynamic>> topUpWallet(double amount) async {
    try {
      final response = await http.post(
        Uri.parse('$kBaseUrl/api/payments/wallet/topup'),
        headers: await _getHeaders(),
        body: jsonEncode({'amount': amount}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // ── Get Transactions ──────────────────────────────────────────────
  Future<Map<String, dynamic>> getTransactions() async {
    try {
      final response = await http.get(
        Uri.parse('$kBaseUrl/api/payments/wallet/transactions'),
        headers: await _getHeaders(),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // ── Complete Ride Payment ─────────────────────────────────────────
  Future<Map<String, dynamic>> completeRidePayment(String rideId) async {
    try {
      final response = await http.post(
        Uri.parse('$kBaseUrl/api/payments/ride/$rideId/complete'),
        headers: await _getHeaders(),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }
}
