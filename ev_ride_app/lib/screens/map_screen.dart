import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/socket_service.dart';

class MapScreen extends StatefulWidget {
  final String token;   
  const MapScreen({super.key, required this.token});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final SocketService _socketService = SocketService.instance;
  GoogleMapController? _mapController;
  LatLng _currentPos = const LatLng(24.8607, 67.0011);
  final Map<MarkerId, Marker> _markers = {};
  StreamSubscription? _locationSub;

  @override
  void initState() {
    super.initState();

    _determinePosition();

    _socketService.connect(token: widget.token);

    _locationSub = _socketService.onLocationUpdate.listen((data) {
      final coords = data['coordinates'] as List?;
      if (coords != null && coords.length >= 2 && mounted) {
        final newLocation = LatLng(coords[1].toDouble(), coords[0].toDouble());
        setState(() {
          _currentPos = newLocation;
          _updateMarker(newLocation, 'Live Tracking');
          _mapController?.animateCamera(CameraUpdate.newLatLng(newLocation));
        });
      }
    });
  }

  Future<void> _determinePosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

        setState(() {
          _currentPos = LatLng(position.latitude, position.longitude);
          _updateMarker(_currentPos, 'Meri Location');
        });

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_currentPos, 16.0),
      );
    } catch (e) {
      debugPrint('Location error: $e');
    }
  }

  void _updateMarker(LatLng pos, String title) {
    const markerId = MarkerId('driver_1');
    _markers[markerId] = Marker(
      markerId: markerId,
      position: pos,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      infoWindow: InfoWindow(title: title),
    );
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    // We don't necessarily want to disconnect the singleton here if other screens use it
    // _socketService.disconnect(); 
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EV Ride - Live Tracking'),
        backgroundColor: Colors.green.shade100,
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(target: _currentPos, zoom: 15.0),
        markers: Set<Marker>.of(_markers.values),
        myLocationEnabled: true,
        onMapCreated: (controller) => _mapController = controller,
      ),
    );
  }
}
