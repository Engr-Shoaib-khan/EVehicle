import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/constants.dart';

class KycUploadScreen extends StatefulWidget {
  const KycUploadScreen({super.key});
  @override
  State<KycUploadScreen> createState() => _KycUploadScreenState();
}

class _KycUploadScreenState extends State<KycUploadScreen> {
  final _picker = ImagePicker();
  File? _cnicFront, _cnicBack, _license, _vehicleReg;
  final _cnicCtrl = TextEditingController();
  final _licenseCtrl = TextEditingController();
  bool _uploading = false;

  Future<void> _pick(String field) async {
    final img = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (img == null) return;
    setState(() {
      if (field == 'cnic_front') _cnicFront = File(img.path);
      if (field == 'cnic_back') _cnicBack = File(img.path);
      if (field == 'license') _license = File(img.path);
      if (field == 'vehicle_reg') _vehicleReg = File(img.path);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('KYC Verification')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(controller: _cnicCtrl, decoration: const InputDecoration(labelText: 'CNIC Number')),
            const SizedBox(height: 20),
            ListTile(title: const Text('CNIC Front'), trailing: const Icon(Icons.upload), onTap: () => _pick('cnic_front')),
            if (_cnicFront != null) Text('Selected: ${_cnicFront!.path.split('/').last}'),
            // ... Baaki buttons bhi isi tarah ...
            const SizedBox(height: 40),
            ElevatedButton(onPressed: () {}, child: const Text('Submit Documents'))
          ],
        ),
      ),
    );
  }
}