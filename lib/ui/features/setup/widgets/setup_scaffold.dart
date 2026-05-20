import 'package:flutter/material.dart';

import '../../../core/colors.dart';
import '../../../core/spacing.dart';

// Casca comum dos 3 passos do cadastro de ninho (Stitch — "Configurar
// Ambiente · Passo X de 3"). Header com back + indicador, conteúdo central e
// botão de ação preso ao bottom.
class SetupScaffold extends StatelessWidget {
  const SetupScaffold({
    super.key,
    required this.step,
    required this.totalSteps,
    required this.child,
    required this.primaryLabel,
    required this.onPrimary,
    this.onBack,
    this.primaryEnabled = true,
    this.primaryLoading = false,
    this.errorText,
  });

  final int step;
  final int totalSteps;
  final Widget child;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final VoidCallback? onBack;
  final bool primaryEnabled;
  final bool primaryLoading;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: NinhoColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: NinhoSpacing.marginMobile,
          ),
          child: Column(
            children: [
              SizedBox(
                height: 56,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed:
                          onBack ?? () => Navigator.of(context).maybePop(),
                    ),
                    Expanded(
                      child: Text(
                        'PASSO $step DE $totalSteps',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: NinhoColors.onSurfaceVariant,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(child: child),
              if (errorText != null) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: NinhoSpacing.stackSm),
                  child: Text(
                    errorText!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: NinhoColors.error,
                    ),
                  ),
                ),
              ],
              FilledButton(
                onPressed: (primaryEnabled && !primaryLoading)
                    ? onPrimary
                    : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                child: primaryLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: NinhoColors.onPrimary,
                        ),
                      )
                    : Text(primaryLabel),
              ),
              const SizedBox(height: NinhoSpacing.stackSm),
            ],
          ),
        ),
      ),
    );
  }
}
