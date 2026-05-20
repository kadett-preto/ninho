import 'package:flutter/material.dart';

import '../../core/colors.dart';

// Placeholder de destino pós-fluxo de auth/onboarding. Tela real "Hoje"
// (Stitch — Início) entra na Fase 6.
class HomePlaceholderScreen extends StatelessWidget {
  const HomePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: NinhoColors.surface,
      appBar: AppBar(title: const Text('Ninho')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Bem-vindo ao Ninho.\nHome real entra na Fase 6.',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium,
          ),
        ),
      ),
    );
  }
}
