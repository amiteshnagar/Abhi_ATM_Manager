import 'package:flutter/material.dart';

class CustomLineChart extends StatelessWidget {
  final List<double> data;
  final List<String> labels;
  final String valPrefix;
  final Color lineColor;
  final Color fillColor;

  const CustomLineChart({
    super.key,
    required this.data,
    required this.labels,
    this.valPrefix = '',
    this.lineColor = const Color(0xFF6366F1),
    this.fillColor = const Color(0x336366F1),
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _LineChartPainter(
            data: data,
            labels: labels,
            valPrefix: valPrefix,
            lineColor: lineColor,
            fillColor: fillColor,
            brightness: Theme.of(context).brightness,
          ),
        );
      },
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> data;
  final List<String> labels;
  final String valPrefix;
  final Color lineColor;
  final Color fillColor;
  final Brightness brightness;

  _LineChartPainter({
    required this.data,
    required this.labels,
    required this.valPrefix,
    required this.lineColor,
    required this.fillColor,
    required this.brightness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final double paddingLeft = 40.0;
    final double paddingRight = 15.0;
    final double paddingTop = 20.0;
    final double paddingBottom = 30.0;

    final double chartWidth = size.width - paddingLeft - paddingRight;
    final double chartHeight = size.height - paddingTop - paddingBottom;

    // Find min/max values
    double maxVal = data.reduce((a, b) => a > b ? a : b);
    double minVal = data.reduce((a, b) => a < b ? a : b);
    if (maxVal == minVal) {
      maxVal = maxVal + 10;
      minVal = minVal > 10 ? minVal - 10 : 0;
    }
    
    // Nice rounded max scale
    final double scaleMax = (maxVal / 10).ceil() * 10.0;
    final double scaleMin = (minVal / 10).floor() * 10.0;
    final double range = scaleMax - scaleMin;

    final isDark = brightness == Brightness.dark;
    final gridColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06);
    final textStyle = TextStyle(
      color: isDark ? Colors.grey[400] : Colors.grey[600],
      fontSize: 10,
    );

    // 1. Draw Gridlines and Y Labels
    final Paint gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final int gridLinesCount = 4;
    for (int i = 0; i <= gridLinesCount; i++) {
      final double yRatio = i / gridLinesCount;
      final double y = paddingTop + chartHeight * (1 - yRatio);
      
      // Draw line
      canvas.drawLine(Offset(paddingLeft, y), Offset(size.width - paddingRight, y), gridPaint);
      
      // Draw Y label
      final double val = scaleMin + range * yRatio;
      final textSpan = TextSpan(
        text: '$valPrefix${val.toStringAsFixed(0)}',
        style: textStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      
      textPainter.paint(
        canvas,
        Offset(paddingLeft - textPainter.width - 8, y - textPainter.height / 2),
      );
    }

    // Convert data points to absolute offsets
    final List<Offset> points = [];
    final double xStep = data.length > 1 ? chartWidth / (data.length - 1) : chartWidth;

    for (int i = 0; i < data.length; i++) {
      final double x = paddingLeft + i * xStep;
      final double yRatio = range > 0 ? (data[i] - scaleMin) / range : 0.5;
      final double y = paddingTop + chartHeight * (1 - yRatio);
      points.add(Offset(x, y));
    }

    // 2. Draw Gradient Fill Area Under the Line
    if (points.isNotEmpty) {
      final Path fillPath = Path();
      fillPath.moveTo(points.first.dx, paddingTop + chartHeight);
      
      for (int i = 0; i < points.length; i++) {
        if (i == 0) {
          fillPath.lineTo(points[i].dx, points[i].dy);
        } else {
          // Draw smooth cubic curves
          final prev = points[i - 1];
          final curr = points[i];
          final controlX = (prev.dx + curr.dx) / 2;
          fillPath.cubicTo(controlX, prev.dy, controlX, curr.dy, curr.dx, curr.dy);
        }
      }
      
      fillPath.lineTo(points.last.dx, paddingTop + chartHeight);
      fillPath.close();

      final Paint fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            lineColor.withValues(alpha: 0.4),
            lineColor.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTRB(paddingLeft, paddingTop, size.width - paddingRight, size.height - paddingBottom))
        ..style = PaintingStyle.fill;

      canvas.drawPath(fillPath, fillPaint);
    }

    // 3. Draw the Line Stroke
    if (points.isNotEmpty) {
      final Path linePath = Path();
      linePath.moveTo(points.first.dx, points.first.dy);

      for (int i = 1; i < points.length; i++) {
        final prev = points[i - 1];
        final curr = points[i];
        final controlX = (prev.dx + curr.dx) / 2;
        linePath.cubicTo(controlX, prev.dy, controlX, curr.dy, curr.dx, curr.dy);
      }

      final Paint strokePaint = Paint()
        ..color = lineColor
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(linePath, strokePaint);
    }

    // 4. Draw Dots on Points & X Labels
    final Paint pointPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    final Paint pointStrokePaint = Paint()
      ..color = isDark ? const Color(0xFF0F172A) : Colors.white
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      
      // Draw point circle
      canvas.drawCircle(point, 5.0, pointPaint);
      canvas.drawCircle(point, 5.0, pointStrokePaint);

      // Draw X label (skip labels if list is very crowded)
      final bool shouldDrawLabel = data.length <= 7 || i % (data.length ~/ 4) == 0 || i == data.length - 1;
      
      if (shouldDrawLabel && i < labels.length) {
        final textSpan = TextSpan(
          text: labels[i],
          style: textStyle,
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        )..layout();

        textPainter.paint(
          canvas,
          Offset(point.dx - textPainter.width / 2, size.height - paddingBottom + 8),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class CustomBarChart extends StatelessWidget {
  final List<double> data;
  final List<String> labels;
  final String valPrefix;
  final Color barColor;

  const CustomBarChart({
    super.key,
    required this.data,
    required this.labels,
    this.valPrefix = '',
    this.barColor = const Color(0xFF10B981),
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _BarChartPainter(
            data: data,
            labels: labels,
            valPrefix: valPrefix,
            barColor: barColor,
            brightness: Theme.of(context).brightness,
          ),
        );
      },
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<double> data;
  final List<String> labels;
  final String valPrefix;
  final Color barColor;
  final Brightness brightness;

  _BarChartPainter({
    required this.data,
    required this.labels,
    required this.valPrefix,
    required this.barColor,
    required this.brightness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final double paddingLeft = 40.0;
    final double paddingRight = 15.0;
    final double paddingTop = 20.0;
    final double paddingBottom = 30.0;

    final double chartWidth = size.width - paddingLeft - paddingRight;
    final double chartHeight = size.height - paddingTop - paddingBottom;

    // Find max value
    double maxVal = data.reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) maxVal = 10;
    
    // Scale maximum slightly higher
    final double scaleMax = (maxVal / 10).ceil() * 10.0;

    final isDark = brightness == Brightness.dark;
    final gridColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06);
    final textStyle = TextStyle(
      color: isDark ? Colors.grey[400] : Colors.grey[600],
      fontSize: 10,
    );

    // 1. Draw Gridlines and Y Labels
    final Paint gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final int gridLinesCount = 4;
    for (int i = 0; i <= gridLinesCount; i++) {
      final double yRatio = i / gridLinesCount;
      final double y = paddingTop + chartHeight * (1 - yRatio);
      
      canvas.drawLine(Offset(paddingLeft, y), Offset(size.width - paddingRight, y), gridPaint);
      
      final double val = scaleMax * yRatio;
      final textSpan = TextSpan(
        text: '$valPrefix${val.toStringAsFixed(0)}',
        style: textStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      
      textPainter.paint(
        canvas,
        Offset(paddingLeft - textPainter.width - 8, y - textPainter.height / 2),
      );
    }

    // 2. Draw Bars and X Labels
    final double totalBarSpace = chartWidth / data.length;
    final double barWidth = totalBarSpace * 0.6; // Bar takes 60% of slot width

    for (int i = 0; i < data.length; i++) {
      final double valRatio = data[i] / scaleMax;
      final double barHeight = chartHeight * valRatio;

      final double left = paddingLeft + (i * totalBarSpace) + (totalBarSpace - barWidth) / 2;
      final double top = paddingTop + chartHeight - barHeight;
      final double right = left + barWidth;
      final double bottom = paddingTop + chartHeight;

      // Draw Bar
      final Paint barPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            barColor,
            barColor.withValues(alpha: 0.6),
          ],
        ).createShader(Rect.fromLTRB(left, top, right, bottom))
        ..style = PaintingStyle.fill;

      // Draw bar with top rounded corners
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTRB(left, top, right, bottom),
          topLeft: const Radius.circular(6),
          topRight: const Radius.circular(6),
        ),
        barPaint,
      );

      // Draw X Label
      if (i < labels.length) {
        final textSpan = TextSpan(
          text: labels[i],
          style: textStyle,
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        )..layout();

        textPainter.paint(
          canvas,
          Offset(left + (barWidth - textPainter.width) / 2, size.height - paddingBottom + 8),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
