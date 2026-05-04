import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../services/auth_service.dart';
import '../widgets/auth_widgets.dart';
import 'otp_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();

  String _selectedRole = 'rider'; // 'rider' | 'driver'
  bool   _isLoading    = false;

  final _authService = AuthService();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final result = await _authService.register(
      fullName:    _nameCtrl.text.trim(),
      email:       _emailCtrl.text.trim(),
      password:    _passCtrl.text,
      phoneNumber: _phoneCtrl.text.trim(),
      role:        _selectedRole,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result.success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OtpScreen(email: result.email ?? _emailCtrl.text.trim()),
        ),
      );
    } else {
      showError(context, result.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Up'),
        leading: const BackButton(),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ────────────────────────────────────────
                const Text('Join EV Ride',
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: kTextPrimary,
                        letterSpacing: -0.5)),
                const SizedBox(height: 4),
                const Text('Create your account to get started.',
                    style: TextStyle(fontSize: 14, color: kTextSecondary)),

                const SizedBox(height: 28),

                // ── Role Toggle ───────────────────────────────────
                const Text('I am registering as',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: kTextPrimary)),
                const SizedBox(height: 8),
                _RoleToggle(
                  selected: _selectedRole,
                  onChanged: (role) => setState(() => _selectedRole = role),
                ),

                const SizedBox(height: 24),

                // ── Fields ────────────────────────────────────────
                AuthTextField(
                  label: 'Full Name',
                  hint: 'Shoaib Khan',
                  icon: Icons.person_outline_rounded,
                  controller: _nameCtrl,
                  validator: (v) =>
                      (v == null || v.trim().length < 2) ? 'Enter your full name' : null,
                ),
                const SizedBox(height: 16),

                AuthTextField(
                  label: 'Email Address',
                  hint: 'shoaib@example.com',
                  icon: Icons.email_outlined,
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Email is required';
                    if (!RegExp(r'\S+@\S+\.\S+').hasMatch(v)) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                AuthTextField(
                  label: 'Password',
                  hint: 'Min. 8 characters',
                  icon: Icons.lock_outline_rounded,
                  controller: _passCtrl,
                  isPassword: true,
                  validator: (v) =>
                      (v == null || v.length < 8) ? 'Password must be at least 8 characters' : null,
                ),
                const SizedBox(height: 16),

                AuthTextField(
                  label: 'Phone Number',
                  hint: '03001234567',
                  icon: Icons.phone_outlined,
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Phone number is required';
                    if (!RegExp(r'^(\+92|0)3[0-9]{9}$').hasMatch(v)) {
                      return 'Enter a valid Pakistani mobile number';
                    }
                    return null;
                  },
                ),

                // ── Driver note ───────────────────────────────────
                if (_selectedRole == 'driver') ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kGreenLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kGreen.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: kGreenDark, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Driver accounts require KYC verification (CNIC + License). You can complete this after registration.',
                            style: TextStyle(fontSize: 12, color: kGreenDark, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 28),

                GreenButton(
                  label: 'Sign Up',
                  onPressed: _handleRegister,
                  isLoading: _isLoading,
                ),

                const SizedBox(height: 20),

                // ── Login link ────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have an account?',
                        style: TextStyle(color: kTextSecondary, fontSize: 14)),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Login',
                          style: TextStyle(
                              color: kGreen, fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Role Toggle Widget ─────────────────────────────────────────────
class _RoleToggle extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _RoleToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          _RoleOption(
            label: '🧑 Customer',
            value: 'rider',
            selected: selected,
            onTap: () => onChanged('rider'),
          ),
          _RoleOption(
            label: '🚗 Driver',
            value: 'driver',
            selected: selected,
            onTap: () => onChanged('driver'),
          ),
        ],
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final VoidCallback onTap;

  const _RoleOption({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected ? kGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [BoxShadow(color: kGreen.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))]
                : [],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : kTextSecondary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
