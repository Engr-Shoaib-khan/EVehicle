import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/constants/constants.dart';

class RideNavigationScreen extends StatefulWidget {
  final Map<String, dynamic> rideData;
  const RideNavigationScreen({super.key, required this.rideData});

  @override
  State<RideNavigationScreen> createState() => _RideNavigationScreenState();
}

class _RideNavigationScreenState extends State<RideNavigationScreen> {
  final Completer<GoogleMapController> _controller = Completer();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(widget.rideData['pickup']['lat'], widget.rideData['pickup']['lng']),
              zoom: 14,
            ),
            onMapCreated: (GoogleMapController controller) => _controller.complete(controller),
            myLocationEnabled: true,
          ),
          Positioned(
            bottom: 20, left: 20, right: 20,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Text("Customer: ${widget.rideData['userName']}", style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          )
        ],
      ),
    );
  }
}