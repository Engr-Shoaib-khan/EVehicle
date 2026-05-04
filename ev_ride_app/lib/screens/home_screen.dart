import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../models/vehicle_type.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../services/ride_service.dart';
import 'active_ride_screen.dart';
import 'main_auth_screen.dart';

// ── Clean green-tinted map style ─────────────────────────────────
const String _kMapStyle = '''
[
  {"featureType":"poi","elementType":"labels","stylers":[{"visibility":"off"}]},
  {"featureType":"transit","elementType":"labels","stylers":[{"visibility":"off"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
  {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#f5f5f5"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#c9e8f0"}]},
  {"featureType":"landscape","elementType":"geometry","stylers":[{"color":"#f0f4f0"}]},
  {"featureType":"administrative","elementType":"labels.text.fill","stylers":[{"color":"#555555"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#777777"}]}
]
''';

enum _SheetPhase { selectVehicle, confirmRide, searching }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final _locationService = LocationService();
  final _authService     = AuthService();

  GoogleMapController? _mapController;
  Position? _currentPosition;
  LatLng?   _pickupLatLng;
  LatLng?   _dropoffLatLng;
  String    _pickupAddress  = 'Fetching location...';
  String    _dropoffAddress = '';
  final Set<Marker>   _markers   = {};
  final Set<Polyline> _polylines = {};

  Map<String, dynamic>? _user;
  _SheetPhase _phase = _SheetPhase.selectVehicle;
  int  _selectedVehicleIndex = 0;
  String _selectedPaymentMethod = 'cash';
  bool _isLoading = false;

  late final AnimationController _sheetAnim;
  late final Animation<double>   _sheetSlide;
  final _dropoffCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sheetAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    _sheetSlide = CurvedAnimation(parent: _sheetAnim, curve: Curves.easeOutQuart);
    _loadUser();
    _initLocation();
    _sheetAnim.forward();
  }

  @override
  void dispose() {
    _sheetAnim.dispose();
    _dropoffCtrl.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString(kUserKey);
    if (raw != null && mounted) setState(() => _user = jsonDecode(raw));
  }

  Future<void> _initLocation() async {
    try {
      final pos  = await _locationService.getCurrentPosition();
      final addr = await _locationService.getAddressFromCoords(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() {
        _currentPosition = pos;
        _pickupLatLng    = LatLng(pos.latitude, pos.longitude);
        _pickupAddress   = addr;
      });
      _updateMarkers();
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(CameraPosition(target: _pickupLatLng!, zoom: 15.5)),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _pickupAddress = 'Location unavailable');
        // _showSnack(e.toString(), isError: true);
      }
    }
  }

  void _updateMarkers() {
    _markers.clear();
    if (_pickupLatLng != null) {
      _markers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: _pickupLatLng!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: 'Pickup', snippet: _pickupAddress),
      ));
    }
    if (_dropoffLatLng != null) {
      _markers.add(Marker(
        markerId: const MarkerId('dropoff'),
        position: _dropoffLatLng!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: 'Destination', snippet: _dropoffAddress),
      ));
    }
    if (mounted) setState(() {});
  }

  Future<void> _onMapTap(LatLng latLng) async {
    if (_phase == _SheetPhase.searching) return;
    
    setState(() { 
      _dropoffLatLng = latLng; 
      _dropoffAddress = 'Fetching address...'; 
      _dropoffCtrl.text = 'Fetching address...';
    });
    _updateMarkers();
    
    final addr = await _locationService.getAddressFromCoords(latLng.latitude, latLng.longitude);
    if (mounted) {
      setState(() { 
        _dropoffAddress = addr; 
        _dropoffCtrl.text = addr; 
      });
      _updateMarkers();
    }
  }

  void _fitBounds() {
    if (_pickupLatLng != null && _dropoffLatLng != null) {
      final bounds = LatLngBounds(
        southwest: LatLng(
          _pickupLatLng!.latitude  < _dropoffLatLng!.latitude  ? _pickupLatLng!.latitude  : _dropoffLatLng!.latitude,
          _pickupLatLng!.longitude < _dropoffLatLng!.longitude ? _pickupLatLng!.longitude : _dropoffLatLng!.longitude,
        ),
        northeast: LatLng(
          _pickupLatLng!.latitude  > _dropoffLatLng!.latitude  ? _pickupLatLng!.latitude  : _dropoffLatLng!.latitude,
          _pickupLatLng!.longitude > _dropoffLatLng!.longitude ? _pickupLatLng!.longitude : _dropoffLatLng!.longitude,
        ),
      );
      _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 120));
    }
  }

  Future<void> _confirmRide() async {
    if (_dropoffLatLng == null) {
      _showSnack('Please tap the map to set a drop-off location.', isError: true);
      return;
    }
    setState(() => _phase = _SheetPhase.confirmRide);
    _fitBounds();
  }

  final RideService _rideService = RideService();

  Future<void> _requestRide() async {
    if (_pickupLatLng == null || _dropoffLatLng == null) {
      _showSnack('Missing location data.', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
      _phase = _SheetPhase.searching;
    });

    final vehicle = kEvFleet[_selectedVehicleIndex];
    
    final result = await _rideService.requestRide(
      pickupCoordinates: [_pickupLatLng!.longitude, _pickupLatLng!.latitude],
      pickupAddress: _pickupAddress,
      dropoffCoordinates: [_dropoffLatLng!.longitude, _dropoffLatLng!.latitude],
      dropoffAddress: _dropoffAddress,
      paymentMethod: _selectedPaymentMethod,
      vehicleTypeId: vehicle.id,
    );

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      if (mounted) {
        final rideId = result['data']['rideId'];
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ActiveRideScreen(rideId: rideId)),
        ).then((_) {
          // Reset when back
          setState(() {
            _phase = _SheetPhase.selectVehicle;
            _dropoffLatLng = null;
            _dropoffAddress = '';
            _dropoffCtrl.clear();
            _updateMarkers();
          });
        });
      }
    } else {
      setState(() => _phase = _SheetPhase.confirmRide);
      _showSnack(result['message'] ?? 'Failed to request ride', isError: true);
    }
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const MainAuthScreen()), (_) => false);
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? kError : kGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
    ));
  }

  double get _bottomSheetHeight {
    if (_phase == _SheetPhase.searching) return 150.h;
    return _phase == _SheetPhase.selectVehicle ? 400.h.clamp(380.0, 450.0) : 360.h.clamp(340.0, 420.0);
  }

  @override
  Widget build(BuildContext context) {
    final firstName = (_user?['fullName'] as String? ?? 'Rider').split(' ').first;
    final isDriver  = (_user?['role'] ?? 'rider') == 'driver';
    final vehicle   = kEvFleet[_selectedVehicleIndex];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            _buildMap(),
            if (_phase != _SheetPhase.searching) 
              Positioned(top: 0, left: 0, right: 0, child: _buildTopBar(firstName, isDriver)),
            
            Positioned(
              bottom: _bottomSheetHeight + 16.h,
              right: 16.w,
              child: _buildRecenterButton(),
            ),
            
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(_sheetSlide),
                child: _buildBottomSheet(vehicle),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap() {
    final initialTarget = _pickupLatLng ?? const LatLng(24.8607, 67.0011);
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: initialTarget, zoom: 14),
      markers: _markers,
      polylines: _polylines,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      onMapCreated: (ctrl) {
        _mapController = ctrl;
        ctrl.setMapStyle(_kMapStyle);
        if (_pickupLatLng != null) {
          ctrl.animateCamera(CameraUpdate.newCameraPosition(
            CameraPosition(target: _pickupLatLng!, zoom: 15.5)));
        }
      },
      onTap: _onMapTap,
    );
  }

  Widget _buildTopBar(String firstName, bool isDriver) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: EdgeInsets.fromLTRB(20.w, 52.h.clamp(40.0, 70.0), 20.w, 14.h),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.82),
            border: Border(bottom: BorderSide(color: kBorder.withOpacity(0.5))),
          ),
          child: Row(children: [
            Container(
              width: 40.w.clamp(35.0, 50.0), height: 40.w.clamp(35.0, 50.0),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [kGreen, kGreenDark],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
                shape: BoxShape.circle,
              ),
              child: Center(child: Text(
                firstName.isNotEmpty ? firstName[0].toUpperCase() : 'R',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16.sp.clamp(14.0, 20.0)),
              )),
            ),
            SizedBox(width: 12.w),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Hey, $firstName', style: TextStyle(fontSize: 16.sp.clamp(14.0, 18.0), fontWeight: FontWeight.w700, color: kTextPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
              SizedBox(height: 2.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: isDriver ? const Color(0xFFFFF3E0) : kGreenLight,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(isDriver ? 'Driver Mode' : 'Rider Mode',
                  style: TextStyle(fontSize: 10.sp.clamp(9.0, 12.0), fontWeight: FontWeight.w600,
                    color: isDriver ? const Color(0xFFE65100) : kGreenDark)),
              ),
            ])),
            GestureDetector(
              onTap: _logout,
              child: Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: kSurface, borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: kBorder),
                ),
                child: Icon(Icons.logout_rounded, size: 18.r.clamp(16.0, 22.0), color: kTextSecondary),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildRecenterButton() {
    return GestureDetector(
      onTap: () {
        if (_pickupLatLng != null) {
          _mapController?.animateCamera(CameraUpdate.newCameraPosition(
            CameraPosition(target: _pickupLatLng!, zoom: 15.5)));
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: kBorder.withOpacity(0.6)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Icon(Icons.my_location_rounded, color: kGreen, size: 22.r.clamp(20.0, 26.0)),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSheet(VehicleType vehicle) {
    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.94),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 32, offset: const Offset(0, -4))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(height: 12.h),
            Container(width: 40.w.clamp(30.0, 50.0), height: 4.h,
              decoration: BoxDecoration(color: kBorder, borderRadius: BorderRadius.circular(2.r))),
            SizedBox(height: 16.h),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _phase == _SheetPhase.searching
                  ? _buildSearchingSheet()
                  : _phase == _SheetPhase.selectVehicle
                      ? _buildSelectVehicleSheet(key: const ValueKey('select'))
                      : _buildConfirmSheet(vehicle, key: const ValueKey('confirm')),
            ),
            SizedBox(height: 16.h),
          ]),
        ),
      ),
    );
  }

  Widget _buildSearchingSheet() {
    return Padding(
      padding: EdgeInsets.all(24.w),
      child: Column(children: [
        const CircularProgressIndicator(color: kGreen),
        SizedBox(height: 20.h),
        Text('Finding nearby drivers...', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: kTextPrimary)),
        SizedBox(height: 8.h),
        Text('Please wait while we broadcast your request.', style: TextStyle(fontSize: 13.sp, color: kTextSecondary)),
      ]),
    );
  }

  Widget _buildSelectVehicleSheet({Key? key}) {
    return Padding(
      key: key,
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildLocationInputs(),
        SizedBox(height: 20.h),
        Row(children: [
          Expanded(child: Text('Choose your ride', style: TextStyle(fontSize: 15.sp.clamp(14.0, 18.0), fontWeight: FontWeight.w700, color: kTextPrimary))),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
            decoration: BoxDecoration(color: kGreenLight, borderRadius: BorderRadius.circular(20.r)),
            child: Text('All Electric', style: TextStyle(fontSize: 10.sp.clamp(9.0, 12.0), fontWeight: FontWeight.w600, color: kGreenDark)),
          ),
        ]),
        SizedBox(height: 12.h),
        SizedBox(
          height: 130.h.clamp(120.0, 150.0),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: kEvFleet.length,
            separatorBuilder: (_, __) => SizedBox(width: 10.w),
            itemBuilder: (context, i) => _VehicleCard(
              vehicle: kEvFleet[i],
              isSelected: _selectedVehicleIndex == i,
              onTap: () => setState(() => _selectedVehicleIndex = i),
            ),
          ),
        ),
        SizedBox(height: 16.h),
        SizedBox(
          width: double.infinity, height: 52.h.clamp(45.0, 60.0),
          child: ElevatedButton(
            onPressed: _confirmRide,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('Confirm Pickup Point', style: TextStyle(fontSize: 15.sp.clamp(14.0, 18.0), fontWeight: FontWeight.w600)),
              SizedBox(width: 8.w),
              Icon(Icons.arrow_forward_rounded, size: 18.r.clamp(16.0, 22.0)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildLocationInputs() {
    return Container(
      decoration: BoxDecoration(
        color: kSurface, borderRadius: BorderRadius.circular(16.r), border: Border.all(color: kBorder)),
      child: Column(children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
          child: Row(children: [
            Container(width: 10.w.clamp(8.0, 12.0), height: 10.w.clamp(8.0, 12.0), decoration: const BoxDecoration(color: kGreen, shape: BoxShape.circle)),
            SizedBox(width: 10.w),
            Expanded(child: Text(_pickupAddress,
              style: TextStyle(fontSize: 13.sp.clamp(12.0, 16.0), color: kTextPrimary, fontWeight: FontWeight.w500),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
        ),
        Divider(height: 1, color: kBorder),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
          child: Row(children: [
            Container(width: 10.w.clamp(8.0, 12.0), height: 10.w.clamp(8.0, 12.0),
              decoration: BoxDecoration(shape: BoxShape.circle,
                border: Border.all(color: kError, width: 2))),
            SizedBox(width: 10.w),
            Expanded(child: TextField(
              controller: _dropoffCtrl,
              readOnly: true, // Only allow map tap for now to ensure precision
              onTap: () => _showSnack('Tap the map to select destination'),
              style: TextStyle(fontSize: 13.sp.clamp(12.0, 16.0), color: kTextPrimary),
              decoration: InputDecoration(
                hintText: 'Where to? (tap map)',
                hintStyle: TextStyle(color: kTextSecondary, fontSize: 13.sp.clamp(12.0, 16.0)),
                border: InputBorder.none, enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none, filled: false,
                contentPadding: EdgeInsets.symmetric(vertical: 10.h),
              ),
            )),
          ]),
        ),
      ]),
    );
  }

  Widget _buildConfirmSheet(VehicleType vehicle, {Key? key}) {
    const double distanceKm = 5.0;
    final int baseFareNum = int.tryParse(vehicle.baseFare.replaceAll(RegExp(r'[^0-9]'), '')) ?? 50;
    final int perKmNum    = int.tryParse(vehicle.pricePerKm.replaceAll(RegExp(r'[^0-9]'), '')) ?? 20;
    final int estimatedFare = (baseFareNum + (distanceKm * perKmNum)).round();

    return Padding(
      key: key,
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          GestureDetector(
            onTap: () => setState(() => _phase = _SheetPhase.selectVehicle),
            child: Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(10.r), border: Border.all(color: kBorder)),
              child: Icon(Icons.arrow_back_rounded, size: 18.r.clamp(16.0, 22.0), color: kTextPrimary),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(child: Text('Confirm Your Ride', style: TextStyle(fontSize: 16.sp.clamp(14.0, 20.0), fontWeight: FontWeight.w700, color: kTextPrimary), maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
        SizedBox(height: 16.h),
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(16.r), border: Border.all(color: kBorder)),
          child: Column(children: [
            Row(children: [
              Text(vehicle.emoji, style: TextStyle(fontSize: 28.sp.clamp(24.0, 36.0))),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(vehicle.name, style: TextStyle(fontSize: 14.sp.clamp(12.0, 16.0), fontWeight: FontWeight.w700, color: kTextPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(vehicle.description, style: TextStyle(fontSize: 11.sp.clamp(10.0, 13.0), color: kTextSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
              SizedBox(width: 8.w),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('Rs. $estimatedFare', style: TextStyle(fontSize: 18.sp.clamp(16.0, 22.0), fontWeight: FontWeight.w800, color: kTextPrimary)),
                Text('Estimated', style: TextStyle(fontSize: 10.sp.clamp(9.0, 12.0), color: kTextSecondary)),
              ]),
            ]),
            Padding(padding: EdgeInsets.symmetric(vertical: 12.h), child: const Divider(color: kBorder, height: 1)),
            _RouteLine(icon: Icons.circle, iconColor: kGreen, label: 'Pickup', value: _pickupAddress),
            SizedBox(height: 8.h),
            _RouteLine(icon: Icons.location_on_rounded, iconColor: kError, label: 'Drop-off',
              value: _dropoffAddress.isEmpty ? 'Map selection' : _dropoffAddress),
          ]),
        ),
        SizedBox(height: 14.h),
        
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: [
            _InfoChip(icon: Icons.access_time_rounded, label: '~${vehicle.etaMinutes} min'),
            const _InfoChip(icon: Icons.payments_outlined, label: 'Cash'),
            _InfoChip(icon: Icons.people_outline_rounded, label: '${vehicle.capacity} seat${vehicle.capacity > 1 ? "s" : ""}'),
          ],
        ),
        
        SizedBox(height: 16.h),
        SizedBox(
          width: double.infinity, height: 52.h.clamp(45.0, 60.0),
          child: ElevatedButton(
            onPressed: _isLoading ? null : _requestRide,
            child: _isLoading
                ? SizedBox(width: 22.r.clamp(20.0, 26.0), height: 22.r.clamp(20.0, 26.0),
                    child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.bolt_rounded, size: 20.r.clamp(18.0, 24.0)),
                    SizedBox(width: 6.w),
                    Text('Request ${vehicle.name}', style: TextStyle(fontSize: 15.sp.clamp(14.0, 18.0), fontWeight: FontWeight.w700)),
                  ]),
          ),
        ),
      ]),
    );
  }
}

// ─── VEHICLE CARD ────────────────────────────────────────────────
class _VehicleCard extends StatelessWidget {
  final VehicleType vehicle;
  final bool        isSelected;
  final VoidCallback onTap;
  const _VehicleCard({required this.vehicle, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: 110.w.clamp(100.0, 130.0), // Clamped card width
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: isSelected ? kGreenLight : kSurface,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: isSelected ? kGreen : kBorder, width: isSelected ? 2 : 1),
          boxShadow: isSelected ? [BoxShadow(color: kGreen.withOpacity(0.18), blurRadius: 12, offset: const Offset(0, 4))] : [],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(vehicle.emoji, style: TextStyle(fontSize: 28.sp.clamp(24.0, 32.0))),
          SizedBox(height: 6.h),
          Text(vehicle.name, style: TextStyle(fontSize: 12.sp.clamp(10.0, 14.0), fontWeight: FontWeight.w700,
            color: isSelected ? kGreenDark : kTextPrimary)),
          SizedBox(height: 2.h),
          Text(vehicle.baseFare, style: TextStyle(fontSize: 12.sp.clamp(10.0, 14.0), fontWeight: FontWeight.w800,
            color: isSelected ? kGreen : kTextPrimary)),
          SizedBox(height: 2.h),
          Text(vehicle.pricePerKm, style: TextStyle(fontSize: 9.sp.clamp(8.0, 11.0), color: kTextSecondary)),
          const Spacer(),
          Row(children: [
            Icon(Icons.access_time_rounded, size: 9.r.clamp(8.0, 12.0), color: kTextSecondary),
            SizedBox(width: 2.w),
            Text('${vehicle.etaMinutes} min', style: TextStyle(fontSize: 9.sp.clamp(8.0, 11.0), color: kTextSecondary)),
          ]),
        ]),
      ),
    );
  }
}

// ─── ROUTE LINE ──────────────────────────────────────────────────
class _RouteLine extends StatelessWidget {
  final IconData icon;
  final Color    iconColor;
  final String   label;
  final String   value;
  const _RouteLine({required this.icon, required this.iconColor, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: iconColor, size: 12.r.clamp(10.0, 16.0)),
      SizedBox(width: 8.w),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 10.sp.clamp(9.0, 12.0), color: kTextSecondary)),
          Text(value, style: TextStyle(fontSize: 12.sp.clamp(11.0, 15.0), fontWeight: FontWeight.w600, color: kTextPrimary),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
    ]);
  }
}

// ─── INFO CHIP ──────────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(color: kGreenLight, borderRadius: BorderRadius.circular(20.r)),
      child: Row(
        mainAxisSize: MainAxisSize.min, // 🔥 FIX: Ye bhi lazmi hai wrap ke andar
        children: [
        Icon(icon, size: 12.r.clamp(10.0, 16.0), color: kGreenDark),
        SizedBox(width: 4.w),
        Text(label, style: TextStyle(fontSize: 11.sp.clamp(10.0, 14.0), fontWeight: FontWeight.w600, color: kGreenDark)),
      ]),
    );
  }
}