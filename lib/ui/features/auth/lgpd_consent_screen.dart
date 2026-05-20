import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/colors.dart';
import '../../core/routes.dart';
import '../../core/spacing.dart';

// Consentimento LGPD (Stitch — Consentimento de Privacidade).
// Persistência (`users.lgpd_consent_at` + audit_log) entra na task 2.7.
class LgpdConsentScreen extends StatefulWidget {
  const LgpdConsentScreen({super.key});

  @override
  State<LgpdConsentScreen> createState() => _LgpdConsentScreenState();
}

class _LgpdConsentScreenState extends State<LgpdConsentScreen> {
  bool _notificationsConsent = false;
  bool _analyticsConsent = false;

  void _accept() {
    // TODO(task 2.7): persistir consentimentos via Edge Function:
    //   - users.lgpd_consent_at = now()
    //   - audit_log entry "consent.lgpd.accepted"
    //   - notifications/analytics flags em users meta
    // E disparar PosthogService.setupIfConsented(analytics) só se opt-in.
    context.go(NinhoRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: NinhoColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: NinhoSpacing.marginMobile,
            vertical: NinhoSpacing.stackLg,
          ),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  color: NinhoColors.onSurface,
                  onPressed: () => Navigator.maybePop(context),
                ),
              ),
              const SizedBox(height: NinhoSpacing.stackMd),
              _ShieldHeader(theme: theme),
              const SizedBox(height: NinhoSpacing.stackLg),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _ConsentCard(
                        icon: Icons.settings,
                        iconBg: NinhoColors.tertiaryFixed,
                        iconFg: NinhoColors.onTertiaryFixed,
                        title: 'Uso dos meus dados para funcionamento do app',
                        requiredLabel: true,
                        value: true,
                        onChanged: null,
                      ),
                      const SizedBox(height: NinhoSpacing.stackMd),
                      _ConsentCard(
                        icon: Icons.notifications,
                        iconBg: NinhoColors.secondaryFixed,
                        iconFg: NinhoColors.onSecondaryFixed,
                        title: 'Receber notificações de tarefas',
                        value: _notificationsConsent,
                        onChanged: (v) =>
                            setState(() => _notificationsConsent = v),
                      ),
                      const SizedBox(height: NinhoSpacing.stackMd),
                      _ConsentCard(
                        icon: Icons.bar_chart,
                        iconBg: NinhoColors.primaryFixed,
                        iconFg: NinhoColors.onPrimaryFixed,
                        title: 'Métricas para melhorar o app',
                        value: _analyticsConsent,
                        onChanged: (v) => setState(() => _analyticsConsent = v),
                      ),
                    ],
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  // TODO(2.7): abrir URL real da política de privacidade.
                },
                style: TextButton.styleFrom(
                  foregroundColor: NinhoColors.tertiary,
                ),
                child: const Text('Ler política de privacidade completa'),
              ),
              const SizedBox(height: NinhoSpacing.stackSm),
              FilledButton(
                onPressed: _accept,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                child: const Text('Aceitar e continuar'),
              ),
              const SizedBox(height: NinhoSpacing.stackSm),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShieldHeader extends StatelessWidget {
  const _ShieldHeader({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: NinhoColors.secondaryContainer,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: NinhoColors.secondary.withValues(alpha: 0.1),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.shield,
            size: 48,
            color: NinhoColors.secondary,
          ),
        ),
        const SizedBox(height: NinhoSpacing.stackMd),
        Text(
          'Sua privacidade vem primeiro.',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineLarge?.copyWith(
            color: NinhoColors.primary,
          ),
        ),
        const SizedBox(height: NinhoSpacing.stackSm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'Seus dados são usados apenas para o funcionamento do app e nunca são compartilhados fora do seu ninho.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: NinhoColors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _ConsentCard extends StatelessWidget {
  const _ConsentCard({
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.title,
    required this.value,
    required this.onChanged,
    this.requiredLabel = false,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String title;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool requiredLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(NinhoSpacing.paddingCard),
      decoration: BoxDecoration(
        color: NinhoColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: NinhoColors.tertiary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconFg, size: 24),
          ),
          const SizedBox(width: NinhoSpacing.gutterMobile),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (requiredLabel) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Obrigatório',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: NinhoColors.primaryContainer,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: NinhoSpacing.gutterMobile),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: NinhoColors.primary,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: NinhoColors.surfaceVariant,
          ),
        ],
      ),
    );
  }
}
