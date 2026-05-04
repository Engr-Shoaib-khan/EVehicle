import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../services/auth_service.dart';
import '../widgets/auth_widgets.dart';
import 'home_screen.dart';
import 'otp_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final result = await _authService.login(
      email:    _emailCtrl.text.trim(),
      password: _passCtrl.text,
    );

    setState(() => _isLoading = false);
    if (!mounted) return;

    if (result.success) {
      // Token already saved by AuthService
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    } else if (result.requiresOtp) {
      // Server resent OTP automatically — redirect to OTP screen
      showError(context, result.message);
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      Navigator.push(
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
        title: const Text('Login'),
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
                const Text('Welcome Back',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: kTextPrimary,
                        letterSpacing: -0.6)),
                const SizedBox(height: 4),
                const Text('Log in to your EV Ride account.',
                    style: TextStyle(fontSize: 14, color: kTextSecondary)),

                const SizedBox(height: 32),

                // ── Fields ────────────────────────────────────────
                AuthTextField(
                  label: 'Email Address',
                  hint: 'shoaib@example.com',
                  icon: Icons.email_outlined,
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Email is required';
                    if (!RegExp(r'\S+@\S+\.\S+').hasMatch(v)) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                AuthTextField(
                  label: 'Password',
                  hint: 'Enter your password',
                  icon: Icons.lock_outline_rounded,
                  controller: _passCtrl,
                  isPassword: true,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Password is required' : null,
                ),

                // ── Forgot password link ──────────────────────────
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      // TODO: forgot password flow
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Coming soon!')),
                      );
                    },
                    child: const Text('Forgot Password?',
                        style: TextStyle(
                            color: kGreen,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                  ),
                ),

                const SizedBox(height: 8),

                GreenButton(
                  label: 'Login',
                  onPressed: _handleLogin,
                  isLoading: _isLoading,
                ),

                const SizedBox(height: 16),

                Row(children: [
                  Expanded(child: Divider(color: kBorder, thickness: 1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('or',
                        style: TextStyle(color: kTextSecondary, fontSize: 13)),
                  ),
                  Expanded(child: Divider(color: kBorder, thickness: 1)),
                ]),

                const SizedBox(height: 16),

                GoogleSignInButton(onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Google Sign-In coming soon!')),
                  );
                }),

                const SizedBox(height: 28),

                // ── Register link ─────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account?",
                        style: TextStyle(color: kTextSecondary, fontSize: 14)),
                    TextButton(
                      onPressed: () => Navigator.pushReplacement(context,
                          MaterialPageRoute(builder: (_) => const RegisterScreen())),
                      child: const Text('Sign Up',
                          style: TextStyle(
                              color: kGreen,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
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
