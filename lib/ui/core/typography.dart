import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';

// Tipografia Montserrat (DESIGN.md §Typography).
//
// Mapeamento dos roles Material 3 para a escala definida no design:
//   displayLarge   <-> display-lg     (40 / 700 / 48)
//   headlineLarge  <-> headline-lg    (28 / 700 / 34)
//   headlineMedium <-> headline-lg-mobile (24 / 700 / 30)
//   titleMedium    <-> title-md       (20 / 600 / 28)
//   bodyLarge      <-> body-lg        (16 / 400 / 24)
//   bodySmall      <-> body-sm        (14 / 400 / 20)
//   labelSmall     <-> label-caps     (12 / 700 / 16 / +1 spacing)
class NinhoTypography {
  NinhoTypography._();

  static TextTheme textTheme() {
    final base = GoogleFonts.montserratTextTheme();
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        height: 48 / 40,
        letterSpacing: -1,
        color: NinhoColors.onSurface,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 34 / 28,
        color: NinhoColors.onSurface,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 30 / 24,
        color: NinhoColors.onSurface,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 28 / 20,
        color: NinhoColors.onSurface,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 24 / 16,
        color: NinhoColors.onSurface,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
        color: NinhoColors.onSurfaceVariant,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        height: 16 / 12,
        letterSpacing: 1,
        color: NinhoColors.onSurfaceVariant,
      ),
    );
  }
}
