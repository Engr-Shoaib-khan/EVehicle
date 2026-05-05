import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../services/ride_service.dart';
import '../services/socket_service.dart';
import 'active_ride_screen.dart';
import 'main_auth_screen.dart';

// ─────────────────────────────────────────────────────────────
//  DRIVER DASHBOARD SCREEN
// ─────────────────────────────────────────────────────────────
class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen>
    with TickerProviderStateMixin {
  // ── Services ────────────────────────────────────────────────
  final _locationSvc = LocationService();
  final _authSvc = AuthService();

  // ── State ────────────────────────────────────────────────────
  Map<String, dynamic>? _user;
  bool _isOnline = false;
  bool _togglingOnline = false;
  double _batterySoc = 85.0;
  String _currentAddress = 'Fetching location...';
  Position? _currentPosition;

  // ── Stats (mock for now, wire to GET /api/drivers/me/stats) ─
  final int _todayRides = 0;
  final double _todayEarnings = 0.0;
  double _rating = 0.0;

  // ── Active ride request (from socket) ────────────────────────
  Map<String, dynamic>? _pendingRequest;
  bool _requestExpired = false;
  Timer? _requestTimer;
  int _requestCountdown = 30;

  // ── Animation: toggle pulse ───────────────────────────────────
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  // ── Animation: incoming alert slide ──────────────────────────
  late final AnimationController _alertCtrl;
  late final Animation<Offset> _alertSlide;

  // ── Socket subscriptions ──────────────────────────────────────
  final List<StreamSubscription> _subs = [];
  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _alertCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _alertSlide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _alertCtrl, curve: Curves.easeOutQuart));

    _loadUser();
    _initLocation();
    _connectSocket();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _alertCtrl.dispose();
    _requestTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  // ── Load saved user ──────────────────────────────────────────
  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kUserKey);
    if (raw != null && mounted) {
      final user = jsonDecode(raw) as Map<String, dynamic>;
      setState(() {
        _user = user;
        _rating = (user['rating']?['average'] ?? 0).toDouble();
      });
    }
  }

  Timer? _locationTimer;

  void _startLocationUpdates() {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (t) async {
      if (!_isOnline || !mounted) {
        t.cancel();
        return;
      }
      try {
        final pos = await _locationSvc.getCurrentPosition();
        if (mounted) {
          setState(() => _currentPosition = pos);
          SocketService.instance.updateLocation([pos.longitude, pos.latitude]);
        }
      } catch (e) {
        debugPrint('Location update failed: $e');
      }
    });
  }

  void _stopLocationUpdates() {
    _locationTimer?.cancel();
    _locationTimer = null;
  }

  // ── GPS ──────────────────────────────────────────────────────
  Future<void> _initLocation() async {
    try {
      final pos = await _locationSvc.getCurrentPosition();
      final addr =
          await _locationSvc.getAddressFromCoords(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() {
          _currentPosition = pos;
          _currentAddress = addr;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _currentAddress = 'Location unavailable');
      }
    }
  }

  // ── Socket ───────────────────────────────────────────────────
  Future<void> _connectSocket() async {
    await SocketService.instance.connect();
    if (!mounted) return;

    _subs
        .add(SocketService.instance.onNewRideRequest.listen(_onNewRideRequest));
    _subs.add(SocketService.instance.onRideTaken.listen((_) {
      // Another driver accepted — dismiss pending request silently
      if (mounted && _pendingRequest != null) {
        _dismissRequest(accepted: false, silent: true);
      }
    }));
  }

  // ── Toggle online/offline ────────────────────────────────────
  Future<void> _toggleOnline() async {
    setState(() => _togglingOnline = true);

    try {
      if (!_isOnline) {
        // Going online — need fresh GPS coords
        Position? pos;
        try {
          pos = _currentPosition ?? await _locationSvc.getCurrentPosition();
        } catch (_) {
          pos = null;
        }

        final coords = pos != null
            ? [pos.longitude, pos.latitude]
            : [67.0011, 24.8607]; // Karachi fallback

        SocketService.instance.goOnline(coords.cast<double>());
        setState(() {
          _isOnline = true;
        });
        _startLocationUpdates();
        _showSnack('You are now online. Waiting for ride requests...',
            icon: Icons.wifi_rounded);
      } else {
        SocketService.instance.goOffline();
        setState(() {
          _isOnline = false;
        });
        _stopLocationUpdates();
        _showSnack('You are now offline.',
            icon: Icons.wifi_off_rounded,
            isError: false,
            color: const Color(0xFF6B7280));
      }
    } finally {
      if (mounted) setState(() => _togglingOnline = false);
    }
  }

  // ── Battery SOC update ───────────────────────────────────────
  void _updateBattery(double newSoc) {
    setState(() => _batterySoc = newSoc);
    SocketService.instance.updateBattery(newSoc);

    if (newSoc <= 15 && newSoc > 0) {
      _showSnack('⚠️ Battery critical! Navigate to nearest charging station.',
          isError: true, icon: Icons.battery_alert_rounded);
    }
  }

  // ── Incoming ride request ────────────────────────────────────
  void _onNewRideRequest(Map<String, dynamic> data) {
    if (!mounted) return;
    setState(() {
      _pendingRequest = data;
      _requestExpired = false;
      _requestCountdown = 30;
    });
    _alertCtrl.forward(from: 0);

    // 30-second accept window
    _requestTimer?.cancel();
    _requestTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _requestCountdown--);
      if (_requestCountdown <= 0) {
        t.cancel();
        setState(() => _requestExpired = true);
        Future.delayed(
            const Duration(seconds: 2), () => _dismissRequest(accepted: false));
      }
    });
  }

  // ── Accept ride ──────────────────────────────────────────────
  final RideService _rideService = RideService();

  Future<void> _acceptRide() async {
    if (_pendingRequest == null) return;
    final rideId = _pendingRequest!['rideId']?.toString() ?? '';

    final result = await _rideService.acceptRide(rideId);

    if (result['success'] == true) {
      _dismissRequest(accepted: true);
      _showSnack('Ride accepted! Head to pickup location.',
          icon: Icons.check_circle_rounded);
      setState(() => _isOnline = false); // driver goes busy

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ActiveRideScreen(rideId: rideId)),
        );
      }
    } else {
      _showSnack(result['message'] ?? 'Failed to accept ride', isError: true);
    }
  }

  // ── Reject ride ──────────────────────────────────────────────
  void _rejectRide() {
    _dismissRequest(accepted: false);
    _showSnack('Ride rejected.',
        icon: Icons.close_rounded, color: const Color(0xFF6B7280));
  }

  void _dismissRequest({required bool accepted, bool silent = false}) {
    _requestTimer?.cancel();
    _alertCtrl.reverse().then((_) {
      if (mounted) setState(() => _pendingRequest = null);
    });
  }

  // ── Logout ───────────────────────────────────────────────────
  Future<void> _logout() async {
    if (_isOnline) SocketService.instance.goOffline();
    SocketService.instance.disconnect();
    await _authSvc.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainAuthScreen()),
        (_) => false);
  }

  // ── Snack helper ─────────────────────────────────────────────
  void _showSnack(
    String msg, {
    bool isError = false,
    IconData icon = Icons.info_outline_rounded,
    Color? color,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon, color: Colors.white, size: 16.0),
        const SizedBox(width: 8.0),
        Expanded(child: Text(msg, style: const TextStyle(fontSize: 13.0))),
      ]),
      backgroundColor: color ?? (isError ? const Color(0xFFEF4444) : kGreen),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      duration: const Duration(seconds: 3),
    ));
  }

  // ── UI helpers ───────────────────────────────────────────────
  Color get _batteryColor {
    if (_batterySoc > 40) return kGreen;
    if (_batterySoc > 15) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  String get _firstName =>
      (_user?['fullName'] as String? ?? 'Driver').split(' ').first;

  // ─────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420.0),
            child: Stack(
              children: [
                // ── MAIN SCROLL CONTENT ──────────────────────
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 120.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 24.0),
                      _buildStatusCard(),
                      const SizedBox(height: 20.0),
                      _buildStatsRow(),
                      const SizedBox(height: 20.0),
                      _buildBatterySimulator(),
                      const SizedBox(height: 20.0),
                      _buildLocationCard(),
                      const SizedBox(height: 20.0),
                      _buildQuickTips(),
                    ],
                  ),
                ),

                // ── INCOMING RIDE ALERT (overlay) ────────────
                if (_pendingRequest != null)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: SlideTransition(
                      position: _alertSlide,
                      child: _buildRideRequestAlert(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  HEADER
  // ─────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Row(children: [
      // Avatar
      Container(
        width: 46.0,
        height: 46.0,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [kGreen, kGreenDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
        ),
        child: Center(
            child: Text(
          _firstName.isNotEmpty ? _firstName[0].toUpperCase() : 'D',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18.0),
        )),
      ),
      const SizedBox(width: 12.0),
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Hey, $_firstName!',
            style: const TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0D1B2A),
                letterSpacing: -0.4)),
        Row(children: [
          Container(
            width: 7.0,
            height: 7.0,
            decoration: BoxDecoration(
              color: _isOnline ? kGreen : const Color(0xFF9CA3AF),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5.0),
          Text(
            _isOnline ? 'Online — accepting rides' : 'Offline',
            style: TextStyle(
              fontSize: 12.0,
              fontWeight: FontWeight.w500,
              color: _isOnline ? kGreenDark : const Color(0xFF9CA3AF),
            ),
          ),
        ]),
      ])),
      // Logout
      GestureDetector(
        onTap: _logout,
        child: Container(
          padding: const EdgeInsets.all(9.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04), blurRadius: 6.0)
            ],
          ),
          child: const Icon(Icons.logout_rounded,
              size: 18.0, color: Color(0xFF6B7280)),
        ),
      ),
    ]);
  }

  // ─────────────────────────────────────────────────────────────
  //  GO ONLINE / OFFLINE STATUS CARD
  // ─────────────────────────────────────────────────────────────
  Widget _buildStatusCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.all(22.0),
      decoration: BoxDecoration(
        gradient: _isOnline
            ? const LinearGradient(
                colors: [kGreen, kGreenDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight)
            : const LinearGradient(
                colors: [Color(0xFFF3F4F6), Color(0xFFE5E7EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(22.0),
        boxShadow: [
          BoxShadow(
            color: _isOnline
                ? kGreen.withValues(alpha: 0.35)
                : Colors.black.withValues(alpha: 0.06),
            blurRadius: 20.0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(children: [
        // Animated toggle button
        GestureDetector(
          onTap: _togglingOnline ? null : _toggleOnline,
          child: AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, child) => Transform.scale(
              scale: _isOnline ? _pulseAnim.value : 1.0,
              child: child,
            ),
            child: Container(
              width: 90.0,
              height: 90.0,
              decoration: BoxDecoration(
                color: _isOnline
                    ? Colors.white.withValues(alpha: 0.2)
                    : const Color(0xFFE5E7EB),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _isOnline
                      ? Colors.white.withValues(alpha: 0.5)
                      : const Color(0xFFD1D5DB),
                  width: 3.0,
                ),
              ),
              child: _togglingOnline
                  ? Center(
                      child: SizedBox(
                          width: 28.0,
                          height: 28.0,
                          child: CircularProgressIndicator(
                              color: _isOnline ? Colors.white : kGreen,
                              strokeWidth: 3.0)))
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                          Icon(
                            _isOnline
                                ? Icons.wifi_rounded
                                : Icons.wifi_off_rounded,
                            color: _isOnline
                                ? Colors.white
                                : const Color(0xFF9CA3AF),
                            size: 30.0,
                          ),
                          const SizedBox(height: 2.0),
                          Text(
                            _isOnline ? 'ONLINE' : 'OFFLINE',
                            style: TextStyle(
                              fontSize: 10.0,
                              fontWeight: FontWeight.w800,
                              color: _isOnline
                                  ? Colors.white
                                  : const Color(0xFF9CA3AF),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ]),
            ),
          ),
        ),

        const SizedBox(height: 16.0),

        Text(
          _isOnline ? 'Tap to Go Offline' : 'Tap to Go Online',
          style: TextStyle(
            fontSize: 15.0,
            fontWeight: FontWeight.w600,
            color: _isOnline ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 4.0),
        Text(
          _isOnline
              ? 'You are visible to riders in your area'
              : 'You will not receive any ride requests',
          style: TextStyle(
            fontSize: 12.0,
            color: _isOnline
                ? Colors.white.withValues(alpha: 0.75)
                : const Color(0xFF9CA3AF),
          ),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  STATS ROW
  // ─────────────────────────────────────────────────────────────
  Widget _buildStatsRow() {
    return Row(children: [
      Expanded(
          child: _StatCard(
        icon: Icons.directions_car_rounded,
        iconColor: const Color(0xFF1565C0),
        iconBg: const Color(0xFFE3F2FD),
        label: 'Today\'s Rides',
        value: '$_todayRides',
      )),
      const SizedBox(width: 12.0),
      Expanded(
          child: _StatCard(
        icon: Icons.payments_rounded,
        iconColor: const Color(0xFF00897B),
        iconBg: const Color(0xFFE0F2F1),
        label: 'Earnings',
        value: 'Rs. ${_todayEarnings.toStringAsFixed(0)}',
      )),
      const SizedBox(width: 12.0),
      Expanded(
          child: _StatCard(
        icon: Icons.star_rounded,
        iconColor: const Color(0xFFF59E0B),
        iconBg: const Color(0xFFFFF8E1),
        label: 'Rating',
        value: _rating > 0 ? _rating.toStringAsFixed(1) : '—',
      )),
    ]);
  }

  // ─────────────────────────────────────────────────────────────
  //  BATTERY SOC SIMULATOR
  // ─────────────────────────────────────────────────────────────
  Widget _buildBatterySimulator() {
    return Container(
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.0),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10.0,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: _batteryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: Icon(Icons.battery_charging_full_rounded,
                color: _batteryColor, size: 20.0),
          ),
          const SizedBox(width: 10.0),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Battery SOC Simulator',
                style: TextStyle(
                    fontSize: 14.0,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0D1B2A))),
            Text('Emits live socket event to rider',
                style: TextStyle(fontSize: 11.0, color: Color(0xFF6B7280))),
          ]),
          const Spacer(),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding:
                const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: _batteryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: Text(
              '${_batterySoc.toStringAsFixed(0)}%',
              style: TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.w800,
                  color: _batteryColor),
            ),
          ),
        ]),

        const SizedBox(height: 16.0),

        // Battery bar
        ClipRRect(
          borderRadius: BorderRadius.circular(6.0),
          child: LinearProgressIndicator(
            value: _batterySoc / 100.0,
            minHeight: 10.0,
            backgroundColor: const Color(0xFFF3F4F6),
            valueColor: AlwaysStoppedAnimation(_batteryColor),
          ),
        ),

        const SizedBox(height: 16.0),

        // Slider
        SliderTheme(
          data: SliderThemeData(
            thumbColor: _batteryColor,
            activeTrackColor: _batteryColor,
            inactiveTrackColor: const Color(0xFFF3F4F6),
            overlayColor: _batteryColor.withValues(alpha: 0.12),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10.0),
            trackHeight: 4.0,
          ),
          child: Slider(
            value: _batterySoc,
            min: 0,
            max: 100,
            divisions: 20,
            onChanged: _updateBattery,
          ),
        ),

        // Quick preset buttons
        Row(children: [
          _BatteryPreset(
              label: '100%', color: kGreen, onTap: () => _updateBattery(100)),
          const SizedBox(width: 8.0),
          _BatteryPreset(
              label: '50%',
              color: const Color(0xFFF59E0B),
              onTap: () => _updateBattery(50)),
          const SizedBox(width: 8.0),
          _BatteryPreset(
              label: '15%',
              color: const Color(0xFFEF4444),
              onTap: () => _updateBattery(15)),
          const SizedBox(width: 8.0),
          _BatteryPreset(
              label: '5%',
              color: const Color(0xFF991B1B),
              onTap: () => _updateBattery(5)),
          const Spacer(),
          // Manual ±5 stepper
          _StepButton(
              icon: Icons.remove_rounded,
              onTap: () => _updateBattery((_batterySoc - 5).clamp(0, 100))),
          const SizedBox(width: 6.0),
          _StepButton(
              icon: Icons.add_rounded,
              onTap: () => _updateBattery((_batterySoc + 5).clamp(0, 100))),
        ]),

        if (_batterySoc <= 15) ...[
          const SizedBox(height: 12.0),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10.0),
              border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
            ),
            child: const Row(children: [
              Icon(Icons.warning_rounded, color: Color(0xFFEF4444), size: 14.0),
              SizedBox(width: 6.0),
              Expanded(
                  child: Text(
                'Low battery warning emitted to rider. Navigate to nearest EV charging station.',
                style: TextStyle(
                    fontSize: 11.0, color: Color(0xFFEF4444), height: 1.4),
              )),
            ]),
          ),
        ],
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  CURRENT LOCATION CARD
  // ─────────────────────────────────────────────────────────────
  Widget _buildLocationCard() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8.0,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10.0),
          decoration: BoxDecoration(
              color: kGreenLight, borderRadius: BorderRadius.circular(12.0)),
          child:
              const Icon(Icons.my_location_rounded, color: kGreen, size: 20.0),
        ),
        const SizedBox(width: 12.0),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Current Location',
              style: TextStyle(
                  fontSize: 11.0,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF9CA3AF))),
          const SizedBox(height: 2.0),
          Text(_currentAddress,
              style: const TextStyle(
                  fontSize: 13.0,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0D1B2A)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ])),
        GestureDetector(
          onTap: () async {
            setState(() => _currentAddress = 'Refreshing...');
            await _initLocation();
          },
          child: Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10.0)),
            child: const Icon(Icons.refresh_rounded,
                size: 16.0, color: Color(0xFF6B7280)),
          ),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  QUICK TIPS
  // ─────────────────────────────────────────────────────────────
  Widget _buildQuickTips() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: kGreenLight,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: kGreen.withValues(alpha: 0.2)),
      ),
      child:
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.lightbulb_outline_rounded, color: kGreenDark, size: 16.0),
          SizedBox(width: 6.0),
          Text('Driver Tips',
              style: TextStyle(
                  fontSize: 13.0,
                  fontWeight: FontWeight.w700,
                  color: kGreenDark)),
        ]),
        SizedBox(height: 10.0),
        _Tip(
            text:
                'Go online only when you are ready to drive and in a busy area.'),
        _Tip(text: 'Keep battery above 20% before starting a long trip.'),
        _Tip(
            text:
                'Female rider requests will be sent to you if no female drivers are available.'),
        _Tip(
            text: 'KYC must be approved before you can receive ride requests.'),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  INCOMING RIDE REQUEST ALERT OVERLAY
  // ─────────────────────────────────────────────────────────────
  Widget _buildRideRequestAlert() {
    final req = _pendingRequest!;

    final pickup = (req['pickupLocation'] as Map?)?['address'] as String? ??
        'Pickup location';
    final dropoff = (req['dropoffLocation'] as Map?)?['address'] as String? ??
        'Drop-off location';
    final fare = (req['fare'] as Map?)?['estimated'] ?? 0;
    final distance = req['distanceKm'] ?? 0;
    final duration = req['durationMins'] ?? 0;
    final payment = req['paymentMethod'] ?? 'cash';
    final vehicle = req['vehicleTypeId'] ?? 'ev_bike';
    final gender = req['genderPreference'] ?? 'any';

    final countdownProgress = _requestCountdown / 30.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28.0)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 32.0,
              offset: const Offset(0, -6)),
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Drag handle
        const SizedBox(height: 12.0),
        Container(
            width: 40.0,
            height: 4.0,
            decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2.0))),

        // Header bar
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16.0, 14.0, 16.0, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
          decoration: BoxDecoration(
            color: _requestExpired
                ? const Color(0xFFFEF2F2)
                : const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(14.0),
          ),
          child: Row(children: [
            Icon(
              _requestExpired ? Icons.timer_off_rounded : Icons.timer_rounded,
              color: _requestExpired
                  ? const Color(0xFFEF4444)
                  : const Color(0xFFF59E0B),
              size: 18.0,
            ),
            const SizedBox(width: 8.0),
            Expanded(
                child: Text(
              _requestExpired ? 'Request expired!' : 'New Ride Request!',
              style: TextStyle(
                fontSize: 14.0,
                fontWeight: FontWeight.w700,
                color: _requestExpired
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF92400E),
              ),
            )),
            // Countdown ring
            SizedBox(
                width: 36.0,
                height: 36.0,
                child: Stack(alignment: Alignment.center, children: [
                  CircularProgressIndicator(
                    value: countdownProgress,
                    strokeWidth: 3.5,
                    backgroundColor: const Color(0xFFE5E7EB),
                    valueColor: AlwaysStoppedAnimation(_requestExpired
                        ? const Color(0xFFEF4444)
                        : countdownProgress > 0.5
                            ? kGreen
                            : const Color(0xFFF59E0B)),
                  ),
                  Text('$_requestCountdown',
                      style: TextStyle(
                          fontSize: 11.0,
                          fontWeight: FontWeight.w800,
                          color: _requestExpired
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF0D1B2A))),
                ])),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 14.0, 16.0, 0),
          child: Column(children: [
            // Fare + distance row
            Row(children: [
              Expanded(
                  child: _AlertStat(
                icon: Icons.payments_rounded,
                iconColor: kGreen,
                label: 'Fare',
                value: 'Rs. $fare',
                large: true,
              )),
              const SizedBox(width: 10.0),
              Expanded(
                  child: _AlertStat(
                icon: Icons.route_rounded,
                iconColor: const Color(0xFF1565C0),
                label: 'Distance',
                value: '${distance.toStringAsFixed(1)} km',
              )),
              const SizedBox(width: 10.0),
              Expanded(
                  child: _AlertStat(
                icon: Icons.access_time_rounded,
                iconColor: const Color(0xFFF59E0B),
                label: 'ETA',
                value: '$duration min',
              )),
            ]),

            const SizedBox(height: 14.0),

            // Route
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9FC),
                borderRadius: BorderRadius.circular(14.0),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(children: [
                _RouteRow(
                    icon: Icons.circle,
                    color: kGreen,
                    label: 'Pickup',
                    value: pickup),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 6.0, horizontal: 5.0),
                  child: Row(children: [
                    Container(
                        width: 2.0,
                        height: 16.0,
                        color: const Color(0xFFE5E7EB)),
                  ]),
                ),
                _RouteRow(
                    icon: Icons.location_on_rounded,
                    color: const Color(0xFFEF4444),
                    label: 'Drop-off',
                    value: dropoff),
              ]),
            ),

            const SizedBox(height: 10.0),

            // Tags row
            Row(children: [
              _AlertTag(
                  icon: Icons.payments_outlined,
                  label: payment == 'cash' ? 'Cash' : 'Card'),
              const SizedBox(width: 8.0),
              _AlertTag(
                  icon: Icons.bolt_rounded,
                  label: vehicle.replaceAll('_', ' ').toUpperCase()),
              if (gender == 'female') ...[
                const SizedBox(width: 8.0),
                const _AlertTag(
                    icon: Icons.female_rounded,
                    label: 'Female Pref',
                    isHighlight: true),
              ],
            ]),

            const SizedBox(height: 16.0),

            // Accept / Reject
            Row(children: [
              Expanded(
                child: SizedBox(
                    height: 52.0,
                    child: OutlinedButton(
                      onPressed: _requestExpired ? null : _rejectRide,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        side: const BorderSide(
                            color: Color(0xFFEF4444), width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.0)),
                        disabledForegroundColor: const Color(0xFFD1D5DB),
                      ),
                      child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.close_rounded, size: 18.0),
                            SizedBox(width: 6.0),
                            Text('Reject',
                                style: TextStyle(
                                    fontSize: 15.0,
                                    fontWeight: FontWeight.w700)),
                          ]),
                    )),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                flex: 2,
                child: SizedBox(
                    height: 52.0,
                    child: ElevatedButton(
                      onPressed: _requestExpired ? null : _acceptRide,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.0)),
                        disabledBackgroundColor: const Color(0xFFD1D5DB),
                      ),
                      child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_rounded, size: 18.0),
                            SizedBox(width: 6.0),
                            Text('Accept Ride',
                                style: TextStyle(
                                    fontSize: 15.0,
                                    fontWeight: FontWeight.w700)),
                          ]),
                    )),
              ),
            ]),

            const SizedBox(height: 20.0),
          ]),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  MICRO WIDGETS
// ═══════════════════════════════════════════════════════════════

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor, iconBg;
  final String label, value;
  const _StatCard(
      {required this.icon,
      required this.iconColor,
      required this.iconBg,
      required this.label,
      required this.value});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8.0,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(7.0),
            decoration: BoxDecoration(
                color: iconBg, borderRadius: BorderRadius.circular(10.0)),
            child: Icon(icon, color: iconColor, size: 16.0),
          ),
          const SizedBox(height: 10.0),
          Text(value,
              style: const TextStyle(
                  fontSize: 18.0,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0D1B2A))),
          const SizedBox(height: 2.0),
          Text(label,
              style: const TextStyle(
                  fontSize: 10.0,
                  color: Color(0xFF9CA3AF),
                  fontWeight: FontWeight.w500)),
        ]),
      );
}

class _BatteryPreset extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _BatteryPreset(
      {required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20.0),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 11.0, fontWeight: FontWeight.w700, color: color)),
        ),
      );
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30.0,
          height: 30.0,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Icon(icon, size: 16.0, color: const Color(0xFF6B7280)),
        ),
      );
}

class _AlertStat extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label, value;
  final bool large;
  const _AlertStat(
      {required this.icon,
      required this.iconColor,
      required this.label,
      required this.value,
      this.large = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10.0),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9FC),
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: iconColor, size: 14.0),
          const SizedBox(height: 4.0),
          Text(value,
              style: TextStyle(
                  fontSize: large ? 16.0 : 13.0,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0D1B2A))),
          Text(label,
              style: const TextStyle(fontSize: 10.0, color: Color(0xFF9CA3AF))),
        ]),
      );
}

class _AlertTag extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isHighlight;
  const _AlertTag(
      {required this.icon, required this.label, this.isHighlight = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
        decoration: BoxDecoration(
          color: isHighlight ? const Color(0xFFFCE4EC) : kGreenLight,
          borderRadius: BorderRadius.circular(20.0),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size: 11.0,
              color: isHighlight ? const Color(0xFFAD1457) : kGreenDark),
          const SizedBox(width: 4.0),
          Text(label,
              style: TextStyle(
                  fontSize: 10.0,
                  fontWeight: FontWeight.w600,
                  color: isHighlight ? const Color(0xFFAD1457) : kGreenDark)),
        ]),
      );
}

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
        Icon(icon, color: color, size: 12.0),
        const SizedBox(width: 8.0),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(fontSize: 10.0, color: Color(0xFF9CA3AF))),
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

class _Tip extends StatelessWidget {
  final String text;
  const _Tip({required this.text});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6.0),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
              padding: EdgeInsets.only(top: 4.0),
              child: Icon(Icons.circle, size: 5.0, color: kGreenDark)),
          const SizedBox(width: 8.0),
          Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 12.0, color: kGreenDark, height: 1.4))),
        ]),
      );
}
