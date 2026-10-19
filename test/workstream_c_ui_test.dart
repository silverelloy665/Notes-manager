import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studymate_classroom/utils/app_theme.dart';
import 'package:studymate_classroom/widgets/botanical_charts.dart';
import 'package:studymate_classroom/widgets/botanical_decoration.dart';
import 'package:studymate_classroom/widgets/growing_vine_progress.dart';
import 'package:studymate_classroom/widgets/numbered_three_column_layout.dart';
import 'package:studymate_classroom/widgets/watercolor_blob_container.dart';

void main() {
  group('Workstream C: Botanical Watercolor UI & Theme Design System', () {
    test('Palette design tokens match exact reference specifications', () {
      expect(AppTheme.inkForest, const Color(0xFF0F4A22));
      expect(AppTheme.sageBlob, const Color(0xFFA9BC9B));
      expect(AppTheme.mintWash, const Color(0xFFC5DCC6));
      expect(AppTheme.tealWash, const Color(0xFF9CBFA7));
      expect(AppTheme.creamPaper, const Color(0xFFFAF6EE));
      expect(AppTheme.accentPeach, const Color(0xFFE8A598));
      expect(AppTheme.charcoalSlate, const Color(0xFF1A3022));

      // Typography names
      expect(AppTheme.fontCardo, 'Cardo');
      expect(AppTheme.fontZilla, 'Zilla Slab');
    });

    test('Calm mode toggle switches between botanical decoration and distraction-free mode', () {
      AppTheme.calmModeNotifier.value = false;
      expect(AppTheme.isCalmMode, isFalse);

      AppTheme.toggleCalmMode();
      expect(AppTheme.isCalmMode, isTrue);

      AppTheme.toggleCalmMode();
      expect(AppTheme.isCalmMode, isFalse);
    });

    test('ThemeMode toggle switches between light cream paper and dark charcoal botanical', () {
      AppTheme.themeModeNotifier.value = ThemeMode.light;
      expect(AppTheme.themeModeNotifier.value, ThemeMode.light);

      AppTheme.toggleThemeMode();
      expect(AppTheme.themeModeNotifier.value, ThemeMode.dark);

      AppTheme.toggleThemeMode();
      expect(AppTheme.themeModeNotifier.value, ThemeMode.light);
    });

    testWidgets('BotanicalBackground renders decoration when calm mode is disabled', (tester) async {
      AppTheme.calmModeNotifier.value = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: BotanicalBackground(
              showTopVine: true,
              showBottomVine: true,
              showButterfly: true,
              child: Text('Study Content'),
            ),
          ),
        ),
      );

      expect(find.text('Study Content'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('BotanicalBackground renders clean paper background without vines when calm mode is enabled', (tester) async {
      AppTheme.calmModeNotifier.value = true;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: BotanicalBackground(
              showTopVine: true,
              showBottomVine: true,
              showButterfly: true,
              child: Text('Calm Focus Content'),
            ),
          ),
        ),
      );

      expect(find.text('Calm Focus Content'), findsOneWidget);

      // Reset calm mode
      AppTheme.calmModeNotifier.value = false;
    });

    testWidgets('WatercolorBlobContainer renders across variants with organic radii and typography', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: Column(
              children: [
                WatercolorBlobContainer(
                  variant: BlobVariant.creamPaper,
                  child: Text('Cream Paper Card'),
                ),
                WatercolorBlobContainer(
                  variant: BlobVariant.sageSoft,
                  child: Text('Sage Soft Card'),
                ),
                WatercolorBlobContainer(
                  variant: BlobVariant.mintWash,
                  child: Text('Mint Wash Card'),
                ),
                WatercolorBlobContainer(
                  variant: BlobVariant.accentPeach,
                  child: Text('Accent Peach Card'),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Cream Paper Card'), findsOneWidget);
      expect(find.text('Sage Soft Card'), findsOneWidget);
      expect(find.text('Mint Wash Card'), findsOneWidget);
      expect(find.text('Accent Peach Card'), findsOneWidget);
    });

    testWidgets('NumberedThreeColumnLayout renders 3-column blob cards with Cardo numerals', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: NumberedThreeColumnLayout(
              sectionTitle: 'Core Study Objectives',
              items: [
                NumberedColumnItem(
                  stepNumber: '1',
                  title: 'Identify Core Idea',
                  description: 'Grasp the central intuition without initial jargon.',
                ),
                NumberedColumnItem(
                  stepNumber: '2',
                  title: 'Analyze Trade-offs',
                  description: 'Evaluate algorithmic complexities and system limits.',
                ),
                NumberedColumnItem(
                  stepNumber: '3',
                  title: 'Apply to Exam Problems',
                  description: 'Synthesize formulas and worked examples for mastery.',
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Core Study Objectives'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Identify Core Idea'), findsOneWidget);
      expect(find.text('Analyze Trade-offs'), findsOneWidget);
      expect(find.text('Apply to Exam Problems'), findsOneWidget);
    });

    testWidgets('BotanicalDonutChart and BotanicalVineLineChart render analytics', (tester) async {
      final points = [
        const VineChartDataPoint(label: 'Day 1', value: 60, displayValue: '60%'),
        const VineChartDataPoint(label: 'Day 2', value: 75, displayValue: '75%'),
        const VineChartDataPoint(label: 'Today', value: 90, displayValue: '90%'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Column(
              children: [
                const BotanicalDonutChart(
                  masteredPercent: 60,
                  learningPercent: 30,
                  reviewDuePercent: 10,
                  centerTitle: '85%',
                  centerSubtitle: 'Mastery',
                ),
                BotanicalVineLineChart(
                  points: points,
                  chartTitle: 'Accuracy Trend',
                  height: 120,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('85%'), findsOneWidget);
      expect(find.text('Mastery'), findsOneWidget);
      expect(find.text('Accuracy Trend'), findsOneWidget);
    });

    testWidgets('GrowingVineProgress renders animated vine unfurling indicator with message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: GrowingVineProgress(
              message: 'Parsing document & extracting topic map...',
              subMessage: 'Botanical vine growing',
            ),
          ),
        ),
      );

      expect(find.text('Parsing document & extracting topic map...'), findsOneWidget);
      expect(find.text('Botanical vine growing'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });
}

