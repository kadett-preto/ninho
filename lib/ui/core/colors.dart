import 'package:flutter/material.dart';

// Paleta "Earth & Sand" extraída de DESIGN.md (frontmatter `colors:`).
// Quando o Stitch atualizar tokens, atualizar AQUI e propagar via NinhoTheme.
class NinhoColors {
  NinhoColors._();

  // Surfaces
  static const surface = Color(0xFFFDF9F4);
  static const surfaceDim = Color(0xFFDDD9D5);
  static const surfaceBright = Color(0xFFFDF9F4);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceContainerLow = Color(0xFFF7F3EE);
  static const surfaceContainer = Color(0xFFF1EDE8);
  static const surfaceContainerHigh = Color(0xFFEBE8E3);
  static const surfaceContainerHighest = Color(0xFFE6E2DD);
  static const surfaceVariant = Color(0xFFE6E2DD);
  static const onSurface = Color(0xFF1C1C19);
  static const onSurfaceVariant = Color(0xFF54433E);
  static const inverseSurface = Color(0xFF31302D);
  static const inverseOnSurface = Color(0xFFF4F0EB);
  static const outline = Color(0xFF87736D);
  static const outlineVariant = Color(0xFFDAC1BA);
  static const surfaceTint = Color(0xFF944931);

  // Primary — Terracotta (Treta + ações principais)
  static const primary = Color(0xFF944931);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFFD67D61);
  static const onPrimaryContainer = Color(0xFF551905);
  static const inversePrimary = Color(0xFFFFB59E);
  static const primaryFixed = Color(0xFFFFDBD0);
  static const primaryFixedDim = Color(0xFFFFB59E);
  static const onPrimaryFixed = Color(0xFF3A0B00);
  static const onPrimaryFixedVariant = Color(0xFF76321C);

  // Secondary — Sage (Mamão + conclusão)
  static const secondary = Color(0xFF536346);
  static const onSecondary = Color(0xFFFFFFFF);
  static const secondaryContainer = Color(0xFFD6E9C3);
  static const onSecondaryContainer = Color(0xFF59694B);
  static const secondaryFixed = Color(0xFFD6E9C3);
  static const secondaryFixedDim = Color(0xFFBACCA8);
  static const onSecondaryFixed = Color(0xFF111F08);
  static const onSecondaryFixedVariant = Color(0xFF3C4B30);

  // Tertiary — Sand (Embaçada + secundário)
  static const tertiary = Color(0xFF735B26);
  static const onTertiary = Color(0xFFFFFFFF);
  static const tertiaryContainer = Color(0xFFAD9157);
  static const onTertiaryContainer = Color(0xFF3C2B00);
  static const tertiaryFixed = Color(0xFFFFDF9F);
  static const tertiaryFixedDim = Color(0xFFE2C383);
  static const onTertiaryFixed = Color(0xFF261A00);
  static const onTertiaryFixedVariant = Color(0xFF594410);

  // Error
  static const error = Color(0xFFBA1A1A);
  static const onError = Color(0xFFFFFFFF);
  static const errorContainer = Color(0xFFFFDAD6);
  static const onErrorContainer = Color(0xFF93000A);

  // Background (alias surface)
  static const background = Color(0xFFFDF9F4);
  static const onBackground = Color(0xFF1C1C19);
}
