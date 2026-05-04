import 'package:flutter/material.dart';
import '../core/constants.dart';

class PulsePainter extends CustomPainter {
  final double animationValue;
  PulsePainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 3; i >= 1; i--) {
      // Har circle ki opacity aur radius animation ke mutabiq
      final double opacity = (1.0 - (animationValue + i / 3).remainder(1.0)).clamp(0.0, 1.0);
      final double radius = size.width / 2 * ((animationValue + i / 3).remainder(1.0));
      
      final Paint paint = Paint()
        ..color = kGreen.withOpacity(opacity * 0.4)
        ..style = PaintingStyle.fill;
        
      canvas.drawCircle(Offset(size.width / 2, size.height / 2), radius, paint);
    }
  }

  @override
  bool shouldRepaint(PulsePainter oldDelegate) => true;
}