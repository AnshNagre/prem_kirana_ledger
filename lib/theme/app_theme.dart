import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Color tokens lifted 1:1 from the HTML file's `:root` / `[data-theme="light"]`
/// CSS custom properties.
class AppColors extends ThemeExtension<AppColors> {
  final Color bgDeep;
  final Color bgSurface;
  final Color bgElevated;
  final Color brandPrimary;
  final Color udhar;
  final Color jama;
  final Color muted;
  final Color borderHairline;
  final Color warning;
  final Color textBody;

  const AppColors({
    required this.bgDeep,
    required this.bgSurface,
    required this.bgElevated,
    required this.brandPrimary,
    required this.udhar,
    required this.jama,
    required this.muted,
    required this.borderHairline,
    required this.warning,
    required this.textBody,
  });

  static const dark = AppColors(
    bgDeep: Color(0xFF000000),
    bgSurface: Color(0xFF0C0D11),
    bgElevated: Color(0xFF121318),
    brandPrimary: Color(0xFFE8A33D),
    udhar: Color(0xFFE23F49),
    jama: Color(0xFF1FAA59),
    muted: Color(0xFF9AA0AC),
    borderHairline: Color(0x1EFFFFFF),
    warning: Color(0xFFF97316),
    textBody: Color(0xFFFFFFFF),
  );

  static const light = AppColors(
    bgDeep: Color(0xFFF7F5F1),
    bgSurface: Color(0xFFFFFFFF),
    bgElevated: Color(0xFFFFFFFF),
    brandPrimary: Color(0xFFB9791F),
    udhar: Color(0xFFC4262F),
    jama: Color(0xFF178A47),
    muted: Color(0xFF5B6270),
    borderHairline: Color(0x1A000000), // rgba(0,0,0,0.10)
    warning: Color(0xFFC2530A),
    textBody: Color(0xFF1A1B1E),
  );

  @override
  AppColors copyWith({
    Color? bgDeep,
    Color? bgSurface,
    Color? bgElevated,
    Color? brandPrimary,
    Color? udhar,
    Color? jama,
    Color? muted,
    Color? borderHairline,
    Color? warning,
    Color? textBody,
  }) {
    return AppColors(
      bgDeep: bgDeep ?? this.bgDeep,
      bgSurface: bgSurface ?? this.bgSurface,
      bgElevated: bgElevated ?? this.bgElevated,
      brandPrimary: brandPrimary ?? this.brandPrimary,
      udhar: udhar ?? this.udhar,
      jama: jama ?? this.jama,
      muted: muted ?? this.muted,
      borderHairline: borderHairline ?? this.borderHairline,
      warning: warning ?? this.warning,
      textBody: textBody ?? this.textBody,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      bgDeep: Color.lerp(bgDeep, other.bgDeep, t)!,
      bgSurface: Color.lerp(bgSurface, other.bgSurface, t)!,
      bgElevated: Color.lerp(bgElevated, other.bgElevated, t)!,
      brandPrimary: Color.lerp(brandPrimary, other.brandPrimary, t)!,
      udhar: Color.lerp(udhar, other.udhar, t)!,
      jama: Color.lerp(jama, other.jama, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      borderHairline: Color.lerp(borderHairline, other.borderHairline, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      textBody: Color.lerp(textBody, other.textBody, t)!,
    );
  }
}

class AppTheme {
  static TextTheme _textTheme(Color body) {
    return GoogleFonts.plusJakartaSansTextTheme().apply(
      bodyColor: body,
      displayColor: body,
    );
  }

  /// Monospace style used for every rupee amount (`.rupee-mono` in the HTML).
  static TextStyle rupeeMono(Color color, {double size = 14, FontWeight weight = FontWeight.w700}) {
    return GoogleFonts.jetBrainsMono(color: color, fontSize: size, fontWeight: weight);
  }

  static ThemeData dark() {
    const c = AppColors.dark;
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: c.bgDeep,
      primaryColor: c.brandPrimary,
      colorScheme: ColorScheme.dark(
        primary: c.brandPrimary,
        surface: c.bgSurface,
        error: c.udhar,
      ),
      textTheme: _textTheme(c.textBody),
      fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
      dividerColor: c.borderHairline,
      extensions: const [AppColors.dark],
    );
  }

  static ThemeData light() {
    const c = AppColors.light;
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: c.bgDeep,
      primaryColor: c.brandPrimary,
      colorScheme: ColorScheme.light(
        primary: c.brandPrimary,
        surface: c.bgSurface,
        error: c.udhar,
      ),
      textTheme: _textTheme(c.textBody),
      fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
      dividerColor: c.borderHairline,
      extensions: const [AppColors.light],
    );
  }
}

/// Convenience accessor: `context.colors.brandPrimary`
extension BuildContextColors on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
