import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import 'receipt_screen.dart';

class RideHistoryScreen extends StatefulWidget {
  const RideHistoryScreen({super.key});
  @override
  State<RideHistoryScreen> createState() => _RideHistoryScreenState();
}

class _RideHistoryScreenState extends State<RideHistoryScreen> {
  List<Map<String, dynamic>> _rides = [];
  bool   _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _loadHistory(); }

  Future<void> _loadHistory() async {
    setState(() { _loading = true; _error = null; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(kTokenKey) ?? '';
      final res   = await http.get(
        Uri.parse('$kBaseUrl/api/rides/history/me?limit=30'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() => _rides = List<Map<String, dynamic>>.from(data['data'] ?? []));
      } else {
        setState(() => _error = 'Failed to load history.');
      }
    } catch (e) {
      setState(() => _error = 'Connection error.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        title: const Text('Ride History', style: TextStyle(fontSize: 17.0, fontWeight: FontWeight.w700, color: Color(0xFF0D1B2A))),
        leading: const BackButton(color: Color(0xFF0D1B2A)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded, color: Color(0xFF6B7280)), onPressed: _loadHistory),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420.0),
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: kGreen))
              : _error != null
                  ? _buildError()
                  : _rides.isEmpty
                      ? _buildEmpty()
                      : RefreshIndicator(
                          color: kGreen,
                          onRefresh: _loadHistory,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16.0),
                            itemCount: _rides.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10.0),
                            itemBuilder: (_, i) => _RideTile(ride: _rides[i]),
                          ),
                        ),
        ),
      ),
    );
  }

  Widget _buildEmpty() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Text('🚗', style: TextStyle(fontSize: 48.0)),
    const SizedBox(height: 14.0),
    const Text('No Rides Yet', style: TextStyle(fontSize: 17.0, fontWeight: FontWeight.w700, color: Color(0xFF0D1B2A))),
    const SizedBox(height: 6.0),
    const Text('Your completed and cancelled rides\nwill appear here.', textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13.0, color: Color(0xFF6B7280), height: 1.5)),
  ]));

  Widget _buildError() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.wifi_off_rounded, color: Color(0xFF9CA3AF), size: 44.0),
    const SizedBox(height: 12.0),
    Text(_error!, style: const TextStyle(fontSize: 14.0, color: Color(0xFF6B7280))),
    const SizedBox(height: 16.0),
    ElevatedButton(onPressed: _loadHistory, style: ElevatedButton.styleFrom(backgroundColor: kGreen, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0))),
        child: const Text('Retry')),
  ]));
}

class _RideTile extends StatelessWidget {
  final Map<String, dynamic> ride;
  const _RideTile({required this.ride});

  @override
  Widget build(BuildContext context) {
    final status    = ride['status'] as String? ?? '';
    final completed = status == 'completed';
    final cancelled = status == 'cancelled';
    final fare      = ride['fare'] as Map? ?? {};
    final finalFare = fare['final'] ?? fare['estimated'] ?? 0;
    final pickup    = (ride['pickupLocation']  as Map?)?['address']  as String? ?? 'Pickup';
    final dropoff   = (ride['dropoffLocation'] as Map?)?['address']  as String? ?? 'Drop-off';
    final date      = ride['createdAt'] as String? ?? '';
    final dateStr   = date.isNotEmpty ? date.substring(0, 10) : '—';
    final driver    = ride['driver'] as Map? ?? {};
    final driverName = driver['fullName'] as String? ?? '—';

    return GestureDetector(
      onTap: completed
          ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReceiptScreen(ride: ride)))
          : null,
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(18.0),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8.0, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header row
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: completed ? kGreenLight : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Icon(
                completed ? Icons.check_circle_outline_rounded : Icons.cancel_outlined,
                color: completed ? kGreen : const Color(0xFFEF4444), size: 18.0,
              ),
            ),
            const SizedBox(width: 10.0),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(completed ? 'Completed' : cancelled ? 'Cancelled' : status.replaceAll('_', ' '),
                  style: TextStyle(fontSize: 13.0, fontWeight: FontWeight.w700,
                      color: completed ? kGreen : const Color(0xFFEF4444))),
              Text(dateStr, style: const TextStyle(fontSize: 11.0, color: Color(0xFF9CA3AF))),
            ])),
            if (completed) ...[
              Text('Rs. $finalFare',
                  style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.w800, color: Color(0xFF0D1B2A))),
            ],
          ]),

          const Padding(padding: EdgeInsets.symmetric(vertical: 10.0), child: Divider(height: 1, color: Color(0xFFE5E7EB))),

          // Route
          _RouteChip(icon: Icons.circle, color: kGreen, label: pickup),
          const SizedBox(height: 4.0),
          _RouteChip(icon: Icons.location_on_rounded, color: const Color(0xFFEF4444), label: dropoff),

          if (driverName != '—') ...[
            const SizedBox(height: 10.0),
            Row(children: [
              const Icon(Icons.person_outline_rounded, size: 13.0, color: Color(0xFF9CA3AF)),
              const SizedBox(width: 4.0),
              Text('Driver: $driverName', style: const TextStyle(fontSize: 11.0, color: Color(0xFF6B7280))),
              const Spacer(),
              if (completed) const Row(children: [
                Text('View Receipt', style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.w600, color: kGreen)),
                SizedBox(width: 2.0),
                Icon(Icons.arrow_forward_ios_rounded, size: 10.0, color: kGreen),
              ]),
            ]),
          ],
        ]),
      ),
    );
  }
}

class _RouteChip extends StatelessWidget {
  final IconData icon; final Color color; final String label;
  const _RouteChip({required this.icon, required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, color: color, size: 10.0), const SizedBox(width: 6.0),
    Expanded(child: Text(label, style: const TextStyle(fontSize: 12.0, color: Color(0xFF0D1B2A)), maxLines: 1, overflow: TextOverflow.ellipsis)),
  ]);
}
