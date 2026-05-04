import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/constants.dart';
import 'screens/main_auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/driver_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs    = await SharedPreferences.getInstance();
  final token    = prefs.getString(kTokenKey);
  final userJson = prefs.getString(kUserKey);

  bool   isLoggedIn = token != null && token.isNotEmpty;
  String role       = 'rider';

  if (isLoggedIn && userJson != null) {
    try {
      final user = jsonDecode(userJson) as Map<String, dynamic>;
      role = user['role'] as String? ?? 'rider';
    } catch (e) {
      isLoggedIn = false;
    }
  }

  runApp(EVRideApp(isLoggedIn: isLoggedIn, role: role));
}

class EVRideApp extends StatelessWidget {
  final bool isLoggedIn;
  final String role;

  const EVRideApp({
    super.key, 
    required this.isLoggedIn, 
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            primarySwatch: Colors.green,
            fontFamily: 'Inter',
          ),
          builder: (context, widget) {
            // Web par app ko "Phone Frame" mein dikhane ke liye
            return kIsWeb 
              ? Center(
                  child: Container(
                    width: 420, 
                    margin: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20)],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: widget!,
                    ),
                  ),
                )
              : widget!;
          },
          // 🔥 MAIN ROUTING LOGIC 🔥
          home: isLoggedIn 
              ? (role == 'driver' ? const DriverDashboardScreen() : const HomeScreen())
              : const MainAuthScreen(),
        );
      },
    );
  }
}