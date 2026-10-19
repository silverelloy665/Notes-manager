import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Renders the authentic botanical watercolor slide aesthetic matching the presentation PDF:
/// - Hand-crafted vector botanical vines, eucalyptus leaves, and floral sprigs in the corners.
/// - Whimsical fluttering butterfly illustration.
/// - Soft watercolor sage wash gradient background.
class BotanicalBackground extends StatelessWidget {
  final Widget child;
  final bool showButterfly;
  final bool showBottomVine;
  final bool showTopVine;
  final double opacity;

  const BotanicalBackground({
    super.key,
    required this.child,
    this.showButterfly = true,
    this.showBottomVine = true,
    this.showTopVine = true,
    this.opacity = 0.85,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Soft watercolor background gradient wash
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFE9F3EB), // Watercolor sage mist
                  Color(0xFFF3F8F4), // Ivory sage tint
                  Color(0xFFEDF5EF), // Soft eucalyptus wash
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),

        // 2. Botanical vector paintings (Vines, Leaves, Butterfly)
        Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: opacity,
              child: CustomPaint(
                painter: _BotanicalSlidePainter(
                  showTopVine: showTopVine,
                  showBottomVine: showBottomVine,
                  showButterfly: showButterfly,
                ),
              ),
            ),
          ),
        ),

        // 3. Foreground Child Content
        child,
      ],
    );
  }
}

class _BotanicalSlidePainter extends CustomPainter {
  final bool showTopVine;
  final bool showBottomVine;
  final bool showButterfly;

  _BotanicalSlidePainter({
    required this.showTopVine,
    required this.showBottomVine,
    required this.showButterfly,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Top-Left Botanical Vine & Foliage
    if (showTopVine) {
      _drawTopLeftVine(canvas, size);
    }

    // Butterfly
    if (showButterfly) {
      _drawButterfly(canvas, size);
    }

    // Bottom-Left Botanical Sprigs
    if (showBottomVine) {
      _drawBottomLeftBranch(canvas, size);
    }
  }

  void _drawTopLeftVine(Canvas canvas, Size size) {
    final stemPaint = Paint()
      ..color = const Color(0xFF265239)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final leafFill = Paint()
      ..color = const Color(0xFF4C7B5D).withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    final leafBorder = Paint()
      ..color = const Color(0xFF234A35)
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;

    // Main hanging stem
    final stemPath = Path();
    stemPath.moveTo(20, 0);
    stemPath.cubicTo(25, 45, 18, 90, 32, 130);
    stemPath.cubicTo(42, 160, 30, 200, 38, 230);
    canvas.drawPath(stemPath, stemPaint);

    // Secondary curving branch
    final branchPath = Path();
    branchPath.moveTo(24, 70);
    branchPath.cubicTo(50, 95, 75, 120, 80, 165);
    canvas.drawPath(branchPath, stemPaint);

    // Draw leaves along the main hanging stem
    _drawLeaf(canvas, 18, 40, -0.6, 18, 9, leafFill, leafBorder);
    _drawLeaf(canvas, 28, 65, 0.5, 20, 10, leafFill, leafBorder);
    _drawLeaf(canvas, 16, 95, -0.8, 22, 11, leafFill, leafBorder);
    _drawLeaf(canvas, 35, 125, 0.7, 24, 11, leafFill, leafBorder);
    _drawLeaf(canvas, 24, 160, -0.5, 22, 10, leafFill, leafBorder);
    _drawLeaf(canvas, 40, 195, 0.4, 20, 10, leafFill, leafBorder);

    // Draw leaves along secondary branch
    _drawLeaf(canvas, 48, 90, 0.8, 19, 9, leafFill, leafBorder);
    _drawLeaf(canvas, 68, 120, 1.1, 20, 10, leafFill, leafBorder);
    _drawLeaf(canvas, 78, 155, 0.9, 18, 9, leafFill, leafBorder);

    // Hanging flower blossom at tip of branch
    _drawFlowerBud(canvas, 38, 230, leafBorder, leafFill);
    _drawFlowerBud(canvas, 80, 165, leafBorder, leafFill);
  }

  void _drawBottomLeftBranch(Canvas canvas, Size size) {
    final bottom = size.height;
    if (bottom <= 100) return;

    final stemPaint = Paint()
      ..color = const Color(0xFF265239)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final leafFill = Paint()
      ..color = const Color(0xFF5A8E6E).withValues(alpha: 0.38)
      ..style = PaintingStyle.fill;

    final leafBorder = Paint()
      ..color = const Color(0xFF234A35)
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;

    // Soft watercolor corner wash
    final washPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF9DC5AB).withValues(alpha: 0.32),
          const Color(0xFFB8D8C3).withValues(alpha: 0.15),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(30, bottom - 40), radius: 110));
    canvas.drawCircle(Offset(30, bottom - 40), 110, washPaint);

    // Stem arching upward from bottom-left corner
    final stem = Path();
    stem.moveTo(0, bottom - 20);
    stem.cubicTo(35, bottom - 60, 60, bottom - 120, 45, bottom - 180);
    stem.cubicTo(35, bottom - 220, 50, bottom - 260, 40, bottom - 300);
    canvas.drawPath(stem, stemPaint);

    // Arching branch to the right
    final branch = Path();
    branch.moveTo(25, bottom - 40);
    branch.cubicTo(65, bottom - 30, 110, bottom - 35, 150, bottom - 20);
    canvas.drawPath(branch, stemPaint);

    // Leaves climbing upward
    _drawLeaf(canvas, 20, bottom - 70, -1.2, 22, 11, leafFill, leafBorder);
    _drawLeaf(canvas, 50, bottom - 100, 0.6, 24, 12, leafFill, leafBorder);
    _drawLeaf(canvas, 48, bottom - 145, -0.9, 23, 11, leafFill, leafBorder);
    _drawLeaf(canvas, 52, bottom - 190, 0.7, 22, 10, leafFill, leafBorder);
    _drawLeaf(canvas, 38, bottom - 235, -0.8, 20, 10, leafFill, leafBorder);
    _drawLeaf(canvas, 46, bottom - 280, 0.5, 18, 9, leafFill, leafBorder);

    // Leaves on right branch
    _drawLeaf(canvas, 60, bottom - 45, -0.4, 20, 10, leafFill, leafBorder);
    _drawLeaf(canvas, 95, bottom - 38, 0.4, 21, 10, leafFill, leafBorder);
    _drawLeaf(canvas, 130, bottom - 28, -0.3, 19, 9, leafFill, leafBorder);

    // Floral buds
    _drawFlowerBud(canvas, 40, bottom - 300, leafBorder, leafFill);
    _drawFlowerBud(canvas, 150, bottom - 20, leafBorder, leafFill);
  }

  void _drawButterfly(Canvas canvas, Size size) {
    if (size.width < 240) return;
    final cx = math.min(180.0, size.width * 0.22);
    const cy = 90.0;

    final wingFill = Paint()
      ..color = const Color(0xFFC7D9CC).withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final wingBorder = Paint()
      ..color = const Color(0xFF4C7B5D)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final detailPaint = Paint()
      ..color = const Color(0xFF265239).withValues(alpha: 0.6)
      ..strokeWidth = 0.9
      ..style = PaintingStyle.stroke;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(-0.35); // Gentle flight tilt

    // Top Upper Wing
    final topWing = Path();
    topWing.moveTo(0, 0);
    topWing.cubicTo(-18, -32, 22, -48, 30, -22);
    topWing.cubicTo(32, -10, 18, -2, 0, 0);
    canvas.drawPath(topWing, wingFill);
    canvas.drawPath(topWing, wingBorder);

    // Wing detail veining
    final vein1 = Path()..moveTo(0, 0)..cubicTo(8, -16, 16, -26, 26, -32);
    final vein2 = Path()..moveTo(0, 0)..cubicTo(12, -10, 20, -14, 28, -18);
    canvas.drawPath(vein1, detailPaint);
    canvas.drawPath(vein2, detailPaint);

    // Lower Wing
    final lowerWing = Path();
    lowerWing.moveTo(0, 0);
    lowerWing.cubicTo(14, 6, 26, 16, 22, 28);
    lowerWing.cubicTo(14, 34, 4, 20, 0, 0);
    canvas.drawPath(lowerWing, wingFill);
    canvas.drawPath(lowerWing, wingBorder);

    // Butterfly slender body
    final bodyPaint = Paint()
      ..color = const Color(0xFF234A35)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(-2, -12), const Offset(2, 14), bodyPaint);

    // Antennae
    final ant1 = Path()..moveTo(-2, -12)..cubicTo(-6, -20, -10, -24, -14, -22);
    final ant2 = Path()..moveTo(-1, -12)..cubicTo(-2, -22, 2, -26, 4, -26);
    canvas.drawPath(ant1, detailPaint);
    canvas.drawPath(ant2, detailPaint);

    canvas.restore();
  }

  void _drawLeaf(
    Canvas canvas,
    double x,
    double y,
    double angle,
    double length,
    double width,
    Paint fill,
    Paint border,
  ) {
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(angle);

    final leaf = Path();
    leaf.moveTo(0, 0);
    leaf.cubicTo(-width * 0.7, length * 0.4, -width * 0.5, length * 0.85, 0, length);
    leaf.cubicTo(width * 0.5, length * 0.85, width * 0.7, length * 0.4, 0, 0);

    canvas.drawPath(leaf, fill);
    canvas.drawPath(leaf, border);

    // Center vein
    final veinPaint = Paint()
      ..color = border.color.withValues(alpha: 0.7)
      ..strokeWidth = 0.9
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(0, 0), Offset(0, length * 0.9), veinPaint);

    canvas.restore();
  }

  void _drawFlowerBud(Canvas canvas, double x, double y, Paint border, Paint fill) {
    canvas.save();
    canvas.translate(x, y);

    final bud = Path();
    bud.moveTo(0, 0);
    bud.cubicTo(-6, 6, -6, 14, 0, 18);
    bud.cubicTo(6, 14, 6, 6, 0, 0);

    canvas.drawPath(bud, fill);
    canvas.drawPath(bud, border);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
