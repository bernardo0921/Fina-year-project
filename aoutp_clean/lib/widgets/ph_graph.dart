import 'dart:math';

import 'package:flutter/material.dart';

List<double> generatePHData(int count) {
  final random = Random();
  return List.generate(count, (index) {
    // Random value between 5 and 10, centered around 7
    return 7 + (random.nextDouble() - 0.5) * 2; // Range: 6 to 8
  });
}

class PHGraph extends StatelessWidget {
  final List<double> data;

  const PHGraph({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Center(
        child: Text(
          'No data available',
          style: TextStyle(color: Color(0xFF7F8C8D)),
        ),
      );
    }

    return CustomPaint(painter: PHGraphPainter(data), size: Size.infinite);
  }
}

class PHGraphPainter extends CustomPainter {
  final List<double> data;

  PHGraphPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = Color(0xFF3498DB)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = Color(0xFF3498DB).withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final gridPaint = Paint()
      ..color = Color(0xFFECF0F1)
      ..strokeWidth = 1;

    // Draw grid lines
    final gridSpacing = size.height / 6;
    for (int i = 0; i <= 6; i++) {
      final y = i * gridSpacing;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Draw pH reference lines
    final neutralLinePaint = Paint()
      ..color = Colors.green.withOpacity(0.5)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // pH 7 (neutral) line
    final neutralY = size.height - ((7 - 5) / 5) * size.height;
    canvas.drawLine(
      Offset(0, neutralY),
      Offset(size.width, neutralY),
      neutralLinePaint,
    );

    // Create path for the line
    final path = Path();
    final fillPath = Path();

    final stepX = data.length > 1 ? size.width / (data.length - 1) : 0;

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y =
          size.height - ((data[i] - 5) / 5) * size.height; // Scale from pH 5-10

      if (i == 0) {
        path.moveTo(x.toDouble(), y.toDouble());
        fillPath.moveTo(x.toDouble(), size.height.toDouble());
        fillPath.lineTo(x.toDouble(), y.toDouble());
      } else {
        path.lineTo(x.toDouble(), y.toDouble());
        fillPath.lineTo(x.toDouble(), y.toDouble());
      }
    }

    // Complete fill path
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // Draw fill and line
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // Draw data points
    final pointPaint = Paint()
      ..color = Color(0xFF2980B9)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = size.height - ((data[i] - 5) / 5) * size.height;
      canvas.drawCircle(Offset(x.toDouble(), y.toDouble()), 3, pointPaint);
    }

    // Draw labels
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // Y-axis labels (pH values)
    for (int i = 5; i <= 10; i++) {
      final y = size.height - ((i - 5) / 5) * size.height;
      textPainter.text = TextSpan(
        text: i.toString(),
        style: TextStyle(color: Color(0xFF7F8C8D), fontSize: 12),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(-20, y - 6));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
