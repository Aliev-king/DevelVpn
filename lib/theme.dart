import 'package:flutter/material.dart';

/// Central theme mode controller ('system' | 'dark' | 'light').
/// MaterialApp listens to [mode]; AppColors.isLight is resolved in the
/// MaterialApp.builder BEFORE the child (Shell) builds, so a theme flip
/// repaints everything at once without touching navigation state.
class ThemeController {
  static final ValueNotifier<String> mode = ValueNotifier<String>('dark');
  static void set(String m) => mode.value = m;
  static String get current => mode.value;
}

/// Global theme mode for the whole app. Set from Settings; every AppColors /
/// AppText getter switches palettes accordingly.
abstract final class AppColors {
  static bool isLight = false;

  // Backgrounds
  static Color get bg => isLight ? const Color(0xFFF2F2F7) : const Color(0xFF171717);
  static Color get bgDark => isLight ? const Color(0xFFE9E9EF) : const Color(0xFF0A0A0C);
  static List<Color> get bgGradient => isLight
      ? const [Color(0xFFF7F7FA), Color(0xFFF4F4F9), Color(0xFFEDEDF3), Color(0xFFE7E7EE)]
      : const [Color(0xFF171717), Color(0xFF141416), Color(0xFF0D0D0F), Color(0xFF08080A)];

  // Cards & surfaces
  static Color get card => isLight ? const Color(0xFFFFFFFF) : const Color(0xFF232327);
  static Color get cardPress => isLight ? const Color(0xFFF0F0F5) : const Color(0xFF2A2A2F);
  static Color get cardSelected => isLight ? const Color(0xFFE4E9E4) : const Color(0xFF2B2B32);
  static Color get nav => isLight ? const Color(0xFFFFFFFF) : const Color(0xFF222325);
  static Color get chipBorder => isLight ? const Color(0xFFD9D9E0) : const Color(0xFF33333A);
  static Color get inputFill => isLight ? const Color(0xFFF0F0F5) : const Color(0xFF26262B);
  static Color get sheetBg => isLight ? const Color(0xFFFFFFFF) : const Color(0xFF1F1F24);
  static Color get dialogBg => isLight ? const Color(0xFFFFFFFF) : const Color(0xFF232327);
  static Color get blackBg => isLight ? const Color(0xFFF2F2F7) : const Color(0xFF131315);

  // Text
  static Color get textHi => isLight ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F4);
  static Color get textMid => isLight ? const Color(0xFF636368) : const Color(0xFF8E8E93);
  static Color get textLow => isLight ? const Color(0xFF8E8E93) : const Color(0xFF6E6E74);

  // Misc
  static Color get mark => isLight ? const Color(0xFFD1D1D6) : const Color(0xFF3D3D44);
  static Color get green => isLight ? const Color(0xFF2F5847) : const Color(0xFF2F5847);
  static Color get greenBadgeBg => isLight ? const Color(0xFFDCF0E4) : const Color(0x382F5847);
  static Color get graySwitch => isLight ? const Color(0xFFC7C7CC) : const Color(0xFF6E6E74);
  static Color get divider => isLight ? const Color(0x1A000000) : const Color(0x0EFFFFFF);
  static Color get trafficTrack => isLight ? const Color(0xFFE0E0E6) : const Color(0xFF3A3A3F);
  static Color get iconRoundBg => isLight ? const Color(0xFFEBEBF0) : const Color(0xFF26262B);
  static Color get whiteOrBlack => isLight ? const Color(0xFF1C1C1E) : Colors.white;
}

abstract final class AppText {
  static TextStyle get brand => TextStyle(
      fontFamily: 'InterDisplay',
      fontFamilyFallback: ['Inter', 'sans-serif-thin'],
      fontWeight: FontWeight.w100,
      fontSize: 41,
      letterSpacing: -0.3,
      color: AppColors.isLight ? const Color(0xFF1A1A1C) : const Color(0xFFF7F7F8));
  static TextStyle get ip => TextStyle(
      fontFamily: 'InterDisplay',
      fontFamilyFallback: ['Inter', 'sans-serif-light'],
      fontWeight: FontWeight.w200,
      fontSize: 14.5,
      letterSpacing: 0.2,
      color: AppColors.textMid);
  static TextStyle get state => TextStyle(
      fontFamily: 'InterDisplay',
      fontFamilyFallback: ['Inter'],
      fontWeight: FontWeight.w700,
      fontSize: 27,
      letterSpacing: .35,
      color: AppColors.isLight ? const Color(0xFF1A1A1C) : const Color(0xFFFAFAFA));
  static TextStyle get hint => TextStyle(
      fontFamily: 'InterDisplay',
      fontFamilyFallback: ['Inter'],
      fontWeight: FontWeight.w400,
      fontSize: 14.5,
      color: AppColors.textMid);
  static TextStyle get plateName => TextStyle(
      fontFamily: 'InterDisplay',
      fontFamilyFallback: ['Inter'],
      fontWeight: FontWeight.w500,
      fontSize: 14.5,
      color: AppColors.isLight ? const Color(0xFF2A2A2E) : const Color(0xFFF0F0F2));
  static TextStyle get statLabel => TextStyle(
      fontFamily: 'InterDisplay',
      fontFamilyFallback: ['Inter'],
      fontWeight: FontWeight.w400,
      fontSize: 10.5,
      color: AppColors.textMid);
  static TextStyle get statValue => TextStyle(
      fontFamily: 'InterDisplay',
      fontFamilyFallback: ['Inter'],
      fontWeight: FontWeight.w500,
      fontSize: 13.0,
      color: AppColors.isLight ? const Color(0xFF2A2A2E) : const Color(0xFFECECEE));
  static TextStyle get traffic => TextStyle(
      fontFamily: 'InterDisplay',
      fontFamilyFallback: ['Inter'],
      fontWeight: FontWeight.w400,
      fontSize: 10.5,
      color: AppColors.textMid);
  static TextStyle get pageTitle => TextStyle(
      fontFamily: 'InterDisplay',
      fontFamilyFallback: ['Inter'],
      fontWeight: FontWeight.w700,
      fontSize: 30,
      color: AppColors.isLight ? const Color(0xFF1A1A1C) : const Color(0xFFECECEE));
  static TextStyle get pageSub => TextStyle(
      fontFamily: 'InterDisplay',
      fontFamilyFallback: ['Inter'],
      fontWeight: FontWeight.w400,
      fontSize: 14,
      color: AppColors.textMid);
  static TextStyle get rowName => TextStyle(
      fontFamily: 'InterDisplay',
      fontFamilyFallback: ['Inter'],
      fontWeight: FontWeight.w500,
      fontSize: 15,
      color: AppColors.isLight ? const Color(0xFF1C1C1E) : const Color(0xFFE9E9EC));
  static TextStyle get rowSub => TextStyle(
      fontFamily: 'InterDisplay',
      fontFamilyFallback: ['Inter'],
      fontWeight: FontWeight.w400,
      fontSize: 11.5,
      color: AppColors.textMid);
  static TextStyle get rowValue => TextStyle(
      fontFamily: 'InterDisplay',
      fontFamilyFallback: ['Inter'],
      fontWeight: FontWeight.w400,
      fontSize: 13,
      color: AppColors.textMid);
  static TextStyle get secTitle => TextStyle(
      fontFamily: 'InterDisplay',
      fontFamilyFallback: ['Inter'],
      fontWeight: FontWeight.w600,
      fontSize: 11,
      letterSpacing: .9,
      color: AppColors.textLow);
  static TextStyle get cardName => TextStyle(
      fontFamily: 'InterDisplay',
      fontFamilyFallback: ['Inter'],
      fontWeight: FontWeight.w500,
      fontSize: 15.5,
      color: AppColors.isLight ? const Color(0xFF1C1C1E) : const Color(0xFFF5F5F6));
  static TextStyle get cardSub => TextStyle(
      fontFamily: 'InterDisplay',
      fontFamilyFallback: ['Inter'],
      fontWeight: FontWeight.w400,
      fontSize: 11.5,
      color: AppColors.textMid);
  static TextStyle get cardPing => TextStyle(
      fontFamily: 'InterDisplay',
      fontFamilyFallback: ['Inter'],
      fontWeight: FontWeight.w500,
      fontSize: 11.5,
      color: AppColors.textMid);
  static TextStyle get subName => TextStyle(
      fontFamily: 'InterDisplay',
      fontFamilyFallback: ['Inter'],
      fontWeight: FontWeight.w600,
      fontSize: 15,
      color: AppColors.isLight ? const Color(0xFF1C1C1E) : const Color(0xFFECECEE));
  static TextStyle get subDesc => TextStyle(
      fontFamily: 'InterDisplay',
      fontFamilyFallback: ['Inter'],
      fontWeight: FontWeight.w400,
      fontSize: 11.5,
      height: 1.5,
      color: AppColors.textMid);
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: AppColors.isLight ? Brightness.light : Brightness.dark,
    scaffoldBackgroundColor: AppColors.bg,
    fontFamily: 'InterDisplay',
    fontFamilyFallback: const ['Inter'],
    textTheme: const TextTheme().apply(
      fontFamily: 'InterDisplay',
      bodyColor: AppColors.textHi,
      displayColor: AppColors.textHi,
    ),
    colorScheme: AppColors.isLight
        ? ColorScheme.light(
            surface: const Color(0xFFF2F2F7),
            primary: const Color(0xFF1C1C1E),
            secondary: AppColors.green,
          )
        : ColorScheme.dark(
            surface: AppColors.bg,
            primary: AppColors.textHi,
            secondary: AppColors.green,
          ),
  );
}
