import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../core/constants.dart';
import '../services/auth_service.dart';
import '../widgets/auth_widgets.dart';
import 'home_screen.dart';

class OtpScreen extends StatefulWidget {
  final String email;
  const OtpScreen({super.key, required this.email});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _otpController = TextEditingController();
  final _authService   = AuthService();

  bool _isLoading  = false;
  bool _isResending = false;
  String _otp      = '';

  Future<void> _handleVerify() async {
    if (_otp.length < 6) {
      showError(context, 'Please enter all 6 digits of your code.');
      return;
    }
    setState(() => _isLoading = true);

    final result = await _authService.verifyOtp(
      email: widget.email,
      otp:   _otp,
    );

    setState(() => _isLoading = false);
    if (!mounted) return;

    if (result.success) {
      showSuccess(context, '✅ Registered successfully! Welcome to EV Ride.');
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    } else {
      showError(context, result.message);
    }
  }

  Future<void> _handleResend() async {
    setState(() => _isResending = true);
    final result = await _authService.resendOtp(email: widget.email);
    setState(() => _isResending = false);
    if (!mounted) return;

    if (result.success) {
      showSuccess(context, 'A new code has been sent to your email.');
    } else {
      showError(context, result.message);
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),

              // ── Icon ──────────────────────────────────────────
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: kGreenLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.mark_email_unread_outlined,
                    color: kGreen, size: 36),
              ),

              const SizedBox(height: 20),

              // ── Header ────────────────────────────────────────
              const Text(
                'Verify Your Email',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary,
                    letterSpacing: -0.5),
              ),
              const SizedBox(height: 8),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                      fontSize: 14, color: kTextSecondary, height: 1.5),
                  children: [
                    const TextSpan(text: 'We sent a 6-digit code to\n'),
                    TextSpan(
                      text: widget.email,
                      style: const TextStyle(
                          color: kTextPrimary, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // ── OTP Input ─────────────────────────────────────
              PinCodeTextField(
                appContext: context,
                controller: _otpController,
                length: 6,
                keyboardType: TextInputType.number,
                animationType: AnimationType.scale,
                onChanged: (val) => setState(() => _otp = val),
                onCompleted: (_) => _handleVerify(),
                pinTheme: PinTheme(
                  shape: PinCodeFieldShape.box,
                  borderRadius: BorderRadius.circular(12),
                  fieldHeight: 56,
                  fieldWidth: 46,
                  activeFillColor: kGreenLight,
                  inactiveFillColor: kSurface,
                  selectedFillColor: kGreenLight,
                  activeColor: kGreen,
                  inactiveColor: kBorder,
                  selectedColor: kGreen,
                ),
                enableActiveFill: true,
                cursorColor: kGreen,
                textStyle: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary),
                boxShadows: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ],
              ),

              const SizedBox(height: 28),

              // ── Verify Button ─────────────────────────────────
              GreenButton(
                label: 'Verify & Continue',
                onPressed: _handleVerify,
                isLoading: _isLoading,
              ),

              const SizedBox(height: 20),

              // ── Resend ────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Didn't receive a code? ",
                      style: TextStyle(color: kTextSecondary, fontSize: 14)),
                  _isResending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: kGreen),
                        )
                      : TextButton(
                          onPressed: _handleResend,
                          style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 0),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                          child: const Text('Resend',
                              style: TextStyle(
                                  color: kGreen,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14)),
                        ),
                ],
              ),

              const SizedBox(height: 16),

              Text(
                'Code expires in 10 minutes.',
                style: TextStyle(
                    fontSize: 12,
                    color: kTextSecondary.withOpacity(0.7)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
