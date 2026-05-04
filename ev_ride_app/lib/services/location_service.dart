import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart'; // kIsWeb ke liye

class LocationService {
  /// User se permission mangna aur current location nikalna
  Future<Position> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw 'Location services are disabled. Please turn on GPS.';
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw 'Location permission denied. Please allow access in settings.';
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      throw 'Location permission permanently denied. Please enable it in app settings.';
    }

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );
  }

  /// Latitude/Longitude ko address mein badalna (Web safe)
  Future<String> getAddressFromCoords(double lat, double lng) async {
    if (kIsWeb) return "Saddar, Karachi (Web Preview)"; // Chrome par geocoding nahi chalti
    
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return 'Unknown location';
      final p = placemarks.first;
      
      final parts = [
        p.street,
        p.subLocality,
        p.locality,
      ].where((s) => s != null && s.isNotEmpty).toList();
      
      return parts.take(2).join(', ');
    } catch (_) {
      return 'Current Location';
    }
  }

  /// Do points ke darmiyan distance nikalna (Kilometers mein)
  double calculateDistance(double startLat, double startLng, double endLat, double endLng) {
    double distanceInMeters = Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
    return distanceInMeters / 1000; // Meters ko KM mein badalna
  }

  /// Live tracking stream (Drivers ke liye)
  Stream<Position> positionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
      ),
    );
  }
}