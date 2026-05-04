import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';

class KycUploadScreen extends StatefulWidget {
  const KycUploadScreen({super.key});
  @override
  State<KycUploadScreen> createState() => _KycUploadScreenState();
}

class _KycUploadScreenState extends State<KycUploadScreen> {
  final _picker  = ImagePicker();
  File? _cnicFront, _cnicBack, _license, _vehicleReg;
  final _cnicCtrl    = TextEditingController();
  final _licenseCtrl = TextEditingController();
  bool  _uploading = false;
  String? _successMsg;

  @override
  void dispose() { _cnicCtrl.dispose(); _licenseCtrl.dispose(); super.dispose(); }

  Future<void> _pick(String field) async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.0))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8.0),
        ListTile(leading: const Icon(Icons.camera_alt_rounded), title: const Text('Camera'), onTap: () => Navigator.pop(context, ImageSource.camera)),
        ListTile(leading: const Icon(Icons.photo_library_rounded), title: const Text('Gallery'), onTap: () => Navigator.pop(context, ImageSource.gallery)),
        const SizedBox(height: 8.0),
      ])),
    );
    if (src == null) return;
    final img = await _picker.pickImage(source: src, imageQuality: 80);
    if (img == null) return;
    setState(() {
      final f = File(img.path);
      if (field == 'cnic_front')  _cnicFront = f;
      if (field == 'cnic_back')   _cnicBack  = f;
      if (field == 'license')     _license   = f;
      if (field == 'vehicle_reg') _vehicleReg = f;
    });
  }

  Future<void> _submit() async {
    if (_cnicFront == null || _cnicBack == null || _license == null || _vehicleReg == null) {
      _showSnack('Please upload all 4 documents before submitting.', isError: true); return;
    }
    if (_cnicCtrl.text.trim().isEmpty || _licenseCtrl.text.trim().isEmpty) {
      _showSnack('CNIC and License Number are required.', isError: true); return;
    }
    setState(() => _uploading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(kTokenKey) ?? '';
      final req   = http.MultipartRequest('POST', Uri.parse('$kBaseUrl/api/kyc/upload'));
      req.headers['Authorization'] = 'Bearer $token';
      req.fields['cnic']          = _cnicCtrl.text.trim();
      req.fields['licenseNumber'] = _licenseCtrl.text.trim();
      req.files.add(await http.MultipartFile.fromPath('cnic_front',  _cnicFront!.path));
      req.files.add(await http.MultipartFile.fromPath('cnic_back',   _cnicBack!.path));
      req.files.add(await http.MultipartFile.fromPath('license',     _license!.path));
      req.files.add(await http.MultipartFile.fromPath('vehicle_reg', _vehicleReg!.path));
      final res = await req.send().timeout(const Duration(seconds: 30));
      if (res.statusCode == 200 || res.statusCode == 201) {
        setState(() => _successMsg = 'Documents submitted! Our team will review within 24 hours.');
      } else {
        _showSnack('Upload failed. Please try again.', isError: true);
      }
    } catch (e) {
      _showSnack('Connection error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: isError ? const Color(0xFFEF4444) : kGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        title: const Text('KYC Verification', style: TextStyle(fontSize: 17.0, fontWeight: FontWeight.w700, color: Color(0xFF0D1B2A))),
        leading: const BackButton(color: Color(0xFF0D1B2A)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420.0),
          child: _successMsg != null
              ? _buildSuccess()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Info banner
                    Container(
                      padding: const EdgeInsets.all(14.0),
                      decoration: BoxDecoration(color: kGreenLight, borderRadius: BorderRadius.circular(14.0), border: Border.all(color: kGreen.withOpacity(0.3))),
                      child: const Row(children: [
                        Icon(Icons.verified_user_outlined, color: kGreenDark, size: 18.0),
                        SizedBox(width: 10.0),
                        Expanded(child: Text('Upload clear photos of all documents. Approval takes up to 24 hours.',
                            style: TextStyle(fontSize: 12.0, color: kGreenDark, height: 1.4))),
                      ]),
                    ),
                    const SizedBox(height: 22.0),

                    // CNIC number
                    _fieldLabel('CNIC Number'),
                    const SizedBox(height: 6.0),
                    TextField(
                      controller: _cnicCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 14.0, color: Color(0xFF0D1B2A)),
                      decoration: _inputDeco('e.g. 42101-1234567-1', Icons.badge_outlined),
                    ),
                    const SizedBox(height: 16.0),

                    // License number
                    _fieldLabel('Driving License Number'),
                    const SizedBox(height: 6.0),
                    TextField(
                      controller: _licenseCtrl,
                      style: const TextStyle(fontSize: 14.0, color: Color(0xFF0D1B2A)),
                      decoration: _inputDeco('e.g. LHR-12345678', Icons.credit_card_rounded),
                    ),
                    const SizedBox(height: 22.0),

                    _fieldLabel('Document Photos'),
                    const SizedBox(height: 12.0),

                    _DocUploadTile(label: 'CNIC — Front Side',       icon: Icons.credit_card_rounded, color: const Color(0xFF1565C0), file: _cnicFront,   onTap: () => _pick('cnic_front')),
                    const SizedBox(height: 10.0),
                    _DocUploadTile(label: 'CNIC — Back Side',        icon: Icons.credit_card_outlined, color: const Color(0xFF6A1B9A), file: _cnicBack,    onTap: () => _pick('cnic_back')),
                    const SizedBox(height: 10.0),
                    _DocUploadTile(label: 'Driving License',          icon: Icons.directions_car_rounded, color: const Color(0xFF00897B), file: _license,   onTap: () => _pick('license')),
                    const SizedBox(height: 10.0),
                    _DocUploadTile(label: 'Vehicle Registration',     icon: Icons.description_outlined, color: const Color(0xFFF57F17), file: _vehicleReg, onTap: () => _pick('vehicle_reg')),

                    const SizedBox(height: 28.0),

                    SizedBox(
                      width: double.infinity, height: 54.0,
                      child: ElevatedButton(
                        onPressed: _uploading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kGreen, foregroundColor: Colors.white, elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
                        ),
                        child: _uploading
                            ? const SizedBox(width: 22.0, height: 22.0, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : const Text('Submit for Verification', style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(height: 20.0),
                  ]),
                ),
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 80.0, height: 80.0,
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [kGreen, kGreenDark]), shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: kGreen.withOpacity(0.3), blurRadius: 20.0, offset: const Offset(0,6))]),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 40.0),
        ),
        const SizedBox(height: 20.0),
        const Text('Documents Submitted!', style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.w800, color: Color(0xFF0D1B2A))),
        const SizedBox(height: 10.0),
        Text(_successMsg!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14.0, color: Color(0xFF6B7280), height: 1.5)),
        const SizedBox(height: 28.0),
        SizedBox(width: double.infinity, height: 52.0, child: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(backgroundColor: kGreen, foregroundColor: Colors.white, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.0))),
          child: const Text('Back to Dashboard', style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600)),
        )),
      ]),
    );
  }

  Widget _fieldLabel(String text) => Text(text,
      style: const TextStyle(fontSize: 13.0, fontWeight: FontWeight.w600, color: Color(0xFF0D1B2A)));

  InputDecoration _inputDeco(String hint, IconData icon) => InputDecoration(
    hintText: hint, hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13.0),
    prefixIcon: Icon(icon, size: 18.0, color: const Color(0xFF9CA3AF)),
    filled: true, fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: const BorderSide(color: kGreen, width: 2.0)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 14.0),
  );
}

class _DocUploadTile extends StatelessWidget {
  final String label; final IconData icon; final Color color;
  final File? file; final VoidCallback onTap;
  const _DocUploadTile({required this.label, required this.icon, required this.color, required this.file, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final uploaded = file != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14.0),
        decoration: BoxDecoration(
          color: uploaded ? kGreenLight : Colors.white,
          borderRadius: BorderRadius.circular(14.0),
          border: Border.all(color: uploaded ? kGreen : const Color(0xFFE5E7EB), width: uploaded ? 1.8 : 1.0),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6.0)],
        ),
        child: Row(children: [
          Container(
            width: 44.0, height: 44.0,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12.0)),
            child: uploaded
                ? ClipRRect(borderRadius: BorderRadius.circular(12.0),
                    child: Image.file(file!, fit: BoxFit.cover, width: 44.0, height: 44.0))
                : Icon(icon, color: color, size: 22.0),
          ),
          const SizedBox(width: 14.0),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 13.0, fontWeight: FontWeight.w600, color: Color(0xFF0D1B2A))),
            const SizedBox(height: 2.0),
            Text(uploaded ? 'Tap to change photo' : 'Tap to upload photo',
                style: TextStyle(fontSize: 11.0, color: uploaded ? kGreenDark : const Color(0xFF9CA3AF))),
          ])),
          Icon(uploaded ? Icons.check_circle_rounded : Icons.add_photo_alternate_outlined,
              color: uploaded ? kGreen : const Color(0xFF9CA3AF), size: 22.0),
        ]),
      ),
    );
  }
}
