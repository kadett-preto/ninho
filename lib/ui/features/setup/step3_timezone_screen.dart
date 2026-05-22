import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/colors.dart';
import '../../core/routes.dart';
import '../../core/spacing.dart';
import 'setup_controller.dart';
import 'widgets/setup_scaffold.dart';

// Stitch — Configurar Ambiente · Passo 3: fuso do ninho.
// Para MVP web não temos plugin de IANA tz; assumimos default e exibimos
// para confirmação. Busca/picker entram em iteração futura.
class SetupStep3TimezoneScreen extends StatelessWidget {
  const SetupStep3TimezoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = context.watch<SetupController>();

    return SetupScaffold(
      step: 3,
      totalSteps: 3,
      primaryLabel: 'Concluir cadastro',
      primaryLoading: controller.submitting,
      errorText: controller.lastError,
      onPrimary: () async {
        final id = await controller.submit();
        if (!context.mounted) return;
        if (id != null) {
          // Stitch: pós cadastro abre "Convidar Parceiro" com botão "Pular
          // por agora" — fluxo §4 do IDEA.md.
          context.go(NinhoRoutes.inviteFromSetup);
        }
      },
      onBack: () => context.go(NinhoRoutes.setupStep2),
      child: ListView(
        children: [
          const SizedBox(height: NinhoSpacing.stackMd),
          Center(
            child: Container(
              width: 192,
              height: 192,
              decoration: const BoxDecoration(
                color: NinhoColors.surfaceContainerLow,
                shape: BoxShape.circle,
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'assets/illustrations/setup_timezone.png',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
          const SizedBox(height: NinhoSpacing.stackLg),
          Text(
            'Qual o fuso da casa?',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: NinhoColors.primary,
            ),
          ),
          const SizedBox(height: NinhoSpacing.stackSm),
          Text(
            'Streaks e lembretes seguem esse horário pra todo mundo.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: NinhoColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: NinhoSpacing.stackLg),
          Container(
            padding: const EdgeInsets.all(NinhoSpacing.paddingCard),
            decoration: BoxDecoration(
              color: NinhoColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: NinhoColors.secondaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.schedule,
                    color: NinhoColors.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: NinhoSpacing.gutterMobile),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FUSO ATUAL',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: NinhoColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        controller.timezone,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: NinhoColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: NinhoSpacing.stackLg),
          // TODO(stitch): adicionar campo de busca + lista IANA quando o
          // pacote flutter_timezone for adicionado (precisaria adaptar para web).
        ],
      ),
    );
  }
}
