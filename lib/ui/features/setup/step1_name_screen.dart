import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/colors.dart';
import '../../core/routes.dart';
import '../../core/spacing.dart';
import 'setup_controller.dart';
import 'widgets/setup_scaffold.dart';

// Stitch — Configurar Ambiente · Passo 1: nome do ninho.
class SetupStep1NameScreen extends StatefulWidget {
  const SetupStep1NameScreen({super.key});

  @override
  State<SetupStep1NameScreen> createState() => _SetupStep1NameScreenState();
}

class _SetupStep1NameScreenState extends State<SetupStep1NameScreen> {
  late final TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
      text: context.read<SetupController>().name,
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = context.watch<SetupController>();

    return SetupScaffold(
      step: 1,
      totalSteps: 3,
      primaryLabel: 'Continuar',
      primaryEnabled: controller.canAdvanceFromStep1,
      onPrimary: () => context.go(NinhoRoutes.setupStep2),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: NinhoSpacing.stackMd),
            Center(
              child: Container(
                width: 192,
                height: 192,
                decoration: BoxDecoration(
                  color: NinhoColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: NinhoColors.primary.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/illustrations/setup_house.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
            const SizedBox(height: NinhoSpacing.stackLg),
            Text(
              'Crie seu ninho',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: NinhoColors.primary,
              ),
            ),
            const SizedBox(height: NinhoSpacing.stackSm),
            Text(
              'É o espaço que vocês vão compartilhar — tipo o apê inteiro.',
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
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nome do ninho', style: theme.textTheme.titleMedium),
                  const SizedBox(height: NinhoSpacing.stackSm),
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Nosso apê',
                      filled: true,
                      fillColor: NinhoColors.surfaceContainerHigh,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: controller.setName,
                    textInputAction: TextInputAction.next,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
