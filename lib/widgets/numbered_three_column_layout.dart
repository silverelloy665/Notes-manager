import 'package:flutter/material.dart';
import 'package:studymate_classroom/utils/app_theme.dart';
import 'package:studymate_classroom/widgets/watercolor_blob_container.dart';

class NumberedColumnItem {
  final String stepNumber; // '01', '02', '03' or '1', '2', '3'
  final String title;
  final String description;
  final Widget? customContent;
  final VoidCallback? onTap;

  const NumberedColumnItem({
    required this.stepNumber,
    required this.title,
    required this.description,
    this.customContent,
    this.onTap,
  });
}

/// Recreates the slide 4 botanical 3-column layout:
/// Large Cardo serif numerals ('1 / 2 / 3') paired with clean copy blocks on organic watercolor containers.
class NumberedThreeColumnLayout extends StatelessWidget {
  final List<NumberedColumnItem> items;
  final String? sectionTitle;
  final String? sectionSubtitle;

  const NumberedThreeColumnLayout({
    super.key,
    required this.items,
    this.sectionTitle,
    this.sectionSubtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (sectionTitle != null) ...[
          Text(
            sectionTitle!,
            style: const TextStyle(
              fontFamily: AppTheme.fontCardo,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.inkForest,
            ),
          ),
          if (sectionSubtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              sectionSubtitle!,
              style: TextStyle(
                fontFamily: AppTheme.fontZilla,
                fontSize: 12.5,
                color: isDark ? const Color(0xFFA5D6A7) : AppTheme.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 14),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 640;

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: items.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: idx < items.length - 1 ? 12.0 : 0.0,
                      ),
                      child: _buildColumnCard(item, idx, isDark),
                    ),
                  );
                }).toList(),
              );
            }

            // Mobile / Narrow: vertical stack
            return Column(
              children: items.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                return Padding(
                  padding: EdgeInsets.only(bottom: idx < items.length - 1 ? 12.0 : 0.0),
                  child: _buildColumnCard(item, idx, isDark),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildColumnCard(NumberedColumnItem item, int index, bool isDark) {
    final variants = [BlobVariant.creamPaper, BlobVariant.sageSoft, BlobVariant.mintWash];
    final variant = variants[index % variants.length];

    return WatercolorBlobContainer(
      variant: variant,
      onTap: item.onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Large Serif Numeral '1 / 2 / 3'
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                item.stepNumber,
                style: TextStyle(
                  fontFamily: AppTheme.fontCardo,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFF81C784) : AppTheme.inkForest.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 24,
                height: 2,
                decoration: BoxDecoration(
                  color: (isDark ? const Color(0xFF81C784) : AppTheme.sageBlob).withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.title,
            style: const TextStyle(
              fontFamily: AppTheme.fontCardo,
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              color: AppTheme.inkForest,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.description,
            style: TextStyle(
              fontFamily: AppTheme.fontZilla,
              fontSize: 12.5,
              color: isDark ? const Color(0xFFD7EADB) : AppTheme.charcoalSlate,
              height: 1.4,
            ),
          ),
          if (item.customContent != null) ...[
            const SizedBox(height: 10),
            item.customContent!,
          ],
        ],
      ),
    );
  }
}

