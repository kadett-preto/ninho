import 'package:flutter/material.dart';

import 'colors.dart';
import 'spacing.dart';
import 'typography.dart';

// Tema "Harmonia Lar" (DESIGN.md). Source-of-truth visual = Stitch + DESIGN.md.
// Quando tokens mudarem, atualizar arquivos em lib/ui/core/ e propagar aqui.
class NinhoTheme {
  NinhoTheme._();

  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: NinhoColors.primary,
      onPrimary: NinhoColors.onPrimary,
      primaryContainer: NinhoColors.primaryContainer,
      onPrimaryContainer: NinhoColors.onPrimaryContainer,
      inversePrimary: NinhoColors.inversePrimary,
      secondary: NinhoColors.secondary,
      onSecondary: NinhoColors.onSecondary,
      secondaryContainer: NinhoColors.secondaryContainer,
      onSecondaryContainer: NinhoColors.onSecondaryContainer,
      tertiary: NinhoColors.tertiary,
      onTertiary: NinhoColors.onTertiary,
      tertiaryContainer: NinhoColors.tertiaryContainer,
      onTertiaryContainer: NinhoColors.onTertiaryContainer,
      error: NinhoColors.error,
      onError: NinhoColors.onError,
      errorContainer: NinhoColors.errorContainer,
      onErrorContainer: NinhoColors.onErrorContainer,
      surface: NinhoColors.surface,
      onSurface: NinhoColors.onSurface,
      onSurfaceVariant: NinhoColors.onSurfaceVariant,
      surfaceContainerLowest: NinhoColors.surfaceContainerLowest,
      surfaceContainerLow: NinhoColors.surfaceContainerLow,
      surfaceContainer: NinhoColors.surfaceContainer,
      surfaceContainerHigh: NinhoColors.surfaceContainerHigh,
      surfaceContainerHighest: NinhoColors.surfaceContainerHighest,
      surfaceDim: NinhoColors.surfaceDim,
      surfaceBright: NinhoColors.surfaceBright,
      inverseSurface: NinhoColors.inverseSurface,
      onInverseSurface: NinhoColors.inverseOnSurface,
      outline: NinhoColors.outline,
      outlineVariant: NinhoColors.outlineVariant,
      surfaceTint: NinhoColors.surfaceTint,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: NinhoTypography.textTheme(),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NinhoRadii.lg),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: NinhoSpacing.stackLg,
            vertical: NinhoSpacing.stackMd,
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NinhoRadii.lg),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: NinhoSpacing.stackLg,
            vertical: NinhoSpacing.stackMd,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: NinhoColors.surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NinhoRadii.xl),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: NinhoColors.surfaceContainer,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(NinhoRadii.lg)),
          borderSide: BorderSide.none,
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: NinhoColors.surface,
        foregroundColor: NinhoColors.onSurface,
        elevation: 0,
        centerTitle: false,
      ),
    );
  }
}
