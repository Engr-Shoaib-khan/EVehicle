import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/constants.dart'; // Aapke structure ke mutabiq sahi path

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _summary = {
    'today': {'rides': 0, 'earned': 0.0, 'km': 0.0},
    'week': {'rides': 0, 'earned': 0.0, 'km': 0.0},
    'pendingPayout': 0.0,
    'totalPaidOut': 0.0,
  };

  @override
  void initState() {
    super.initState();
    _fetchEarnings();
  }

  Future<void> _fetchEarnings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token'); // Ya kTokenKey use karein agar constants mein hai

      final response = await http.get(
        Uri.parse('$kBaseUrl/api/earnings/summary'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        setState(() {
          _summary = result['data'];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Earnings Error: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Earnings', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: kGreen))
        : RefreshIndicator(
            onRefresh: _fetchEarnings,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBalanceCard(),
                  const SizedBox(height: 25),
                  const Text("Statistics", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  _buildStatsGrid(),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [kGreen, kGreenDark]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: kGreen.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          const Text("Pending Payout", style: TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 10),
          Text("RS ${_summary['pendingPayout']}", 
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              // Payout Request Logic
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: kGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              minimumSize: const Size(150, 45)
            ),
            child: const Text("Withdraw Money", style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      childAspectRatio: 1.2,
      children: [
        _statsTile("Today's Rides", "${_summary['today']['rides']}", Icons.directions_car, Colors.blue),
        _statsTile("Today's Income", "RS ${_summary['today']['earned']}", Icons.account_balance_wallet, Colors.orange),
        _statsTile("Weekly Rides", "${_summary['week']['rides']}", Icons.history, Colors.purple),
        _statsTile("Weekly Income", "RS ${_summary['week']['earned']}", Icons.trending_up, Colors.teal),
      ],
    );
  }

  Widget _statsTile(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}