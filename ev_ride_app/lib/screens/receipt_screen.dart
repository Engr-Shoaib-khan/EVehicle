import 'package:flutter/material.dart';
import '../core/constants.dart';

class ReceiptScreen extends StatelessWidget {
  final Map<String, dynamic> ride;
  const ReceiptScreen({super.key, required this.ride});

  @override
  Widget build(BuildContext context) {
    final fare       = ride['fare']  as Map? ?? {};
    final breakdown  = fare['breakdown'] as Map? ?? {};
    final baseFare   = breakdown['baseFare']       ?? 0;
    final distCharge = breakdown['distanceCharge'] ?? 0;
    final platFee    = breakdown['platformFee']    ?? 0;
    final total      = fare['final'] ?? fare['estimated'] ?? 0;
    final distKm     = ride['distanceKm'] ?? 0;
    final durationM  = ride['durationMins'] ?? 0;
    final payment    = ride['paymentMethod'] ?? 'cash';
    final pickup     = (ride['pickupLocation']  as Map?)?['address'] as String? ?? 'Pickup';
    final dropoff    = (ride['dropoffLocation'] as Map?)?['address'] as String? ?? 'Drop-off';
    final driver     = ride['driver'] as Map? ?? {};
    final driverName = driver['fullName'] as String? ?? 'Driver';
    final dateRaw    = ride['completedAt'] ?? ride['createdAt'] ?? '';
    final dateStr    = (dateRaw as String).length >= 10 ? dateRaw.substring(0, 10) : '—';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        title: const Text('E-Receipt', style: TextStyle(fontSize: 17.0, fontWeight: FontWeight.w700, color: Color(0xFF0D1B2A))),
        leading: const BackButton(color: Color(0xFF0D1B2A)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Color(0xFF6B7280)),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Share feature coming soon'), backgroundColor: kGreen, behavior: SnackBarBehavior.floating)),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420.0),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(children: [

              // ── Header ────────────────────────────────────────
              Container(
                width: double.infinity, padding: const EdgeInsets.all(22.0),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [kGreen, kGreenDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(20.0),
                  boxShadow: [BoxShadow(color: kGreen.withOpacity(0.3), blurRadius: 18.0, offset: const Offset(0,6))],
                ),
                child: Column(children: [
                  const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 36.0),
                  const SizedBox(height: 10.0),
                  Text('Rs. $total', style: const TextStyle(color: Colors.white, fontSize: 32.0, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                  const SizedBox(height: 4.0),
                  Text('Paid via ${payment.toUpperCase()}', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12.0)),
                  const SizedBox(height: 4.0),
                  Text(dateStr, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11.0)),
                ]),
              ),

              const SizedBox(height: 18.0),

              // ── Route ─────────────────────────────────────────
              _card(children: [
                _sectionTitle('Trip Route'),
                const SizedBox(height: 12.0),
                _routeRow(Icons.circle, kGreen, 'Pickup', pickup),
                const Padding(padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 5.0),
                    child: Row(children: [SizedBox(width: 2.0, height: 16.0, child: ColoredBox(color: Color(0xFFE5E7EB)))])),
                _routeRow(Icons.location_on_rounded, const Color(0xFFEF4444), 'Drop-off', dropoff),
              ]),

              const SizedBox(height: 12.0),

              // ── Trip Info ─────────────────────────────────────
              _card(children: [
                _sectionTitle('Trip Details'),
                const SizedBox(height: 12.0),
                Row(children: [
                  Expanded(child: _infoBox(icon: Icons.route_rounded, label: 'Distance', value: '${distKm.toStringAsFixed(1)} km')),
                  const SizedBox(width: 10.0),
                  Expanded(child: _infoBox(icon: Icons.access_time_rounded, label: 'Duration', value: '$durationM min')),
                  const SizedBox(width: 10.0),
                  Expanded(child: _infoBox(icon: Icons.person_outline_rounded, label: 'Driver', value: driverName.split(' ').first)),
                ]),
              ]),

              const SizedBox(height: 12.0),

              // ── Fare Breakdown ────────────────────────────────
              _card(children: [
                _sectionTitle('Fare Breakdown'),
                const SizedBox(height: 14.0),
                _fareRow('Base Fare',       'Rs. $baseFare'),
                const SizedBox(height: 8.0),
                _fareRow('Distance Charge', 'Rs. $distCharge'),
                const SizedBox(height: 8.0),
                _fareRow('Platform Fee',    'Rs. $platFee'),
                const Padding(padding: EdgeInsets.symmetric(vertical: 12.0), child: Divider(height: 1, color: Color(0xFFE5E7EB))),
                Row(children: [
                  const Text('Total Paid', style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w800, color: Color(0xFF0D1B2A))),
                  const Spacer(),
                  Text('Rs. $total', style: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.w900, color: kGreen)),
                ]),
              ]),

              const SizedBox(height: 20.0),

              // ── EV note ───────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(14.0),
                decoration: BoxDecoration(color: kGreenLight, borderRadius: BorderRadius.circular(14.0)),
                child: const Row(children: [
                  Icon(Icons.bolt_rounded, color: kGreen, size: 18.0),
                  SizedBox(width: 8.0),
                  Expanded(child: Text('This trip was completed in a 100% Electric Vehicle. Thank you for riding green!',
                      style: TextStyle(fontSize: 12.0, color: kGreenDark, height: 1.4))),
                ]),
              ),
              const SizedBox(height: 24.0),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _card({required List<Widget> children}) => Container(
    width: double.infinity, padding: const EdgeInsets.all(16.0),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8.0, offset: const Offset(0,2))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );

  Widget _sectionTitle(String t) => Text(t, style: const TextStyle(fontSize: 13.0, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)));

  Widget _routeRow(IconData icon, Color color, String label, String val) => Row(children: [
    Icon(icon, color: color, size: 12.0), const SizedBox(width: 8.0),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 10.0, color: Color(0xFF9CA3AF))),
      Text(val, style: const TextStyle(fontSize: 12.0, fontWeight: FontWeight.w600, color: Color(0xFF0D1B2A)), maxLines: 1, overflow: TextOverflow.ellipsis),
    ]),
  ]);

  Widget _infoBox({required IconData icon, required String label, required String value}) => Container(
    padding: const EdgeInsets.all(10.0),
    decoration: BoxDecoration(color: const Color(0xFFF7F9FC), borderRadius: BorderRadius.circular(12.0), border: Border.all(color: const Color(0xFFE5E7EB))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 14.0, color: kGreen),
      const SizedBox(height: 4.0),
      Text(value, style: const TextStyle(fontSize: 13.0, fontWeight: FontWeight.w700, color: Color(0xFF0D1B2A))),
      Text(label, style: const TextStyle(fontSize: 10.0, color: Color(0xFF9CA3AF))),
    ]),
  );

  Widget _fareRow(String label, String val) => Row(children: [
    Text(label, style: const TextStyle(fontSize: 13.0, color: Color(0xFF6B7280))),
    const Spacer(),
    Text(val, style: const TextStyle(fontSize: 13.0, fontWeight: FontWeight.w600, color: Color(0xFF0D1B2A))),
  ]);
}
