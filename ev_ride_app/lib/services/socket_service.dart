import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter/foundation.dart';
import '../core/constants.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  static SocketService get instance => _instance;

  io.Socket? _socket;
  
  // Stream Controllers
  final _rideTakenController    = StreamController<Map<String, dynamic>>.broadcast();
  final _locationController     = StreamController<Map<String, dynamic>>.broadcast();
  final _batteryController      = StreamController<Map<String, dynamic>>.broadcast();
  final _statusController       = StreamController<Map<String, dynamic>>.broadcast();
  final _sosController          = StreamController<Map<String, dynamic>>.broadcast();
  final _rideRequestController  = StreamController<Map<String, dynamic>>.broadcast();
  
  // Streams
  Stream<Map<String, dynamic>> get onRideTaken        => _rideTakenController.stream;
  Stream<Map<String, dynamic>> get onLocationUpdate   => _locationController.stream;
  Stream<Map<String, dynamic>> get onBatteryUpdate    => _batteryController.stream;
  Stream<Map<String, dynamic>> get onRideStatusUpdate => _statusController.stream;
  Stream<Map<String, dynamic>> get onSosAlert         => _sosController.stream;
  Stream<Map<String, dynamic>> get onNewRideRequest   => _rideRequestController.stream;

  SocketService._internal();

  /// Initialize and connect to the socket server
  Future<void> connect({String? token}) async {
    if (_socket?.connected ?? false) return;

    _socket = io.io(kBaseUrl, 
      io.OptionBuilder()
        .setTransports(['websocket'])
        .setAuth({'token': token})
        .enableAutoConnect()
        .build()
    );

    _socket!.onConnect((_) {
      debugPrint('[SOCKET] Connected to server');
    });

    _socket!.onDisconnect((reason) {
      debugPrint('[SOCKET] Disconnected: $reason');
    });

    // Listen for events
    _socket!.on('ride_taken', (data) => _rideTakenController.add(Map<String, dynamic>.from(data)));
    _socket!.on('driver:location_update', (data) => _locationController.add(Map<String, dynamic>.from(data)));
    _socket!.on('driver:battery_update', (data) => _batteryController.add(Map<String, dynamic>.from(data)));
    _socket!.on('ride_status_update', (data) => _statusController.add(Map<String, dynamic>.from(data)));
    _socket!.on('sos_alert', (data) => _sosController.add(Map<String, dynamic>.from(data)));
    _socket!.on('new_ride_request', (data) => _rideRequestController.add(Map<String, dynamic>.from(data)));

    _socket!.onConnectError((err) => debugPrint('[SOCKET] Connect Error: $err'));
    _socket!.onError((err) => debugPrint('[SOCKET] Error: $err'));
  }

  void emit(String event, dynamic data) {
    _socket?.emit(event, data);
  }

  void goOnline(List<double> coordinates) {
    _socket?.emit('driver:go_online', {'coordinates': coordinates});
  }

  void goOffline() {
    _socket?.emit('driver:go_offline');
  }

  void updateLocation(List<double> coordinates, {String? rideId}) {
    _socket?.emit('driver:update_location', {
      'coordinates': coordinates,
      'rideId': rideId,
    });
  }

  void updateBattery(double soc) {
    _socket?.emit('driver:update_battery', {'soc': soc});
  }

  void triggerSos({required String rideId}) {
    _socket?.emit('ride:sos', {'rideId': rideId});
  }

  void shareLiveLocation(String rideId) {
    _socket?.emit('ride:share_location', {'rideId': rideId});
  }

  void joinRideRoom(String rideId) {
    _socket?.emit('join_ride_room', {'rideId': rideId});
  }

  void leaveRideRoom(String rideId) {
    _socket?.emit('leave_ride_room', {'rideId': rideId});
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }

  void dispose() {
    _rideTakenController.close();
    _locationController.close();
    _batteryController.close();
    _statusController.close();
    _sosController.close();
    _rideRequestController.close();
    _socket?.dispose();
  }
}
