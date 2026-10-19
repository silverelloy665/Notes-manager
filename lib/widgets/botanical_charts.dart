import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:studymate_classroom/utils/app_theme.dart';

class VineChartDataPoint {
  final String label;
  final double value; // 0.0 to 100.0 or score value
  final String? displayValue;

  const VineChartDataPoint({
    required this.label,
    required this.value,
    this.displayValue,
  });
}

/// A progress / mastery line chart styled as a thin dark-green botanical vine with
/// circular leaf-like points, soft watercolor area fill, and Cardo serif typography.
class BotanicalVineLineChart extends StatelessWidget {
  final List<VineChartDataPoint> points;
  final double height;
  final double maxValue;
  final String? chartTitle;

  const BotanicalVineLineChart({
    super.key,
    required this.points,
    this.height = 180,
    this.maxValue = 100,
    this.chartTitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (points.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text('No practice history data available yet.', style: TextStyle(fontFamily: AppTheme.fontZilla)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (chartTitle != null) ...[
          Row(
            children: [
              const Icon(Icons.show_chart_rounded, size: 16, color: AppTheme.inkForest),
              const SizedBox(width: 6),
              Text(
                chartTitle!,
                style: const TextStyle(
                  fontFamily: AppTheme.fontCardo,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.inkForest,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _VineLineChartPainter(
              points: points,
              maxValue: maxValue,
              isDark: isDark,
            ),
          ),
        ),
      ],
    );
  }
}

class _VineLineChartPainter extends CustomPainter {
  final List<VineChartDataPoint> points;
  final double maxValue;
  final bool isDark;

  _VineLineChartPainter({
    required this.points,
    required this.maxValue,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final paddingBottom = 26.0;
    final paddingTop = 20.0;
    final paddingHorizontal = 24.0;
    final chartHeight = size.height - paddingBottom - paddingTop;
    final chartWidth = size.width - (paddingHorizontal * 2);

    final stepX = points.length > 1 ? chartWidth / (points.length - 1) : chartWidth / 2;

    // Build the smooth vine bezier curve path
    final path = Path();
    final fillPath = Path();

    final pointCoords = <Offset>[];
    for (int i = 0; i < points.length; i++) {
      final x = paddingHorizontal + (i * stepX);
      final normalized = (points[i].value / (maxValue <= 0 ? 1 : maxValue)).clamp(0.0, 1.0);
      final y = paddingTop + chartHeight - (normalized * chartHeight);
      pointCoords.add(Offset(x, y));
    }

    path.moveTo(pointCoords.first.dx, pointCoords.first.dy);
    fillPath.moveTo(pointCoords.first.dx, paddingTop + chartHeight);
    fillPath.lineTo(pointCoords.first.dx, pointCoords.first.dy);

    for (int i = 0; i < pointCoords.length - 1; i++) {
      final p0 = pointCoords[i];
      final p1 = pointCoords[i + 1];
      final controlX = (p0.dx + p1.dx) / 2;
      path.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
      fillPath.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
    }

    fillPath.lineTo(pointCoords.last.dx, paddingTop + chartHeight);
    fillPath.close();

    // 1. Draw soft watercolor area wash under the vine
    final areaPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          (isDark ? const Color(0xFF81C784) : AppTheme.mintWash).withValues(alpha: isDark ? 0.35 : 0.45),
          (isDark ? AppTheme.darkSlateBase : AppTheme.creamPaper).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, paddingTop, size.width, chartHeight));
    canvas.drawPath(fillPath, areaPaint);

    // 2. Draw thin dark-green vine line
    final vinePaint = Paint()
      ..color = isDark ? const Color(0xFF81C784) : AppTheme.inkForest
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, vinePaint);

    // 3. Draw baseline guide
    final basePaint = Paint()
      ..color = (isDark ? AppTheme.darkBronzeBorder : AppTheme.borderColor).withValues(alpha: 0.8)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(paddingHorizontal, paddingTop + chartHeight),
      Offset(size.width - paddingHorizontal, paddingTop + chartHeight),
      basePaint,
    );

    // 4. Draw leaf-like circular points and labels
    final pointFill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final pointBorder = Paint()
      ..color = isDark ? const Color(0xFF81C784) : AppTheme.inkForest
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final leafSproutPaint = Paint()
      ..color = isDark ? const Color(0xFFA5D6A7) : AppTheme.tealWash
      ..style = PaintingStyle.fill;

    for (int i = 0; i < pointCoords.length; i++) {
      final pt = pointCoords[i];
      final data = points[i];

      // Draw tiny botanical leaf sprout on every point
      final leaf = Path();
      leaf.moveTo(pt.dx, pt.dy - 4);
      leaf.cubicTo(pt.dx + 6, pt.dy - 12, pt.dx + 10, pt.dy - 8, pt.dx + 4, pt.dy - 3);
      leaf.close();
      canvas.drawPath(leaf, leafSproutPaint);

      // Point circle
      canvas.drawCircle(pt, 5.0, pointFill);
      canvas.drawCircle(pt, 5.0, pointBorder);

      // Value text above point
      final valStr = data.displayValue ?? '${data.value.toInt()}%';
      final valSpan = TextSpan(
        text: valStr,
        style: TextStyle(
          fontFamily: AppTheme.fontCardo,
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          color: isDark ? const Color(0xFFE8F5E9) : AppTheme.inkForest,
        ),
      );
      final valPainter = TextPainter(
        text: valSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      valPainter.paint(canvas, Offset(pt.dx - (valPainter.width / 2), pt.dy - 18));

      // Label below baseline
      final labelSpan = TextSpan(
        text: data.label,
        style: TextStyle(
          fontFamily: AppTheme.fontZilla,
          fontSize: 10.5,
          color: isDark ? const Color(0xFFA5D6A7) : AppTheme.charcoalSlate,
          fontWeight: FontWeight.w600,
        ),
      );
      final labelPainter = TextPainter(
        text: labelSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      labelPainter.paint(canvas, Offset(pt.dx - (labelPainter.width / 2), paddingTop + chartHeight + 6));
    }
  }

  @override
  bool shouldRepaint(covariant _VineLineChartPainter oldDelegate) => true;
}

class DonutSliceData {
  final String label;
  final double value;
  final Color color;

  const DonutSliceData({
    required this.label,
    required this.value,
    required this.color,
  });
}

/// A 3-tone green botanical watercolor donut chart for mastery distribution
/// using Ink Forest (#0F4A22), Eucalyptus (#4C7B5D), and Sage (#A9BC9B).
class BotanicalDonutChart extends StatelessWidget {
  final double masteredPercent;
  final double learningPercent;
  final double reviewDuePercent;
  final double size;
  final String centerTitle;
  final String? centerSubtitle;

  const BotanicalDonutChart({
    super.key,
    required this.masteredPercent,
    required this.learningPercent,
    required this.reviewDuePercent,
    this.size = 170,
    required this.centerTitle,
    this.centerSubtitle = 'Mastery',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 3 tones of botanical green matching design reference
    final colorMastered = isDark ? const Color(0xFF81C784) : AppTheme.inkForest;
    final colorLearning = isDark ? const Color(0xFF4C7B5D) : const Color(0xFF4C7B5D);
    final colorDue = isDark ? const Color(0xFF355843) : AppTheme.sageBlob;

    final slices = [
      DonutSliceData(label: 'Mastered', value: math.max(0.0, masteredPercent), color: colorMastered),
      DonutSliceData(label: 'Learning', value: math.max(0.0, learningPercent), color: colorLearning),
      DonutSliceData(label: 'Due / New', value: math.max(0.0, reviewDuePercent), color: colorDue),
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(size, size),
                painter: _DonutChartPainter(slices: slices),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    centerTitle,
                    style: TextStyle(
                      fontFamily: AppTheme.fontCardo,
                      fontSize: size * 0.16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFFE8F5E9) : AppTheme.inkForest,
                    ),
                  ),
                  if (centerSubtitle != null)
                    Text(
                      centerSubtitle!,
                      style: TextStyle(
                        fontFamily: AppTheme.fontZilla,
                        fontSize: size * 0.08,
                        color: isDark ? const Color(0xFFA5D6A7) : AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 18),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: slices.map((s) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: s.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${s.label}: ${s.value.toInt()}%',
                    style: const TextStyle(
                      fontFamily: AppTheme.fontZilla,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final List<DonutSliceData> slices;

  _DonutChartPainter({required this.slices});

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<double>(0.0, (acc, s) => acc + s.value);
    if (total <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const strokeWidth = 16.0;

    double startAngle = -math.pi / 2;

    for (final slice in slices) {
      final sweepAngle = (slice.value / total) * (math.pi * 2);
      if (sweepAngle <= 0) continue;

      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) => true;
}

