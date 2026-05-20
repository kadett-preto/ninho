import 'package:flutter/material.dart';

// Placeholder de tokens até integração com Stitch (IDEA.md §2).
// Tokens reais (cores, tipografia, espaçamentos) devem ser extraídos do design
// quando os exports estiverem disponíveis.
class NinhoTheme {
  static ThemeData light() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6B8E5A)),
      useMaterial3: true,
    );
  }
}
