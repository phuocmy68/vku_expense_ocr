import 'dart:math';
import 'package:flutter/material.dart';

class CategoryPieChart extends StatelessWidget {
  final Map<String, double> categoryData;

  const CategoryPieChart({super.key, required this.categoryData});

  @override
  Widget build(BuildContext context) {
    if (categoryData.isEmpty) {
      return const SizedBox(
        height: 160,
        child: Center(child: Text("Chưa có dữ liệu thống kê")),
      );
    }

    return SizedBox(
      height: 160,
      width: double.infinity,
      child: CustomPaint(
        painter: PieChartPainter(categoryData),
      ),
    );
  }
}

class PieChartPainter extends CustomPainter {
  final Map<String, double> categoryData;

  PieChartPainter(this.categoryData);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2) - 16;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final double totalSum =
        categoryData.values.fold(0, (sum, item) => sum + item);
    if (totalSum == 0) return;

    double startAngle = -pi / 2;
    final List<Color> colors = [
      Colors.orange,
      Colors.blue,
      Colors.purple,
      Colors.teal
    ];
    int colorIndex = 0;

    categoryData.forEach((category, amount) {
      final sweepAngle = (amount / totalSum) * 2 * pi;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 24
        ..color = colors[colorIndex % colors.length];

      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
      colorIndex++;
    });
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
