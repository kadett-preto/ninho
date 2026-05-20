import 'package:flutter/material.dart';

import '../../core/colors.dart';
import '../../core/spacing.dart';

// Card 1 do onboarding (Stitch — Bem-vindo · Playful Geometric Variant).
// Estrutura: logotype + hero circular ringed + headline + body + CTAs.
class WelcomeCard extends StatelessWidget {
  const WelcomeCard({
    super.key,
    required this.onPrimary,
    required this.onSecondary,
  });

  final VoidCallback onPrimary;
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        const SizedBox(height: NinhoSpacing.stackSm),
        Text(
          'ninho',
          style: theme.textTheme.headlineMedium?.copyWith(
            color: NinhoColors.primary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: NinhoSpacing.stackMd),
        const Expanded(child: _HeroIllustration()),
        const SizedBox(height: NinhoSpacing.stackLg),
        Text(
          'A divisão de tarefas justa e leve da casa.',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: NinhoSpacing.stackSm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'Para casais, amigos e famílias que dividem o mesmo teto.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: NinhoColors.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: NinhoSpacing.stackLg),
        FilledButton(
          onPressed: onPrimary,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          child: const Text('Começar'),
        ),
        const SizedBox(height: NinhoSpacing.stackSm),
        TextButton(
          onPressed: onSecondary,
          style: TextButton.styleFrom(
            foregroundColor: NinhoColors.secondary,
            minimumSize: const Size.fromHeight(48),
          ),
          child: const Text('Já tenho conta · Entrar'),
        ),
      ],
    );
  }
}

class _HeroIllustration extends StatelessWidget {
  const _HeroIllustration();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.maxWidth.clamp(220.0, 280.0);
          return SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Anel decorativo (Stitch usa border-dashed; Flutter sem dashed
                // nativo — anel sólido com baixa opacidade é aproximação aceita).
                Container(
                  width: size * 1.1,
                  height: size * 1.1,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: NinhoColors.outlineVariant.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                ),
                // Card da ilustração: 24px radius, ring surface-bright.
                Container(
                  decoration: BoxDecoration(
                    color: NinhoColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: NinhoColors.surfaceBright,
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: NinhoColors.primary.withValues(alpha: 0.08),
                        blurRadius: 32,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    'assets/illustrations/onboarding_welcome.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const ColoredBox(color: NinhoColors.surfaceContainer),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
