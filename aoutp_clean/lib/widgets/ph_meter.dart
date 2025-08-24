import 'package:flutter/material.dart';
import 'dart:math';

class PHMeter extends StatelessWidget {
  final double value;

  const PHMeter({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: CustomPaint(
        painter: PHMeterPainter(value),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: _getPHColor(value),
                ),
              ),
              Text(
                'pH',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF7F8C8D),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getPHColor(double ph) {
    if (ph < 6.5) return Colors.red;
    if (ph > 7.5) return Colors.blue;
    return Colors.green;
  }
}

class PHMeterPainter extends CustomPainter {
  final double value;

  PHMeterPainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;

    // Draw background circle
    final backgroundPaint = Paint()
      ..color = Color(0xFFECF0F1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    
    canvas.drawCircle(center, radius, backgroundPaint);

    // Draw pH scale arc
    final scalePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    // pH scale from 0 to 14, but we'll show 4 to 10 for practical purposes
    final startAngle = -pi * 0.75; // Start from top-left
    final sweepAngle = pi * 1.5; // 270 degrees

    // Draw colored segments
    final segments = [
      {'start': 4.0, 'end': 6.5, 'color': Colors.red},
      {'start': 6.5, 'end': 7.5, 'color': Colors.green},
      {'start': 7.5, 'end': 10.0, 'color': Colors.blue},
    ];

    for (var segment in segments) {
      final segmentStart = startAngle +
          (sweepAngle * ((segment['start'] as double) - 4) / 6);
      final segmentSweep = 
          sweepAngle * ((segment['end'] as double) - (segment['start'] as double)) / 6;
      
      scalePaint.color = segment['color'] as Color;
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        segmentStart,
        segmentSweep,
        false,
        scalePaint,
      );
    }

    // Draw needle
    final needleAngle = startAngle + (sweepAngle * (value - 4) / 6);
    final needleLength = radius - 10;
    
    final needlePaint = Paint()
      ..color = Color(0xFF2C3E50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final needleEnd = Offset(
      center.dx + needleLength * cos(needleAngle),
      center.dy + needleLength * sin(needleAngle),
    );

    canvas.drawLine(center, needleEnd, needlePaint);

    // Draw center dot
    final centerPaint = Paint()
      ..color = Color(0xFF2C3E50)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, 6, centerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}