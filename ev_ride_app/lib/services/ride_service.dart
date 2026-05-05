import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';

class RideService {
  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(kTokenKey);
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── Request Ride ──────────────────────────────────────────────────
  Future<Map<String, dynamic>> requestRide({
    required List<double> pickupCoordinates,
    required String pickupAddress,
    required List<double> dropoffCoordinates,
    required String dropoffAddress,
    String paymentMethod = 'cash',
    String vehicleTypeId = 'ev_bike',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$kBaseUrl/api/rides/request'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'pickupCoordinates': pickupCoordinates,
          'pickupAddress': pickupAddress,
          'dropoffCoordinates': dropoffCoordinates,
          'dropoffAddress': dropoffAddress,
          'paymentMethod': paymentMethod,
          'vehicleTypeId': vehicleTypeId,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // ── Accept Ride (Driver) ──────────────────────────────────────────
  Future<Map<String, dynamic>> acceptRide(String rideId) async {
    try {
      final response = await http.post(
        Uri.parse('$kBaseUrl/api/rides/$rideId/accept'),
        headers: await _getHeaders(),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // ── Update Ride Status (Driver) ────────────────────────────────────
  Future<Map<String, dynamic>> updateRideStatus(
      String rideId, String newStatus) async {
    try {
      final response = await http.patch(
        Uri.parse('$kBaseUrl/api/rides/$rideId/status'),
        headers: await _getHeaders(),
        body: jsonEncode({'newStatus': newStatus}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // ── Cancel Ride (Rider) ───────────────────────────────────────────
  Future<Map<String, dynamic>> cancelRide(String rideId, String reason) async {
    try {
      final response = await http.delete(
        Uri.parse('$kBaseUrl/api/rides/$rideId/cancel'),
        headers: await _getHeaders(),
        body: jsonEncode({'reason': reason}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // ── Get Ride History ──────────────────────────────────────────────
  Future<Map<String, dynamic>> getRideHistory(
      {int page = 1, int limit = 20}) async {
    try {
      final response = await http.get(
        Uri.parse('$kBaseUrl/api/rides/history/me?page=$page&limit=$limit'),
        headers: await _getHeaders(),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // ── Get Ride Details ─────────────────────────────────────────────
  Future<Map<String, dynamic>> getRideDetails(String rideId) async {
    try {
      final response = await http.get(
        Uri.parse('$kBaseUrl/api/rides/$rideId'),
        headers: await _getHeaders(),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }
}
