import 'package:flutter/material.dart';
import 'package:studymate_classroom/utils/app_theme.dart';

enum BlobVariant {
  sageSoft,
  mintWash,
  creamPaper,
  accentPeach,
  tornPaper,
}

/// A container that renders organic, soft-curved watercolor blob and torn-paper aesthetics
/// rather than sharp rigid tech rectangles.
class WatercolorBlobContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BlobVariant variant;
  final Color? customColor;
  final Color? borderColor;
  final double borderWidth;
  final bool hasShadow;
  final VoidCallback? onTap;

  const WatercolorBlobContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.margin,
    this.variant = BlobVariant.creamPaper,
    this.customColor,
    this.borderColor,
    this.borderWidth = 1.2,
    this.hasShadow = true,
    this.onTap,
  });

  BorderRadius _getOrganicRadius() {
    switch (variant) {
      case BlobVariant.sageSoft:
        return const BorderRadius.only(
          topLeft: Radius.elliptical(24, 18),
          topRight: Radius.elliptical(16, 24),
          bottomLeft: Radius.elliptical(22, 28),
          bottomRight: Radius.elliptical(28, 16),
        );
      case BlobVariant.mintWash:
        return const BorderRadius.only(
          topLeft: Radius.elliptical(18, 26),
          topRight: Radius.elliptical(26, 16),
          bottomLeft: Radius.elliptical(28, 20),
          bottomRight: Radius.elliptical(18, 24),
        );
      case BlobVariant.accentPeach:
        return const BorderRadius.only(
          topLeft: Radius.elliptical(22, 18),
          topRight: Radius.elliptical(24, 22),
          bottomLeft: Radius.elliptical(18, 26),
          bottomRight: Radius.elliptical(26, 18),
        );
      case BlobVariant.tornPaper:
        return const BorderRadius.only(
          topLeft: Radius.elliptical(20, 14),
          topRight: Radius.elliptical(14, 22),
          bottomLeft: Radius.elliptical(24, 16),
          bottomRight: Radius.elliptical(16, 24),
        );
      case BlobVariant.creamPaper:
        return const BorderRadius.only(
          topLeft: Radius.elliptical(20, 20),
          topRight: Radius.elliptical(22, 18),
          bottomLeft: Radius.elliptical(18, 24),
          bottomRight: Radius.elliptical(24, 20),
        );
    }
  }

  Color _getBackgroundColor(bool isDark) {
    if (customColor != null) return customColor!;
    if (isDark) {
      switch (variant) {
        case BlobVariant.sageSoft:
          return const Color(0xFF1E3827);
        case BlobVariant.mintWash:
          return const Color(0xFF1B3525);
        case BlobVariant.accentPeach:
          return const Color(0xFF2C221F);
        case BlobVariant.tornPaper:
        case BlobVariant.creamPaper:
          return const Color(0xFF1B2D22);
      }
    } else {
      switch (variant) {
        case BlobVariant.sageSoft:
          return AppTheme.sageBlob.withValues(alpha: 0.22);
        case BlobVariant.mintWash:
          return AppTheme.mintWash.withValues(alpha: 0.35);
        case BlobVariant.accentPeach:
          return AppTheme.accentPeach.withValues(alpha: 0.20);
        case BlobVariant.tornPaper:
          return const Color(0xFFFBF8F2);
        case BlobVariant.creamPaper:
          return Colors.white.withValues(alpha: 0.94);
      }
    }
  }

  Color _getBorderColor(bool isDark) {
    if (borderColor != null) return borderColor!;
    if (isDark) {
      return const Color(0xFF385C42);
    }
    switch (variant) {
      case BlobVariant.sageSoft:
        return const Color(0xFF98B5A3);
      case BlobVariant.mintWash:
        return const Color(0xFFA6CDAB);
      case BlobVariant.accentPeach:
        return const Color(0xFFDF9B8E);
      case BlobVariant.tornPaper:
      case BlobVariant.creamPaper:
        return AppTheme.borderColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = _getOrganicRadius();
    final bg = _getBackgroundColor(isDark);
    final border = _getBorderColor(isDark);

    Widget content = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: radius,
        border: Border.all(color: border, width: borderWidth),
        boxShadow: hasShadow
            ? [
                BoxShadow(
                  color: (isDark ? Colors.black : AppTheme.inkForest).withValues(alpha: isDark ? 0.25 : 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: content,
      );
    }

    return content;
  }
}
