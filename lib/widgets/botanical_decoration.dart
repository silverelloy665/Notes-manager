import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:studymate_classroom/utils/app_theme.dart';

/// Renders the authentic botanical watercolor slide aesthetic matching the presentation reference:
/// - Background: soft watercolor washes of mint (#C5DCC6), teal-sage (#9CBFA7), and pale yellow-green on warm cream paper base (#FAF6EE).
/// - Faint ghosted leaf silhouettes & tiny pink/peach paint-splatter dots (#E8A598).
/// - All 4 corners: hand-drawn dark-green botanical line art (top-left & top-right vines with flower tips,
///   bottom-left & bottom-right leafy sprigs).
/// - Floating grey butterfly near the top-left with slow, smooth flight animation (respects prefers-reduced-motion).
/// - Calm mode support: strips decorative line-art & floating elements for zero distraction.
class BotanicalBackground extends StatefulWidget {
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
    this.opacity = 0.90,
  });

  @override
  State<BotanicalBackground> createState() => _BotanicalBackgroundState();
}

class _BotanicalBackgroundState extends State<BotanicalBackground> with SingleTickerProviderStateMixin {
  late AnimationController _butterflyController;

  @override
  void initState() {
    super.initState();
    _butterflyController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _butterflyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return ValueListenableBuilder<bool>(
      valueListenable: AppTheme.calmModeNotifier,
      builder: (context, isCalm, _) {
        if (isCalm) {
          // Calm Mode: Distraction-free clean paper base with zero corner artwork
          return Container(
            color: isDark ? AppTheme.darkSlateBase : AppTheme.creamPaper,
            child: widget.child,
          );
        }

        return Stack(
          children: [
            // 1. Warm cream paper base with watercolor mint/teal-sage washes
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSlateBase : AppTheme.creamPaper,
                  gradient: isDark
                      ? const RadialGradient(
                          center: Alignment(-0.6, -0.7),
                          radius: 1.4,
                          colors: [
                            Color(0xFF1B2E22), // Soft dark sage wash
                            Color(0xFF141E18), // Deep slate base
                            Color(0xFF0F1713),
                          ],
                          stops: [0.0, 0.65, 1.0],
                        )
                      : const RadialGradient(
                          center: Alignment(-0.6, -0.7),
                          radius: 1.4,
                          colors: [
                            Color(0xFFE5EFE4), // Soft mint wash
                            Color(0xFFFAF6EE), // Warm cream paper base
                            Color(0xFFF3EFE6), // Paper texture tint
                          ],
                          stops: [0.0, 0.55, 1.0],
                        ),
                ),
              ),
            ),

            // 2. Botanical vector line art (4 corners, splatter dots, ghosted leaves)
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: widget.opacity,
                  child: CustomPaint(
                    painter: _BotanicalWatercolorPainter(
                      isDark: isDark,
                      showTopVine: widget.showTopVine,
                      showBottomVine: widget.showBottomVine,
                    ),
                  ),
                ),
              ),
            ),

            // 3. Floating grey butterfly near top-left (animated, respects reduce-motion)
            if (widget.showButterfly)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _butterflyController,
                    builder: (context, _) {
                      final animValue = reduceMotion ? 0.0 : _butterflyController.value;
                      final tX = math.sin(animValue * math.pi * 2) * 8.0;
                      final tY = math.cos(animValue * math.pi * 2) * 6.0;
                      final tilt = math.sin(animValue * math.pi * 2) * 0.08;

                      return CustomPaint(
                        painter: _ButterflyPainter(
                          isDark: isDark,
                          offsetX: tX,
                          offsetY: tY,
                          tilt: tilt,
                        ),
                      );
                    },
                  ),
                ),
              ),

            // 4. Foreground Content
            widget.child,
          ],
        );
      },
    );
  }
}

/// CustomPainter rendering authentic botanical corner artwork, faint ghosted leaves, and peach splatter dots.
class _BotanicalWatercolorPainter extends CustomPainter {
  final bool isDark;
  final bool showTopVine;
  final bool showBottomVine;

  _BotanicalWatercolorPainter({
    required this.isDark,
    required this.showTopVine,
    required this.showBottomVine,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Draw faint peach and sage watercolor splatter dots
    _drawWatercolorSplatterDots(canvas, size);

    // Draw faint ghosted leaf silhouettes in background
    _drawGhostedLeaves(canvas, size);

    // 1. Top-Left botanical vine with flower tip
    if (showTopVine) {
      _drawTopLeftVine(canvas, size);
    }

    // 2. Top-Right delicate botanical vine with flower tip
    if (showTopVine && w >= 360) {
      _drawTopRightVine(canvas, size);
    }

    // 3. Bottom-Left leafy sprigs climbing upward with flower bud
    if (showBottomVine) {
      _drawBottomLeftBranch(canvas, size);
    }

    // 4. Bottom-Right leafy sprigs arching inward
    if (showBottomVine && w >= 400 && h >= 250) {
      _drawBottomRightSprig(canvas, size);
    }
  }

  void _drawWatercolorSplatterDots(Canvas canvas, Size size) {
    final dotPeach = Paint()
      ..color = (isDark ? AppTheme.accentPeach.withValues(alpha: 0.18) : AppTheme.accentPeach.withValues(alpha: 0.28))
      ..style = PaintingStyle.fill;

    final dotSage = Paint()
      ..color = (isDark ? AppTheme.mintWash.withValues(alpha: 0.12) : AppTheme.sageBlob.withValues(alpha: 0.22))
      ..style = PaintingStyle.fill;

    // Subtle natural paint splatter spots
    final spots = [
      (0.12, 0.15, 2.2, dotPeach),
      (0.14, 0.18, 1.4, dotPeach),
      (0.16, 0.14, 1.8, dotSage),
      (0.85, 0.12, 2.5, dotPeach),
      (0.88, 0.16, 1.6, dotSage),
      (0.08, 0.78, 2.0, dotPeach),
      (0.11, 0.82, 1.3, dotSage),
      (0.92, 0.85, 2.4, dotPeach),
      (0.94, 0.89, 1.5, dotSage),
      (0.45, 0.08, 1.8, dotSage),
      (0.55, 0.94, 2.0, dotPeach),
    ];

    for (final s in spots) {
      final cx = size.width * s.$1;
      final cy = size.height * s.$2;
      canvas.drawCircle(Offset(cx, cy), s.$3, s.$4);
    }
  }

  void _drawGhostedLeaves(Canvas canvas, Size size) {
    final ghostPaint = Paint()
      ..color = isDark
          ? const Color(0xFF263C2E).withValues(alpha: 0.15)
          : const Color(0xFFC5DCC6).withValues(alpha: 0.20)
      ..style = PaintingStyle.fill;

    // Large faint background leaf watermark near top right
    _drawOrganicLeaf(canvas, size.width * 0.82, 110, 0.5, 70, 32, ghostPaint, null);
    _drawOrganicLeaf(canvas, size.width * 0.86, 140, 0.85, 60, 28, ghostPaint, null);

    // Large faint background leaf watermark near bottom left
    _drawOrganicLeaf(canvas, size.width * 0.15, size.height - 180, -0.7, 75, 34, ghostPaint, null);
  }

  void _drawTopLeftVine(Canvas canvas, Size size) {
    final stemPaint = Paint()
      ..color = isDark ? const Color(0xFF8A9E7A) : AppTheme.inkForest
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final leafFill = Paint()
      ..color = isDark ? const Color(0xFF2A4A35).withValues(alpha: 0.5) : AppTheme.tealWash.withValues(alpha: 0.40)
      ..style = PaintingStyle.fill;

    final leafBorder = Paint()
      ..color = isDark ? const Color(0xFF8A9E7A) : AppTheme.inkForest
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;

    // Main hanging stem
    final stemPath = Path();
    stemPath.moveTo(22, 0);
    stemPath.cubicTo(26, 45, 18, 90, 34, 130);
    stemPath.cubicTo(45, 160, 32, 200, 38, 235);
    canvas.drawPath(stemPath, stemPaint);

    // Secondary curving branch
    final branchPath = Path();
    branchPath.moveTo(24, 70);
    branchPath.cubicTo(50, 95, 75, 120, 82, 165);
    canvas.drawPath(branchPath, stemPaint);

    // Leaves along main hanging stem
    _drawOrganicLeaf(canvas, 18, 40, -0.6, 19, 10, leafFill, leafBorder);
    _drawOrganicLeaf(canvas, 28, 65, 0.5, 21, 10.5, leafFill, leafBorder);
    _drawOrganicLeaf(canvas, 16, 95, -0.8, 23, 11.5, leafFill, leafBorder);
    _drawOrganicLeaf(canvas, 36, 125, 0.7, 24, 11.5, leafFill, leafBorder);
    _drawOrganicLeaf(canvas, 25, 160, -0.5, 22, 10.5, leafFill, leafBorder);
    _drawOrganicLeaf(canvas, 40, 198, 0.4, 20, 10, leafFill, leafBorder);

    // Leaves along secondary branch
    _drawOrganicLeaf(canvas, 48, 90, 0.8, 19, 9, leafFill, leafBorder);
    _drawOrganicLeaf(canvas, 68, 120, 1.1, 21, 10, leafFill, leafBorder);
    _drawOrganicLeaf(canvas, 80, 155, 0.9, 18, 9, leafFill, leafBorder);

    // Blossom flower at vine tips
    _drawFlowerBlossom(canvas, 38, 235, leafBorder, leafFill);
    _drawFlowerBlossom(canvas, 82, 165, leafBorder, leafFill);
  }

  void _drawTopRightVine(Canvas canvas, Size size) {
    final right = size.width;
    final stemPaint = Paint()
      ..color = isDark ? const Color(0xFF8A9E7A) : AppTheme.inkForest
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final leafFill = Paint()
      ..color = isDark ? const Color(0xFF2A4A35).withValues(alpha: 0.45) : AppTheme.mintWash.withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;

    final leafBorder = Paint()
      ..color = isDark ? const Color(0xFF8A9E7A) : AppTheme.inkForest
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final stem = Path();
    stem.moveTo(right - 25, 0);
    stem.cubicTo(right - 30, 40, right - 20, 80, right - 38, 125);
    stem.cubicTo(right - 48, 155, right - 35, 185, right - 42, 215);
    canvas.drawPath(stem, stemPaint);

    _drawOrganicLeaf(canvas, right - 22, 35, 0.6, 18, 9, leafFill, leafBorder);
    _drawOrganicLeaf(canvas, right - 32, 60, -0.5, 20, 10, leafFill, leafBorder);
    _drawOrganicLeaf(canvas, right - 20, 90, 0.7, 21, 10.5, leafFill, leafBorder);
    _drawOrganicLeaf(canvas, right - 38, 120, -0.6, 22, 11, leafFill, leafBorder);
    _drawOrganicLeaf(canvas, right - 28, 155, 0.5, 20, 10, leafFill, leafBorder);
    _drawOrganicLeaf(canvas, right - 42, 188, -0.4, 18, 9, leafFill, leafBorder);

    _drawFlowerBlossom(canvas, right - 42, 215, leafBorder, leafFill);
  }

  void _drawBottomLeftBranch(Canvas canvas, Size size) {
    final bottom = size.height;
    if (bottom <= 120) return;

    final stemPaint = Paint()
      ..color = isDark ? const Color(0xFF8A9E7A) : AppTheme.inkForest
      ..strokeWidth = 2.1
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final leafFill = Paint()
      ..color = isDark ? const Color(0xFF2A4A35).withValues(alpha: 0.5) : AppTheme.sageBlob.withValues(alpha: 0.38)
      ..style = PaintingStyle.fill;

    final leafBorder = Paint()
      ..color = isDark ? const Color(0xFF8A9E7A) : AppTheme.inkForest
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;

    // Stem arching upward from bottom-left corner
    final stem = Path();
    stem.moveTo(0, bottom - 20);
    stem.cubicTo(35, bottom - 60, 60, bottom - 120, 45, bottom - 180);
    stem.cubicTo(35, bottom - 220, 50, bottom - 260, 42, bottom - 295);
    canvas.drawPath(stem, stemPaint);

    // Arching branch to the right
    final branch = Path();
    branch.moveTo(25, bottom - 40);
    branch.cubicTo(65, bottom - 30, 110, bottom - 35, 152, bottom - 22);
    canvas.drawPath(branch, stemPaint);

    // Leaves climbing upward
    _drawOrganicLeaf(canvas, 20, bottom - 70, -1.2, 22, 11, leafFill, leafBorder);
    _drawOrganicLeaf(canvas, 50, bottom - 100, 0.6, 24, 12, leafFill, leafBorder);
    _drawOrganicLeaf(canvas, 48, bottom - 145, -0.9, 23, 11, leafFill, leafBorder);
    _drawOrganicLeaf(canvas, 52, bottom - 190, 0.7, 22, 10, leafFill, leafBorder);
    _drawOrganicLeaf(canvas, 38, bottom - 235, -0.8, 20, 10, leafFill, leafBorder);
    _drawOrganicLeaf(canvas, 46, bottom - 275, 0.5, 18, 9, leafFill, leafBorder);

    // Leaves on right branch
    _drawOrganicLeaf(canvas, 60, bottom - 45, -0.4, 20, 10, leafFill, leafBorder);
    _drawOrganicLeaf(canvas, 95, bottom - 38, 0.4, 21, 10, leafFill, leafBorder);
    _drawOrganicLeaf(canvas, 130, bottom - 28, -0.3, 19, 9, leafFill, leafBorder);

    // Flower buds
    _drawFlowerBlossom(canvas, 42, bottom - 295, leafBorder, leafFill);
    _drawFlowerBlossom(canvas, 152, bottom - 22, leafBorder, leafFill);
  }

  void _drawBottomRightSprig(Canvas canvas, Size size) {
    final right = size.width;
    final bottom = size.height;

    final stemPaint = Paint()
      ..color = isDark ? const Color(0xFF8A9E7A) : AppTheme.inkForest
      ..strokeWidth = 1.9
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final leafFill = Paint()
      ..color = isDark ? const Color(0xFF2A4A35).withValues(alpha: 0.4) : AppTheme.tealWash.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    final leafBorder = Paint()
      ..color = isDark ? const Color(0xFF8A9E7A) : AppTheme.inkForest
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final stem = Path();
    stem.moveTo(right, bottom - 25);
    stem.cubicTo(right - 40, bottom - 50, right - 80, bottom - 45, right - 130, bottom - 25);
    canvas.drawPath(stem, stemPaint);

    _drawOrganicLeaf(canvas, right - 35, bottom - 48, 0.5, 20, 10, leafFill, leafBorder);
    _drawOrganicLeaf(canvas, right - 75, bottom - 44, -0.4, 21, 10.5, leafFill, leafBorder);
    _drawOrganicLeaf(canvas, right - 110, bottom - 32, 0.3, 19, 9, leafFill, leafBorder);

    _drawFlowerBlossom(canvas, right - 130, bottom - 25, leafBorder, leafFill);
  }

  void _drawOrganicLeaf(
    Canvas canvas,
    double x,
    double y,
    double angle,
    double length,
    double width,
    Paint fill,
    Paint? border,
  ) {
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(angle);

    final leaf = Path();
    leaf.moveTo(0, 0);
    leaf.cubicTo(-width * 0.7, length * 0.4, -width * 0.5, length * 0.85, 0, length);
    leaf.cubicTo(width * 0.5, length * 0.85, width * 0.7, length * 0.4, 0, 0);

    canvas.drawPath(leaf, fill);
    if (border != null) {
      canvas.drawPath(leaf, border);

      final veinPaint = Paint()
        ..color = border.color.withValues(alpha: 0.7)
        ..strokeWidth = 0.9
        ..style = PaintingStyle.stroke;
      canvas.drawLine(const Offset(0, 0), Offset(0, length * 0.88), veinPaint);
    }

    canvas.restore();
  }

  void _drawFlowerBlossom(Canvas canvas, double x, double y, Paint border, Paint fill) {
    canvas.save();
    canvas.translate(x, y);

    // Small flower bud with 3 delicate petals matching reference
    final petalPeach = Paint()
      ..color = (isDark ? AppTheme.accentPeach.withValues(alpha: 0.5) : AppTheme.accentPeach.withValues(alpha: 0.65))
      ..style = PaintingStyle.fill;

    final bud = Path();
    bud.moveTo(0, 0);
    bud.cubicTo(-7, 7, -6, 15, 0, 19);
    bud.cubicTo(6, 15, 7, 7, 0, 0);

    canvas.drawPath(bud, fill);
    canvas.drawCircle(const Offset(0, 8), 4, petalPeach);
    canvas.drawPath(bud, border);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Painter rendering the floating grey butterfly near the top-left with animated flight dynamics.
class _ButterflyPainter extends CustomPainter {
  final bool isDark;
  final double offsetX;
  final double offsetY;
  final double tilt;

  _ButterflyPainter({
    required this.isDark,
    required this.offsetX,
    required this.offsetY,
    required this.tilt,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 220) return;
    final baseX = math.min(170.0, size.width * 0.20);
    const baseY = 85.0;

    final cx = baseX + offsetX;
    final cy = baseY + offsetY;

    final wingFill = Paint()
      ..color = isDark
          ? const Color(0xFF6B8B77).withValues(alpha: 0.35)
          : const Color(0xFFB0C4B6).withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;

    final wingBorder = Paint()
      ..color = isDark ? const Color(0xFF8A9E7A) : AppTheme.inkForest
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final detailPaint = Paint()
      ..color = isDark
          ? const Color(0xFF8A9E7A).withValues(alpha: 0.5)
          : AppTheme.inkForest.withValues(alpha: 0.6)
      ..strokeWidth = 0.85
      ..style = PaintingStyle.stroke;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(-0.35 + tilt);

    // Top Upper Wing
    final topWing = Path();
    topWing.moveTo(0, 0);
    topWing.cubicTo(-18, -32, 22, -48, 30, -22);
    topWing.cubicTo(32, -10, 18, -2, 0, 0);
    canvas.drawPath(topWing, wingFill);
    canvas.drawPath(topWing, wingBorder);

    // Wing veining
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

    // Slender Body
    final bodyPaint = Paint()
      ..color = isDark ? const Color(0xFF8A9E7A) : AppTheme.inkForest
      ..strokeWidth = 1.5
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

  @override
  bool shouldRepaint(covariant _ButterflyPainter oldDelegate) =>
      oldDelegate.offsetX != offsetX ||
      oldDelegate.offsetY != offsetY ||
      oldDelegate.tilt != tilt;
}
