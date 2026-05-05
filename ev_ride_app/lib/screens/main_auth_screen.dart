import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../core/constants.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class MainAuthScreen extends StatelessWidget {
  const MainAuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE8F5E9), Colors.white],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: 120.r,
                  height: 120.r,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: kGreen.withValues(alpha: 0.2),
                          blurRadius: 30,
                          offset: const Offset(0, 10))
                    ],
                  ),
                  child: Center(
                      child: Icon(Icons.electric_bolt_rounded,
                          size: 60.sp, color: kGreen)),
                ),
                SizedBox(height: 32.h),
                Text("EV Ride",
                    style: TextStyle(
                        fontSize: 32.sp,
                        fontWeight: FontWeight.w900,
                        color: kTextPrimary)),
                Text("Ride the future of mobility.",
                    style: TextStyle(fontSize: 16.sp, color: kTextSecondary)),
                const Spacer(flex: 2),
                _PrimaryButton(
                    label: "Login",
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const LoginScreen()))),
                SizedBox(height: 16.h),
                _SecondaryButton(
                    label: "Create Account",
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const RegisterScreen()))),
                SizedBox(height: 40.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _PrimaryButton({required this.label, required this.onPressed});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 56.h,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
              backgroundColor: kGreen,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r))),
          child: Text(label,
              style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ),
      );
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _SecondaryButton({required this.label, required this.onPressed});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 56.h,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
              side: const BorderSide(color: kGreen, width: 2),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r))),
          child: Text(label,
              style: TextStyle(
                  fontSize: 16.sp, fontWeight: FontWeight.w700, color: kGreen)),
        ),
      );
}
