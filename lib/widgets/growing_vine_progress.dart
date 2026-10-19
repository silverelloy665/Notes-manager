import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:studymate_classroom/utils/app_theme.dart';

/// Animated growing botanical vine with unfurling leaves instead of a generic circular progress spinner.
/// Used for PDF upload, topic analysis, and question generation stages.
class GrowingVineProgress extends StatefulWidget {
  final String message;
  final String? subMessage;
  final double height;

  const GrowingVineProgress({
    super.key,
    this.message = 'Analyzing document & building topic map...',
    this.subMessage,
    this.height = 140,
  });

  @override
  State<GrowingVineProgress> createState() => _GrowingVineProgressState();
}

class _GrowingVineProgressState extends State<GrowingVineProgress> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 160,
            height: widget.height,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  painter: _GrowingVinePainter(
                    progress: _controller.value,
                    isDark: isDark,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.fontCardo,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? const Color(0xFFE8F5E9) : AppTheme.inkForest,
            ),
          ),
          if (widget.subMessage != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.subMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontZilla,
                fontSize: 12,
                color: isDark ? const Color(0xFFA5D6A7) : AppTheme.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GrowingVinePainter extends CustomPainter {
  final double progress;
  final bool isDark;

  _GrowingVinePainter({required this.progress, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final startY = h - 10;
    final targetY = 15.0;

    final stemPaint = Paint()
      ..color = isDark ? const Color(0xFF81C784) : AppTheme.inkForest
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final leafFill = Paint()
      ..color = isDark ? const Color(0xFF386348) : AppTheme.mintWash
      ..style = PaintingStyle.fill;

    final leafBorder = Paint()
      ..color = isDark ? const Color(0xFF81C784) : AppTheme.inkForest
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final currentY = startY - ((startY - targetY) * progress);

    // Growing wavy vine path
    final vinePath = Path();
    vinePath.moveTo(w / 2, startY);

    final segments = 4;
    final segmentHeight = (startY - targetY) / segments;

    for (int i = 0; i < segments; i++) {
      final segStartY = startY - (i * segmentHeight);
      final segEndY = startY - ((i + 1) * segmentHeight);
      if (segStartY < currentY) break;

      final actualEndY = math.max(segEndY, currentY);
      final wave = (i % 2 == 0 ? 1 : -1) * 14.0;

      vinePath.cubicTo(
        (w / 2) + wave,
        segStartY - (segmentHeight * 0.4),
        (w / 2) - wave,
        segStartY - (segmentHeight * 0.7),
        w / 2,
        actualEndY,
      );

      // Unfurl leaves at milestones
      if (progress > (i + 1) * 0.22) {
        final leafScale = math.min(1.0, (progress - ((i + 1) * 0.22)) * 3.5);
        final leafSide = (i % 2 == 0) ? 1 : -1;
        _drawUnfurlingLeaf(
          canvas,
          w / 2,
          segEndY,
          leafSide * 0.7,
          18 * leafScale,
          9 * leafScale,
          leafFill,
          leafBorder,
        );
      }
    }

    canvas.drawPath(vinePath, stemPaint);

    // Unfurling top sprout bud
    if (progress > 0.05) {
      final budPaint = Paint()
        ..color = isDark ? const Color(0xFFE8A598) : AppTheme.accentPeach
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(w / 2, currentY), 3.5, budPaint);
      canvas.drawCircle(Offset(w / 2, currentY), 3.5, stemPaint);
    }
  }

  void _drawUnfurlingLeaf(
    Canvas canvas,
    double x,
    double y,
    double angle,
    double length,
    double width,
    Paint fill,
    Paint border,
  ) {
    if (length <= 2) return;
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(angle);

    final leaf = Path();
    leaf.moveTo(0, 0);
    leaf.cubicTo(-width * 0.7, length * 0.4, -width * 0.5, length * 0.85, 0, length);
    leaf.cubicTo(width * 0.5, length * 0.85, width * 0.7, length * 0.4, 0, 0);

    canvas.drawPath(leaf, fill);
    canvas.drawPath(leaf, border);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GrowingVinePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.isDark != isDark;
}

