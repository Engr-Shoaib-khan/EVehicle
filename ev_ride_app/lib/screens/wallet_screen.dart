import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../services/payment_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen>
    with SingleTickerProviderStateMixin {
  final PaymentService _paymentService = PaymentService();
  late final TabController _tabs;

  double   _balance      = 0.0;
  bool     _loadingWallet = true;
  bool     _topUpLoading  = false;
  List<dynamic> _txns    = [];
  String?  _walletError;

  String   _selectedMethod = 'card';
  double?  _customAmount;
  final _customCtrl = TextEditingController();

  static const List<int>    _presets = [200, 500, 1000, 2000, 5000];
  static const List<Map<String, dynamic>> _methods = [
    {'id': 'card',       'label': 'Card',       'emoji': '💳'},
    {'id': 'easypaisa',  'label': 'EasyPaisa',  'emoji': '🟠'},
    {'id': 'jazzcash',   'label': 'JazzCash',   'emoji': '🔴'},
    {'id': 'bank',       'label': 'Bank',        'emoji': '🏦'},
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _fetchWallet();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _customCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchWallet() async {
    setState(() { _loadingWallet = true; _walletError = null; });
    try {
      final result = await _paymentService.getWalletDetails();

      if (result['success'] == true) {
        final d = result['data'] as Map;
        setState(() {
          _balance = (d['walletBalance'] as num).toDouble();
        });
        
        final txnResult = await _paymentService.getTransactions();
        if (txnResult['success'] == true) {
          setState(() => _txns = (txnResult['data'] as List? ?? []));
        }
      } else {
        setState(() => _walletError = result['message'] ?? 'Failed to load wallet.');
      }
    } catch (_) {
      setState(() => _walletError = 'Connection error.');
    } finally {
      if (mounted) setState(() => _loadingWallet = false);
    }
  }

  Future<void> _topUp(int amount) async {
    setState(() => _topUpLoading = true);
    try {
      final result = await _paymentService.topUpWallet(amount.toDouble());

      if (result['success'] == true) {
        _showSnack('Rs. $amount added to wallet!', isSuccess: true);
        _customCtrl.clear();
        _customAmount = null;
        await _fetchWallet();
      } else {
        _showSnack(result['message'] ?? 'Top-up failed.', isSuccess: false);
      }
    } catch (_) {
      _showSnack('Connection error. Please try again.', isSuccess: false);
    } finally {
      if (mounted) setState(() => _topUpLoading = false);
    }
  }

  void _handleCustomTopUp() {
    final amt = int.tryParse(_customCtrl.text.trim());
    if (amt == null || amt < 50) {
      _showSnack('Minimum amount is Rs. 50.', isSuccess: false);
      return;
    }
    _confirmTopUp(amt);
  }

  void _confirmTopUp(int amount) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
        title: const Text('Confirm Top-Up',
            style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _confirmRow('Amount',  'Rs. $amount'),
          const SizedBox(height: 6.0),
          _confirmRow('Method',  _methods.firstWhere((m) => m['id'] == _selectedMethod)['label'] as String),
          const SizedBox(height: 6.0),
          _confirmRow('New Balance', 'Rs. ${(_balance + amount).toStringAsFixed(0)}'),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); _topUp(amount); },
            style: ElevatedButton.styleFrom(
              backgroundColor: kGreen, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0))),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Widget _confirmRow(String label, String val) => Row(children: [
    Text('$label: ', style: const TextStyle(fontSize: 13.0, color: Color(0xFF6B7280))),
    Text(val, style: const TextStyle(fontSize: 13.0, fontWeight: FontWeight.w700, color: Color(0xFF0D1B2A))),
  ]);

  void _showSnack(String msg, {required bool isSuccess}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isSuccess ? kGreen : const Color(0xFFEF4444),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('My Wallet', style: TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        bottom: TabBar(
          controller: _tabs,
          labelColor: kGreen,
          unselectedLabelColor: Colors.grey,
          indicatorColor: kGreen,
          tabs: const [
            Tab(text: 'Top Up'),
            Tab(text: 'Transactions'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildTopUpTab(),
          _buildTransactionsTab(),
        ],
      ),
    );
  }

  Widget _buildTopUpTab() {
    if (_loadingWallet) return const Center(child: CircularProgressIndicator(color: kGreen));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBalanceCard(),
          const SizedBox(height: 30.0),
          const Text('Select Amount', style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w700)),
          const SizedBox(height: 15.0),
          _buildPresetsGrid(),
          const SizedBox(height: 20.0),
          _buildCustomAmountInput(),
          const SizedBox(height: 30.0),
          const Text('Select Payment Method', style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w700)),
          const SizedBox(height: 15.0),
          _buildPaymentMethods(),
          const SizedBox(height: 40.0),
          SizedBox(
            width: double.infinity,
            height: 55.0,
            child: ElevatedButton(
              onPressed: _topUpLoading ? null : _handleCustomTopUp,
              style: ElevatedButton.styleFrom(
                backgroundColor: kGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
              ),
              child: _topUpLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Top Up Now', style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [kGreen, kGreen.withOpacity(0.8)]),
        borderRadius: BorderRadius.circular(25.0),
        boxShadow: [BoxShadow(color: kGreen.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Available Balance', style: TextStyle(color: Colors.white70, fontSize: 14.0)),
          const SizedBox(height: 10.0),
          Text('Rs. ${_balance.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white, fontSize: 32.0, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _buildPresetsGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2.5,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemCount: _presets.length,
      itemBuilder: (context, index) {
        final amt = _presets[index];
        return InkWell(
          onTap: () => _confirmTopUp(amt),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Text('Rs. $amt', style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        );
      },
    );
  }

  Widget _buildCustomAmountInput() {
    return TextField(
      controller: _customCtrl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        hintText: 'Enter custom amount',
        prefixText: 'Rs. ',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15.0)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15.0), borderSide: const BorderSide(color: kGreen)),
      ),
    );
  }

  Widget _buildPaymentMethods() {
    return Column(
      children: _methods.map((m) {
        final isSelected = _selectedMethod == m['id'];
        return InkWell(
          onTap: () => setState(() => _selectedMethod = m['id']),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10.0),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
            decoration: BoxDecoration(
              border: Border.all(color: isSelected ? kGreen : Colors.grey.shade200, width: 2),
              borderRadius: BorderRadius.circular(15.0),
              color: isSelected ? kGreen.withOpacity(0.05) : Colors.transparent,
            ),
            child: Row(
              children: [
                Text(m['emoji'], style: const TextStyle(fontSize: 20.0)),
                const SizedBox(width: 15.0),
                Text(m['label'], style: const TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                if (isSelected) const Icon(Icons.check_circle, color: kGreen),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTransactionsTab() {
    if (_loadingWallet) return const Center(child: CircularProgressIndicator(color: kGreen));
    if (_txns.isEmpty) return const Center(child: Text('No transactions yet.'));

    return ListView.builder(
      itemCount: _txns.length,
      padding: const EdgeInsets.all(20.0),
      itemBuilder: (context, index) {
        final t = _txns[index];
        final isCredit = t['type'] == 'credit';
        return Container(
          margin: const EdgeInsets.only(bottom: 15.0),
          padding: const EdgeInsets.all(15.0),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(15.0),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10.0),
                decoration: BoxDecoration(
                  color: isCredit ? kGreen.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCredit ? Icons.add : Icons.remove,
                  color: isCredit ? kGreen : Colors.red,
                  size: 20.0,
                ),
              ),
              const SizedBox(width: 15.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t['description'] ?? 'Transaction', style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(t['date'] != null ? t['date'].toString().split('T')[0] : '',
                        style: const TextStyle(color: Colors.grey, fontSize: 12.0)),
                  ],
                ),
              ),
              Text(
                '${isCredit ? "+" : "-"} Rs. ${t['amount']}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: isCredit ? kGreen : Colors.red,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
