import 'package:flutter/material.dart';

/// Application design system and shared Material 3 theme.
/// Recreates the botanical watercolor presentation reference:
/// - Palette: Ink Forest (#0F4A22), Sage Blob (#A9BC9B), Mint Wash (#C5DCC6),
///   Teal Wash (#9CBFA7), Warm Cream Paper (#FAF6EE), Accent Peach (#E8A598).
/// - Typography: Cardo for editorial serif headings, Zilla Slab for body & UI.
/// - Calm Mode: Distraction-free toggle stripping decorative line art and floating elements.
/// - Dark Mode: Charcoal botanical variant.
class AppTheme {
  AppTheme._();

  // Canonical Botanical Watercolor Palette Tokens (Workstream C)
  static const Color inkForest = Color(0xFF0F4A22); // Titles, emphasis, primary buttons
  static const Color sageBlob = Color(0xFFA9BC9B); // Organic card backgrounds & soft washes
  static const Color mintWash = Color(0xFFC5DCC6); // Accents, active indicators, light washes
  static const Color tealWash = Color(0xFF9CBFA7); // Secondary organic blobs
  static const Color creamPaper = Color(0xFFFAF6EE); // Warm cream paper page base
  static const Color accentPeach = Color(0xFFE8A598); // Splatter dots, due badges, gotchas
  static const Color charcoalSlate = Color(0xFF1A3022); // Deep green-charcoal neutral text

  // Dark mode botanical tokens ("Charcoal Botanical")
  static const Color darkSlateBase = Color(0xFF141E18);
  static const Color darkSageCard = Color(0xFF1C2E23);
  static const Color darkMintText = Color(0xFFC5DCC6);
  static const Color darkBronzeBorder = Color(0xFF334F3C);
  static const Color darkLightGreen = Color(0xFF81C784);
  static const Color darkTextPrimary = Color(0xFFE8F5E9);
  static const Color darkTextSecondary = Color(0xFFA5D6A7);

  // Theme-aware helper methods for high-contrast dark/light rendering
  static bool isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;
  static Color primaryHeading(BuildContext context) => isDark(context) ? darkLightGreen : inkForest;
  static Color cardBackground(BuildContext context) => isDark(context) ? darkSageCard : Colors.white;
  static Color pageBase(BuildContext context) => isDark(context) ? darkSlateBase : creamPaper;
  static Color primaryText(BuildContext context) => isDark(context) ? darkTextPrimary : charcoalSlate;
  static Color secondaryText(BuildContext context) => isDark(context) ? darkTextSecondary : textSecondary;
  static Color border(BuildContext context) => isDark(context) ? darkBronzeBorder : borderColor;
  static Color inputBackground(BuildContext context) => isDark(context) ? darkSageCard : Colors.white;
  static Color chipBackground(BuildContext context, bool isSelected) => isSelected
      ? (isDark(context) ? const Color(0xFF2E4D38) : mintWash)
      : (isDark(context) ? darkSageCard : creamPaper);
  static Color chipTextColor(BuildContext context, bool isSelected) => isSelected
      ? (isDark(context) ? darkLightGreen : inkForest)
      : (isDark(context) ? darkTextSecondary : textSecondary);

  // Backward-compatible aliases
  static const Color primaryColor = inkForest;
  static const Color primaryDark = Color(0xFF0A3317);
  static const Color primaryLight = mintWash;
  static const Color secondaryColor = tealWash;
  static const Color accentColor = accentPeach;

  // Surface and background
  static const Color backgroundColor = creamPaper;
  static const Color surfaceColor = Colors.white;
  static const Color cardColor = Colors.white;

  // Neutral tones
  static const Color textPrimary = charcoalSlate;
  static const Color textSecondary = Color(0xFF355843);
  static const Color textMuted = Color(0xFF6B8B77);
  static const Color dividerColor = Color(0xFFDCE8DF);
  static const Color borderColor = Color(0xFFCFE1D4);

  // Status accents
  static const Color successColor = Color(0xFF2E7D32);
  static const Color warningColor = Color(0xFFD97706);
  static const Color errorColor = Color(0xFFC53030);

  // Font Family Tokens
  static const String fontCardo = 'Cardo';
  static const String fontZilla = 'Zilla Slab';

  // Standard metrics
  static const double spacingSm = 8.0;
  static const double spacing = 16.0;
  static const double spacingLg = 24.0;
  static const double borderRadius = 14.0;
  static const double maxFormWidth = 480.0;

  // Interactive Theme & Calm Mode State Notifiers
  static final ValueNotifier<bool> calmModeNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

  static bool get isCalmMode => calmModeNotifier.value;
  static void toggleCalmMode() => calmModeNotifier.value = !calmModeNotifier.value;
  static void toggleThemeMode() {
    themeModeNotifier.value = themeModeNotifier.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }

  /// Global shared ThemeData (Light theme with botanical watercolor aesthetic).
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: inkForest,
      primary: inkForest,
      secondary: secondaryColor,
      surface: surfaceColor,
      error: errorColor,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: creamPaper,
      primaryColor: inkForest,
      fontFamily: fontZilla,
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: fontCardo, fontWeight: FontWeight.bold, color: inkForest),
        displayMedium: TextStyle(fontFamily: fontCardo, fontWeight: FontWeight.bold, color: inkForest),
        displaySmall: TextStyle(fontFamily: fontCardo, fontWeight: FontWeight.bold, color: inkForest),
        headlineLarge: TextStyle(fontFamily: fontCardo, fontWeight: FontWeight.bold, color: inkForest),
        headlineMedium: TextStyle(fontFamily: fontCardo, fontWeight: FontWeight.bold, color: inkForest),
        headlineSmall: TextStyle(fontFamily: fontCardo, fontWeight: FontWeight.bold, color: inkForest),
        titleLarge: TextStyle(fontFamily: fontCardo, fontWeight: FontWeight.w700, color: inkForest),
        titleMedium: TextStyle(fontFamily: fontCardo, fontWeight: FontWeight.w600, color: inkForest),
        titleSmall: TextStyle(fontFamily: fontCardo, fontWeight: FontWeight.w600, color: inkForest),
        bodyLarge: TextStyle(fontFamily: fontZilla, color: charcoalSlate, fontSize: 15),
        bodyMedium: TextStyle(fontFamily: fontZilla, color: charcoalSlate, fontSize: 13.5),
        bodySmall: TextStyle(fontFamily: fontZilla, color: textSecondary, fontSize: 12),
        labelLarge: TextStyle(fontFamily: fontZilla, fontWeight: FontWeight.w600, fontSize: 13),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: creamPaper,
        foregroundColor: inkForest,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontCardo,
          color: inkForest,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
        iconTheme: IconThemeData(color: inkForest),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 1.0,
        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 0.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          side: const BorderSide(color: borderColor, width: 1.2),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        hintStyle: const TextStyle(
          color: textMuted,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: const TextStyle(
          color: textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: inkForest, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: errorColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: errorColor, width: 2),
        ),
        errorMaxLines: 2,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: inkForest,
          foregroundColor: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24), // Botanical rounded pill buttons
          ),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          textStyle: const TextStyle(
            fontFamily: fontZilla,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: inkForest,
          side: const BorderSide(color: inkForest, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          textStyle: const TextStyle(
            fontFamily: fontZilla,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: inkForest,
          textStyle: const TextStyle(
            fontFamily: fontZilla,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: creamPaper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        titleTextStyle: const TextStyle(
          fontFamily: fontCardo,
          color: inkForest,
          fontSize: 19,
          fontWeight: FontWeight.w700,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: creamPaper,
        selectedItemColor: inkForest,
        unselectedItemColor: textMuted,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 6,
        selectedLabelStyle: TextStyle(fontFamily: fontZilla, fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: TextStyle(fontFamily: fontZilla, fontWeight: FontWeight.w500, fontSize: 12),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: creamPaper,
        selectedColor: mintWash,
        labelStyle: const TextStyle(fontFamily: fontZilla, fontSize: 12.5, color: charcoalSlate),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        side: const BorderSide(color: borderColor),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
        backgroundColor: charcoalSlate,
        contentTextStyle: const TextStyle(fontFamily: fontZilla, color: Colors.white, fontSize: 13.5),
      ),
    );
  }

  /// Charcoal Botanical Dark Theme variant.
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: darkLightGreen,
      brightness: Brightness.dark,
      primary: darkLightGreen,
      secondary: tealWash,
      surface: darkSlateBase,
      error: errorColor,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: darkSlateBase,
      primaryColor: darkLightGreen,
      fontFamily: fontZilla,
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: fontCardo, fontWeight: FontWeight.bold, color: darkMintText),
        displayMedium: TextStyle(fontFamily: fontCardo, fontWeight: FontWeight.bold, color: darkMintText),
        displaySmall: TextStyle(fontFamily: fontCardo, fontWeight: FontWeight.bold, color: darkMintText),
        headlineLarge: TextStyle(fontFamily: fontCardo, fontWeight: FontWeight.bold, color: darkMintText),
        headlineMedium: TextStyle(fontFamily: fontCardo, fontWeight: FontWeight.bold, color: darkMintText),
        headlineSmall: TextStyle(fontFamily: fontCardo, fontWeight: FontWeight.bold, color: darkMintText),
        titleLarge: TextStyle(fontFamily: fontCardo, fontWeight: FontWeight.w700, color: darkMintText),
        titleMedium: TextStyle(fontFamily: fontCardo, fontWeight: FontWeight.w600, color: darkMintText),
        titleSmall: TextStyle(fontFamily: fontCardo, fontWeight: FontWeight.w600, color: darkMintText),
        bodyLarge: TextStyle(fontFamily: fontZilla, color: Color(0xFFE8F5E9), fontSize: 15),
        bodyMedium: TextStyle(fontFamily: fontZilla, color: Color(0xFFD7EADB), fontSize: 13.5),
        bodySmall: TextStyle(fontFamily: fontZilla, color: Color(0xFFA5D6A7), fontSize: 12),
        labelLarge: TextStyle(fontFamily: fontZilla, fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFFE8F5E9)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSlateBase,
        foregroundColor: darkMintText,
        elevation: 0,
        titleTextStyle: TextStyle(fontFamily: fontCardo, color: darkMintText, fontSize: 20, fontWeight: FontWeight.bold),
        iconTheme: IconThemeData(color: darkLightGreen),
      ),
      cardTheme: CardThemeData(
        color: darkSageCard,
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 0.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          side: const BorderSide(color: darkBronzeBorder, width: 1.2),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkSageCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: const TextStyle(fontFamily: fontCardo, color: darkMintText, fontSize: 19, fontWeight: FontWeight.bold),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkSageCard,
        selectedItemColor: darkLightGreen,
        unselectedItemColor: Color(0xFF7D9789),
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 6,
        selectedLabelStyle: TextStyle(fontFamily: fontZilla, fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: TextStyle(fontFamily: fontZilla, fontWeight: FontWeight.w500, fontSize: 12),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSageCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        hintStyle: const TextStyle(
          color: darkTextSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: const TextStyle(
          color: darkMintText,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        prefixIconColor: darkLightGreen,
        suffixIconColor: darkTextSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: darkBronzeBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: darkBronzeBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: darkLightGreen, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkSageCard,
        selectedColor: const Color(0xFF2E4D38),
        labelStyle: const TextStyle(fontFamily: fontZilla, fontSize: 12.5, color: darkTextPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        side: const BorderSide(color: darkBronzeBorder),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkLightGreen,
          foregroundColor: darkSlateBase,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          textStyle: const TextStyle(
            fontFamily: fontZilla,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkLightGreen,
          side: const BorderSide(color: darkLightGreen, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          textStyle: const TextStyle(
            fontFamily: fontZilla,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: darkLightGreen,
          textStyle: const TextStyle(
            fontFamily: fontZilla,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
        backgroundColor: darkSageCard,
        contentTextStyle: const TextStyle(fontFamily: fontZilla, color: darkTextPrimary, fontSize: 13.5),
      ),
    );
  }
}
