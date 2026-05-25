import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/users_repository.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/posthog_service.dart';
import '../../core/colors.dart';
import '../../core/routes.dart';
import '../../core/spacing.dart';
import 'account_settings_controller.dart';

// Stitch — "Configurações da Conta - Harmonia Lar" (6ce6cc12...).
// Hub da conta: links pra Editar perfil, Idioma, Notificações, e seções de
// Privacidade que reusam telas existentes (Exportar / Excluir).
// "Aparência" segue marcada como Em breve — tema dark/system ainda não tem
// state global (Stitch traz o segmented mas precisa refactor do MaterialApp).
class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key, this.usersRepository});

  final UsersRepository? usersRepository;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AccountSettingsController>(
      create: (_) =>
          AccountSettingsController(usersRepository: usersRepository)..load(),
      child: const _View(),
    );
  }
}

class _View extends StatelessWidget {
  const _View();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AccountSettingsController>();
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: NinhoColors.background,
      appBar: AppBar(
        backgroundColor: NinhoColors.background,
        elevation: 0,
        leading: IconButton(
          key: const Key('account_back'),
          icon: const Icon(Icons.arrow_back, color: NinhoColors.onSurface),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(NinhoRoutes.profile);
            }
          },
        ),
        centerTitle: true,
        title: Text(
          'Conta',
          style: theme.textTheme.titleMedium?.copyWith(
            color: NinhoColors.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(child: _Body(controller: ctrl)),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.controller});
  final AccountSettingsController controller;

  @override
  Widget build(BuildContext context) {
    switch (controller.status) {
      case AccountSettingsStatus.idle:
      case AccountSettingsStatus.loading:
        return const Center(
          child: CircularProgressIndicator(color: NinhoColors.primary),
        );
      case AccountSettingsStatus.error:
        if (controller.profile == null) {
          return _ErrorView(
            message: controller.error ?? 'Erro desconhecido',
            onRetry: controller.load,
          );
        }
        return _Ready(controller: controller);
      case AccountSettingsStatus.ready:
      case AccountSettingsStatus.saving:
        return _Ready(controller: controller);
    }
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(NinhoSpacing.marginMobile),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              key: const Key('account_error'),
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: NinhoColors.error),
            ),
            const SizedBox(height: NinhoSpacing.stackMd),
            FilledButton.tonal(
              key: const Key('account_retry'),
              onPressed: onRetry,
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Ready extends StatelessWidget {
  const _Ready({required this.controller});
  final AccountSettingsController controller;

  Future<void> _pickLocale(BuildContext context) async {
    final current = controller.profile?.locale ?? 'pt-BR';
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: NinhoColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(NinhoSpacing.marginMobile),
          child: RadioGroup<String>(
            groupValue: current,
            onChanged: (v) => Navigator.of(sheetCtx).pop(v),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: NinhoSpacing.stackMd),
                  child: Text(
                    'Idioma',
                    textAlign: TextAlign.center,
                    style: Theme.of(sheetCtx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                for (final entry in _localeChoices.entries)
                  RadioListTile<String>(
                    key: Key('account_locale_${entry.key}'),
                    value: entry.key,
                    title: Text(entry.value),
                    activeColor: NinhoColors.primary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (picked == null || picked == current) return;
    final ok = await controller.updateLocale(picked);
    if (!context.mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Idioma salvo. Reabra o app pra aplicar.'),
        ),
      );
    } else if (controller.error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(controller.error!)));
    }
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      await PosthogService.optOutAndReset();
      await AuthService.signOut();
      if (!context.mounted) return;
      context.go(NinhoRoutes.splash);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Falha ao sair: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = controller.profile;
    final email = profile?.email ?? '—';
    final localeLabel =
        _localeChoices[profile?.locale ?? 'pt-BR'] ?? 'Português (BR)';
    return RefreshIndicator(
      onRefresh: controller.load,
      color: NinhoColors.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          NinhoSpacing.marginMobile,
          NinhoSpacing.stackMd,
          NinhoSpacing.marginMobile,
          120,
        ),
        children: [
          const _SectionLabel('Conta'),
          _Row(
            keyValue: 'account_row_edit_profile',
            icon: Icons.person_outline,
            title: 'Editar perfil',
            subtitle: profile?.displayName ?? 'Definir nome e foto',
            onTap: () async {
              await context.push(NinhoRoutes.accountEditProfile);
              if (!context.mounted) return;
              controller.load();
            },
          ),
          _Row(
            keyValue: 'account_row_email',
            icon: Icons.mail_outline,
            title: 'E-mail',
            subtitle: email,
            trailing: const SizedBox(width: 8),
          ),
          _Row(
            keyValue: 'account_row_locale',
            icon: Icons.language_outlined,
            title: 'Idioma',
            subtitle: localeLabel,
            onTap: () => _pickLocale(context),
          ),
          _Row(
            keyValue: 'account_row_notifications',
            icon: Icons.notifications_none,
            title: 'Notificações',
            subtitle: 'Horários e canais',
            onTap: () => context.go(NinhoRoutes.notificationSettings),
          ),
          _Row(
            keyValue: 'account_row_appearance',
            icon: Icons.palette_outlined,
            title: 'Aparência',
            subtitle: 'Tema claro',
            comingSoon: true,
          ),
          const SizedBox(height: NinhoSpacing.stackMd),
          const _SectionLabel('Privacidade e dados'),
          _Row(
            keyValue: 'account_row_export',
            icon: Icons.cloud_download_outlined,
            title: 'Exportar meus dados',
            subtitle: 'Receba um arquivo JSON com seus dados.',
            onTap: () => context.go(NinhoRoutes.profileExport),
          ),
          _Row(
            keyValue: 'account_row_delete',
            icon: Icons.delete_outline,
            title: 'Excluir minha conta',
            subtitle: 'Seus dados são apagados em até 30 dias.',
            onTap: () => context.go(NinhoRoutes.profileDelete),
          ),
          const SizedBox(height: NinhoSpacing.stackLg),
          FilledButton.tonal(
            key: const Key('account_sign_out'),
            onPressed: () => _signOut(context),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: NinhoColors.onSurface,
            ),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
  }
}

const Map<String, String> _localeChoices = {
  'pt-BR': 'Português (BR)',
  'en': 'English',
  'es': 'Español',
  'fr': 'Français',
};

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: NinhoSpacing.stackMd,
        bottom: NinhoSpacing.stackSm,
        left: 4,
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: NinhoColors.onSurfaceVariant,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.keyValue,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.comingSoon = false,
  });

  final String keyValue;
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: NinhoSpacing.unit),
      child: Material(
        color: NinhoColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(NinhoRadii.lg),
        child: InkWell(
          key: Key(keyValue),
          borderRadius: BorderRadius.circular(NinhoRadii.lg),
          onTap: comingSoon
              ? () => ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Em breve.')))
              : onTap,
          child: Padding(
            padding: const EdgeInsets.all(NinhoSpacing.stackMd),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: NinhoColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(NinhoRadii.lg),
                  ),
                  child: Icon(
                    icon,
                    color: NinhoColors.onSurfaceVariant,
                    size: 22,
                  ),
                ),
                const SizedBox(width: NinhoSpacing.stackMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: NinhoColors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: NinhoColors.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (trailing != null)
                  trailing!
                else if (onTap != null || comingSoon)
                  const Icon(Icons.chevron_right, color: NinhoColors.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
