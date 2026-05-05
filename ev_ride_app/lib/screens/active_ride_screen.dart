import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../core/constants.dart';
import '../models/ride_state.dart';
import '../services/socket_service.dart';
import '../services/ride_service.dart';
import 'rating_screen.dart';

// ── Map style ─────────────────────────────────────────────────────
const String _kStyle =
    '[{"featureType":"poi","elementType":"labels","stylers":[{"visibility":"off"}]},{"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]},{"featureType":"water","elementType":"geometry","stylers":[{"color":"#c9e8f0"}]},{"featureType":"landscape","elementType":"geometry","stylers":[{"color":"#f0f4f0"}]}]';

// ── Ride lifecycle for driver-side buttons ─────────────────────────
enum _DriverStep { heading, arrived, inProgress, completed }

class ActiveRideScreen extends StatefulWidget {
  final String rideId;
  final DriverInfo? driver;
  final String? pickupAddress;
  final String? dropoffAddress;
  final String? vehicleName;
  final int? estimatedFare;
  final bool isDriverMode; // true = driver sees action buttons

  const ActiveRideScreen({
    super.key,
    required this.rideId,
    this.driver,
    this.pickupAddress,
    this.dropoffAddress,
    this.vehicleName,
    this.estimatedFare,
    this.isDriverMode = false,
  });

  @override
  State<ActiveRideScreen> createState() => _ActiveRideScreenState();
}

class _ActiveRideScreenState extends State<ActiveRideScreen>
    with TickerProviderStateMixin {
  final RideService _rideService = RideService();
  GoogleMapController? _mapCtrl;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  LatLng? _driverPos;
  double _soc = 100.0;
  String _statusMsg = 'Driver is on the way...';

  _DriverStep _driverStep = _DriverStep.heading;
  bool _actionLoading = false;

  late final AnimationController _pulseCtrl;
  late final List<StreamSubscription> _subs;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);

    SocketService.instance.joinRideRoom(widget.rideId);
    _subs = [
      SocketService.instance.onLocationUpdate.listen(_onLocation),
      SocketService.instance.onBatteryUpdate.listen(_onBattery),
      SocketService.instance.onRideStatusUpdate.listen(_onStatus),
      SocketService.instance.onSosAlert.listen(_onSos),
    ];

    if (widget.driver != null &&
        widget.driver!.location != const LatLng(0, 0)) {
      _driverPos = widget.driver!.location;
      _placeDriverMarker(_driverPos!);
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    SocketService.instance.leaveRideRoom(widget.rideId);
    for (final s in _subs) {
      s.cancel();
    }
    _mapCtrl?.dispose();
    super.dispose();
  }

  // ── Socket callbacks ──────────────────────────────────────────
  void _onLocation(Map<String, dynamic> d) {
    final c = d['coordinates'] as List<dynamic>?;
    if (c == null || c.length < 2) return;
    final ll = LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());
    setState(() => _driverPos = ll);
    _placeDriverMarker(ll);
    _mapCtrl?.animateCamera(CameraUpdate.newLatLng(ll));
    final soc = d['batterySoc'];
    if (soc != null) {
      setState(() => _soc = (soc as num).toDouble());
    }
  }

  void _onBattery(Map<String, dynamic> d) {
    final soc = d['soc'];
    if (soc != null && mounted) {
      setState(() => _soc = (soc as num).toDouble());
    }
  }

  void _onStatus(Map<String, dynamic> d) {
    final status = d['newStatus'] as String? ?? '';
    if (!mounted) return;
    setState(() => _statusMsg = d['message'] as String? ?? status);
    if (status == 'completed' && !widget.isDriverMode) _goToRating();
    if (status == 'driver_arrived') {
      setState(() => _driverStep = _DriverStep.arrived);
    }
    if (status == 'in_progress') {
      setState(() => _driverStep = _DriverStep.inProgress);
    }
    if (status == 'completed') {
      setState(() => _driverStep = _DriverStep.completed);
    }
  }

  void _onSos(Map<String, dynamic> d) {
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              backgroundColor: const Color(0xFFFEF2F2),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18.0)),
              title: const Row(children: [
                Icon(Icons.warning_rounded, color: Color(0xFFEF4444)),
                SizedBox(width: 8.0),
                Text('SOS Alert',
                    style: TextStyle(
                        color: Color(0xFFEF4444), fontWeight: FontWeight.w700)),
              ]),
              content:
                  Text(d['message'] as String? ?? 'Emergency alert triggered.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'))
              ],
            ));
  }

  // ── Driver step transitions ───────────────────────────────────
  Future<void> _advanceStep() async {
    setState(() => _actionLoading = true);
    try {
      String newStatus = '';
      String msg = '';
      switch (_driverStep) {
        case _DriverStep.heading:
          newStatus = 'driver_arrived';
          msg = 'You have arrived at the pickup location!';
          break;
        case _DriverStep.arrived:
          newStatus = 'in_progress';
          msg = 'Your trip has started!';
          break;
        case _DriverStep.inProgress:
          newStatus = 'completed';
          msg = 'Trip completed!';
          break;
        default:
          return;
      }
      // Call REST API to update status
      final result =
          await _rideService.updateRideStatus(widget.rideId, newStatus);

      if (result['success'] == true) {
        setState(() => _statusMsg = msg);
        if (newStatus == 'completed') {
          setState(() => _driverStep = _DriverStep.completed);
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) _goToRating();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(result['message'] ?? 'Failed to update status')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  void _goToRating() {
    if (widget.driver == null) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => RatingScreen(
            rideId: widget.rideId,
            driverName: widget.driver!.fullName,
          ),
        ));
  }

  // ── Map helpers ───────────────────────────────────────────────
  void _placeDriverMarker(LatLng pos) {
    if (widget.driver == null) return;
    _markers.removeWhere((m) => m.markerId == const MarkerId('driver'));
    _markers.add(Marker(
      markerId: const MarkerId('driver'),
      position: pos,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
      infoWindow: InfoWindow(title: widget.driver!.fullName),
    ));
    if (mounted) setState(() {});
  }

  // ── SOS ───────────────────────────────────────────────────────
  void _triggerSos() {
    HapticFeedback.heavyImpact();
    SocketService.instance.triggerSos(rideId: widget.rideId);
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18.0)),
              title: const Text('Emergency',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: Color(0xFFEF4444))),
              content: const Text('Choose an emergency action:'),
              actions: [
                TextButton.icon(
                  icon: const Icon(Icons.call, color: Color(0xFFEF4444)),
                  label: const Text('Call Police (15)',
                      style: TextStyle(
                          color: Color(0xFFEF4444),
                          fontWeight: FontWeight.w700)),
                  onPressed: () {
                    Navigator.pop(context);
                    _showSnack('Dialling 15 — Police Emergency');
                  },
                ),
                TextButton.icon(
                  icon: const Icon(Icons.share_location_rounded),
                  label: const Text('Share Live Location'),
                  onPressed: () {
                    Navigator.pop(context);
                    SocketService.instance.shareLiveLocation(widget.rideId);
                    _showSnack('Live location shared with emergency contacts');
                  },
                ),
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
              ],
            ));
  }

  // ── Driver step config ────────────────────────────────────────
  Map<String, dynamic> get _stepConfig {
    switch (_driverStep) {
      case _DriverStep.heading:
        return {
          'label': 'I Have Arrived',
          'icon': Icons.location_on_rounded,
          'color': const Color(0xFF1565C0)
        };
      case _DriverStep.arrived:
        return {
          'label': 'Start Trip',
          'icon': Icons.play_arrow_rounded,
          'color': kGreen
        };
      case _DriverStep.inProgress:
        return {
          'label': 'End Trip',
          'icon': Icons.flag_rounded,
          'color': const Color(0xFFEF4444)
        };
      default:
        return {
          'label': 'Completed',
          'icon': Icons.check_rounded,
          'color': kGreen
        };
    }
  }

  Color get _socColor {
    if (_soc > 40) return kGreen;
    if (_soc > 15) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? const Color(0xFFEF4444) : kGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final initial = _driverPos ?? const LatLng(24.8607, 67.0011);
    final cfg = _stepConfig;
    final isDone = _driverStep == _DriverStep.completed;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(children: [
        // ── MAP ────────────────────────────────────────────────
        GoogleMap(
          initialCameraPosition: CameraPosition(target: initial, zoom: 15.0),
          style: _kStyle,
          markers: _markers,
          polylines: _polylines,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          onMapCreated: (ctrl) {
            _mapCtrl = ctrl;
          },
        ),

        // ── BOTTOM CARD ────────────────────────────────────────
        Align(
          alignment: Alignment.bottomCenter,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420.0),
              child: Container(
                margin: const EdgeInsets.all(14.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24.0),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.13),
                        blurRadius: 24.0,
                        offset: const Offset(0, -4))
                  ],
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // Status banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                    decoration: BoxDecoration(
                      color: isDone ? kGreen : const Color(0xFF1565C0),
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24.0)),
                    ),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                              isDone
                                  ? Icons.check_circle_rounded
                                  : Icons.bolt_rounded,
                              color: Colors.white,
                              size: 16.0),
                          const SizedBox(width: 6.0),
                          Flexible(
                              child: Text(_statusMsg,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13.0,
                                      fontWeight: FontWeight.w600))),
                        ]),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(children: [
                      // ── Driver info ──────────────────────────
                      if (widget.driver != null)
                        Row(children: [
                          Container(
                            width: 46.0,
                            height: 46.0,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                  colors: [kGreen, kGreenDark]),
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            child: Center(
                                child: Text(
                                    widget.driver!.fullName[0].toUpperCase(),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18.0,
                                        fontWeight: FontWeight.w800))),
                          ),
                          const SizedBox(width: 12.0),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(widget.driver!.fullName,
                                    style: const TextStyle(
                                        fontSize: 14.0,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0D1B2A))),
                                Row(children: [
                                  const Icon(Icons.star_rounded,
                                      color: Colors.amber, size: 13.0),
                                  const SizedBox(width: 2.0),
                                  Text(
                                      '${widget.driver!.rating}  ·  ${widget.driver!.vehicleMake} ${widget.driver!.vehicleModel}',
                                      style: const TextStyle(
                                          fontSize: 11.0,
                                          color: Color(0xFF6B7280))),
                                ]),
                              ])),
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(widget.driver!.plateNumber,
                                    style: const TextStyle(
                                        fontSize: 13.0,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0D1B2A))),
                                Text(widget.driver!.vehicleColor,
                                    style: const TextStyle(
                                        fontSize: 11.0,
                                        color: Color(0xFF6B7280))),
                              ]),
                        ])
                      else
                        const Row(children: [
                          CircularProgressIndicator(color: kGreen),
                          SizedBox(width: 16),
                          Text('Searching for nearby drivers...',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                        ]),

                      const SizedBox(height: 12.0),

                      // ── Battery bar ──────────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12.0, vertical: 9.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F9FC),
                          borderRadius: BorderRadius.circular(12.0),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Row(children: [
                          Icon(Icons.battery_charging_full_rounded,
                              color: _socColor, size: 16.0),
                          const SizedBox(width: 8.0),
                          const Text('Vehicle Battery',
                              style: TextStyle(
                                  fontSize: 11.0, color: Color(0xFF6B7280))),
                          const Spacer(),
                          Text('${_soc.toStringAsFixed(0)}%',
                              style: TextStyle(
                                  fontSize: 13.0,
                                  fontWeight: FontWeight.w700,
                                  color: _socColor)),
                          const SizedBox(width: 8.0),
                          SizedBox(
                            width: 72.0,
                            height: 7.0,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4.0),
                              child: LinearProgressIndicator(
                                value: _soc / 100.0,
                                backgroundColor: const Color(0xFFE5E7EB),
                                valueColor: AlwaysStoppedAnimation(_socColor),
                              ),
                            ),
                          ),
                        ]),
                      ),

                      // Low battery warning
                      if (_soc <= 15) ...[
                        const SizedBox(height: 8.0),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12.0, vertical: 7.0),
                          decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(10.0)),
                          child: const Row(children: [
                            Icon(Icons.warning_rounded,
                                color: Color(0xFFEF4444), size: 14.0),
                            SizedBox(width: 6.0),
                            Expanded(
                                child: Text(
                                    'Battery critical! Navigate to nearest EV charging station.',
                                    style: TextStyle(
                                        fontSize: 11.0,
                                        color: Color(0xFFEF4444)))),
                          ]),
                        ),
                      ],

                      const SizedBox(height: 12.0),

                      // ── Route ────────────────────────────────
                      _RouteRow(
                          icon: Icons.circle,
                          color: kGreen,
                          label: 'From',
                          value: widget.pickupAddress ?? 'Pickup'),
                      const SizedBox(height: 5.0),
                      _RouteRow(
                          icon: Icons.location_on_rounded,
                          color: const Color(0xFFEF4444),
                          label: 'To',
                          value: widget.dropoffAddress ?? 'Dropoff'),

                      const SizedBox(height: 14.0),

                      // ── Action buttons ────────────────────────
                      Row(children: [
                        // SOS
                        GestureDetector(
                          onTap: _triggerSos,
                          child: Container(
                            width: 52.0,
                            height: 52.0,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(14.0),
                              border: Border.all(
                                  color: const Color(0xFFEF4444)
                                      .withValues(alpha: 0.4)),
                            ),
                            child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.sos_rounded,
                                      color: Color(0xFFEF4444), size: 20.0),
                                  Text('SOS',
                                      style: TextStyle(
                                          color: Color(0xFFEF4444),
                                          fontSize: 9.0,
                                          fontWeight: FontWeight.w800)),
                                ]),
                          ),
                        ),
                        const SizedBox(width: 10.0),

                        // Share location
                        GestureDetector(
                          onTap: () {
                            SocketService.instance
                                .shareLiveLocation(widget.rideId);
                            _showSnack('Live location shared!');
                          },
                          child: Container(
                            width: 52.0,
                            height: 52.0,
                            decoration: BoxDecoration(
                                color: kGreenLight,
                                borderRadius: BorderRadius.circular(14.0)),
                            child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.share_location_rounded,
                                      color: kGreenDark, size: 20.0),
                                  Text('Share',
                                      style: TextStyle(
                                          color: kGreenDark,
                                          fontSize: 9.0,
                                          fontWeight: FontWeight.w800)),
                                ]),
                          ),
                        ),
                        const SizedBox(width: 10.0),

                        // Driver step button OR Call button for rider
                        Expanded(
                          child: widget.isDriverMode
                              ? SizedBox(
                                  height: 52.0,
                                  child: ElevatedButton(
                                    onPressed: (isDone || _actionLoading)
                                        ? null
                                        : _advanceStep,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: cfg['color'] as Color,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14.0)),
                                    ),
                                    child: _actionLoading
                                        ? const SizedBox(
                                            width: 20.0,
                                            height: 20.0,
                                            child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2.5))
                                        : Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                                Icon(cfg['icon'] as IconData,
                                                    size: 18.0),
                                                const SizedBox(width: 6.0),
                                                Flexible(
                                                    child: Text(
                                                        cfg['label'] as String,
                                                        style: const TextStyle(
                                                            fontSize: 13.0,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w700))),
                                              ]),
                                  ),
                                )
                              : Container(
                                  height: 52.0,
                                  decoration: BoxDecoration(
                                      color: const Color(0xFFE3F2FD),
                                      borderRadius:
                                          BorderRadius.circular(14.0)),
                                  child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.phone_rounded,
                                            color: Color(0xFF1565C0),
                                            size: 20.0),
                                        SizedBox(width: 6.0),
                                        Text('Call Driver',
                                            style: TextStyle(
                                                color: Color(0xFF1565C0),
                                                fontSize: 13.0,
                                                fontWeight: FontWeight.w700)),
                                      ]),
                                ),
                        ),
                      ]),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Shared micro-widget ───────────────────────────────────────────
class _RouteRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label, value;
  const _RouteRow(
      {required this.icon,
      required this.color,
      required this.label,
      required this.value});
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, color: color, size: 11.0),
        const SizedBox(width: 8.0),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(fontSize: 10.0, color: Color(0xFF6B7280))),
          Text(value,
              style: const TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0D1B2A)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ]),
      ]);
}
