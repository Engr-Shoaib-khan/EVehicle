import 'package:google_maps_flutter/google_maps_flutter.dart';

// ── Driver Info Model ───────────────────────────────────────────
class DriverInfo {
  final String id;
  final String fullName;
  final String? phone;
  final String? avatarUrl;
  final double rating;
  final String vehicleMake;
  final String vehicleModel;
  final String plateNumber;
  final String vehicleColor;
  final LatLng location;

  DriverInfo({
    required this.id,
    required this.fullName,
    this.phone,
    this.avatarUrl,
    this.rating = 0.0,
    required this.vehicleMake,
    required this.vehicleModel,
    required this.plateNumber,
    required this.vehicleColor,
    this.location = const LatLng(0, 0),
  });
}

// ── Ride Status Enum ─────────────────────────────────────────────
enum RideStatus {
  idle,
  searching,
  driverAssigned,
  inProgress,
  completed,
  cancelled
}

// ── Ride State Model ─────────────────────────────────────────────
class RideState {
  final String? rideId;
  final RideStatus status;
  final Map<String, dynamic>? driverInfo;
  final double? driverLat;
  final double? driverLng;

  RideState({
    this.rideId,
    this.status = RideStatus.idle,
    this.driverInfo,
    this.driverLat,
    this.driverLng,
  });

  RideState copyWith({
    String? rideId,
    RideStatus? status,
    Map<String, dynamic>? driverInfo,
    double? driverLat,
    double? driverLng,
  }) {
    return RideState(
      rideId: rideId ?? this.rideId,
      status: status ?? this.status,
      driverInfo: driverInfo ?? this.driverInfo,
      driverLat: driverLat ?? this.driverLat,
      driverLng: driverLng ?? this.driverLng,
    );
  }
}
