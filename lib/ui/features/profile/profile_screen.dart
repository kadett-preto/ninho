import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/environments_repository.dart';
import '../../../data/repositories/shop_repository.dart';
import '../../../data/repositories/streaks_repository.dart';
import '../../../data/repositories/users_repository.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/posthog_service.dart';
import '../../core/colors.dart';
import '../../core/routes.dart';
import '../../core/spacing.dart';
import 'profile_controller.dart';

// Stitch — "Perfil do Usuário - Marina" (620c0c86988d41b5bbda558ea787d1b4).
// Fase 11.1: tela de perfil consolidando dados do morador + ninho.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    this.usersRepository,
    this.environmentsRepository,
    this.streaksRepository,
    this.shopRepository,
  });

  final UsersRepository? usersRepository;
  final EnvironmentsRepository? environmentsRepository;
  final StreaksRepository? streaksRepository;
  final ShopRepository? shopRepository;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ProfileController>(
      create: (_) => ProfileController(
        usersRepository: usersRepository,
        environmentsRepository: environmentsRepository,
        streaksRepository: streaksRepository,
        shopRepository: shopRepository,
      )..load(),
      child: const _View(),
    );
  }
}

class _View extends StatefulWidget {
  const _View();

  @override
  State<_View> createState() => _ViewState();
}

class _ViewState extends State<_View> {
  bool _signingOut = false;

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      await PosthogService.optOutAndReset();
      await AuthService.signOut();
      if (!mounted) return;
      context.go(NinhoRoutes.splash);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao sair: $e')),
      );
      setState(() => _signingOut = false);
    }
  }

  void _handleTab(int index) {
    if (index == 0) {
      context.go(NinhoRoutes.home);
      return;
    }
    if (index == 1) {
      context.go(NinhoRoutes.tasks);
      return;
    }
    if (index == 2) {
      context.go(NinhoRoutes.feed);
      return;
    }
    if (index == 3) {
      context.go(NinhoRoutes.shop);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ProfileController>();
    return Scaffold(
      backgroundColor: NinhoColors.background,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: _Body(controller: ctrl, signOut: _signOut, signingOut: _signingOut),
          ),
        ),
      ),
      bottomNavigationBar: _ProfileBottomNav(onTap: _handleTab),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.controller,
    required this.signOut,
    required this.signingOut,
  });

  final ProfileController controller;
  final VoidCallback signOut;
  final bool signingOut;

  @override
  Widget build(BuildContext context) {
    switch (controller.status) {
      case ProfileStatus.idle:
      case ProfileStatus.loading:
        return const Center(
          child: CircularProgressIndicator(color: NinhoColors.primary),
        );
      case ProfileStatus.error:
        return _ErrorView(
          message: controller.error ?? 'Erro desconhecido',
          onRetry: controller.load,
        );
      case ProfileStatus.noEnvironment:
        return _NoEnvView(name: controller.displayName, signOut: signOut, signingOut: signingOut);
      case ProfileStatus.ready:
        return _ReadyView(
          controller: controller,
          signOut: signOut,
          signingOut: signingOut,
        );
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
              key: const Key('profile_error'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: NinhoColors.error,
              ),
            ),
            const SizedBox(height: NinhoSpacing.stackMd),
            FilledButton.tonal(
              key: const Key('profile_retry'),
              onPressed: onRetry,
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoEnvView extends StatelessWidget {
  const _NoEnvView({
    required this.name,
    required this.signOut,
    required this.signingOut,
  });

  final String name;
  final VoidCallback signOut;
  final bool signingOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(NinhoSpacing.marginMobile),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Avatar(label: name, radius: 56),
            const SizedBox(height: NinhoSpacing.stackMd),
            Text(
              name,
              key: const Key('profile_name'),
              style: theme.textTheme.headlineLarge?.copyWith(
                color: NinhoColors.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: NinhoSpacing.stackMd),
            Text(
              'Você ainda não tem ninho.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: NinhoColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: NinhoSpacing.stackLg),
            FilledButton(
              onPressed: () => context.go(NinhoRoutes.setupStep1),
              child: const Text('Criar meu ninho'),
            ),
            const SizedBox(height: NinhoSpacing.stackMd),
            _SignOutButton(onTap: signOut, busy: signingOut),
          ],
        ),
      ),
    );
  }
}

class _ReadyView extends StatelessWidget {
  const _ReadyView({
    required this.controller,
    required this.signOut,
    required this.signingOut,
  });

  final ProfileController controller;
  final VoidCallback signOut;
  final bool signingOut;

  @override
  Widget build(BuildContext context) {
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
          _Header(controller: controller),
          const SizedBox(height: NinhoSpacing.stackLg),
          _StatsGrid(controller: controller),
          const SizedBox(height: NinhoSpacing.stackLg),
          const _MenuSection(),
          const SizedBox(height: NinhoSpacing.stackMd),
          _SignOutButton(onTap: signOut, busy: signingOut),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.controller});
  final ProfileController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final env = controller.environment;
    return Column(
      children: [
        _Avatar(label: controller.displayName, radius: 56),
        const SizedBox(height: NinhoSpacing.stackMd),
        Text(
          controller.displayName,
          key: const Key('profile_name'),
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineLarge?.copyWith(
            color: NinhoColors.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: NinhoSpacing.stackSm),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            if (env != null)
              _Chip(
                icon: Icons.home_outlined,
                label: env.name,
                background: NinhoColors.secondaryContainer,
                foreground: NinhoColors.onSecondaryContainer,
                keyValue: 'profile_env_chip',
              ),
            _Chip(
              icon: env?.isOwner == true
                  ? Icons.workspace_premium_outlined
                  : Icons.eco_outlined,
              label: env?.isOwner == true ? 'Owner' : 'Morador',
              background: NinhoColors.tertiaryFixedDim,
              foreground: NinhoColors.onTertiaryFixedVariant,
              keyValue: 'profile_role_chip',
            ),
          ],
        ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.controller});
  final ProfileController controller;

  @override
  Widget build(BuildContext context) {
    final streak = controller.streak;
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            keyValue: 'profile_stat_current_streak',
            icon: Icons.local_fire_department,
            iconBackground: NinhoColors.primaryFixed,
            iconColor: NinhoColors.onPrimaryFixedVariant,
            label: 'Streak atual',
            value: '${streak.userCount}',
            unit: streak.userCount == 1 ? 'dia' : 'dias',
          ),
        ),
        const SizedBox(width: NinhoSpacing.stackSm),
        Expanded(
          child: _StatCard(
            keyValue: 'profile_stat_best_streak',
            icon: Icons.workspace_premium,
            iconBackground: NinhoColors.tertiaryFixed,
            iconColor: NinhoColors.onTertiaryFixedVariant,
            label: 'Maior streak',
            value: '${streak.userBest}',
            unit: streak.userBest == 1 ? 'dia' : 'dias',
          ),
        ),
        const SizedBox(width: NinhoSpacing.stackSm),
        Expanded(
          child: _StatCard(
            keyValue: 'profile_stat_dust',
            icon: Icons.auto_awesome,
            iconBackground: NinhoColors.secondaryFixed,
            iconColor: NinhoColors.onSecondaryFixedVariant,
            label: 'Poeira',
            value: '${controller.dustBalance}',
            unit: null,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.keyValue,
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.unit,
  });

  final String keyValue;
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String label;
  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      key: Key(keyValue),
      decoration: BoxDecoration(
        color: NinhoColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(NinhoRadii.xl),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14944931),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(NinhoSpacing.paddingCard),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: NinhoSpacing.stackMd),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: NinhoColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    value,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: NinhoColors.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (unit != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    unit!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: NinhoColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuSection extends StatelessWidget {
  const _MenuSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MenuRow(
          keyValue: 'profile_menu_notifications',
          icon: Icons.notifications_outlined,
          label: 'Notificações',
          onTap: () => context.go(NinhoRoutes.notificationSettings),
        ),
        const SizedBox(height: NinhoSpacing.unit),
        _MenuRow(
          keyValue: 'profile_menu_account',
          icon: Icons.manage_accounts_outlined,
          label: 'Configurações da conta',
          comingSoon: true,
        ),
        const SizedBox(height: NinhoSpacing.unit),
        _MenuRow(
          keyValue: 'profile_menu_environment',
          icon: Icons.home_repair_service_outlined,
          label: 'Configurações do ninho',
          comingSoon: true,
        ),
        const SizedBox(height: NinhoSpacing.unit),
        _MenuRow(
          keyValue: 'profile_menu_export',
          icon: Icons.cloud_download_outlined,
          label: 'Exportar meus dados',
          onTap: () => context.go(NinhoRoutes.profileExport),
        ),
        const SizedBox(height: NinhoSpacing.unit),
        _MenuRow(
          keyValue: 'profile_menu_help',
          icon: Icons.help_outline,
          label: 'Ajuda',
          comingSoon: true,
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.keyValue,
    required this.icon,
    required this.label,
    this.onTap,
    this.comingSoon = false,
  });

  final String keyValue;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onTap != null && !comingSoon;
    return Material(
      color: NinhoColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(NinhoRadii.lg),
      child: InkWell(
        key: Key(keyValue),
        borderRadius: BorderRadius.circular(NinhoRadii.lg),
        onTap: enabled
            ? onTap
            : () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Em breve.')),
              ),
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
                child: Text(
                  label,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: NinhoColors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (comingSoon)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    'Em breve',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: NinhoColors.onSurfaceVariant,
                    ),
                  ),
                ),
              const Icon(
                Icons.chevron_right,
                color: NinhoColors.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignOutButton extends StatelessWidget {
  const _SignOutButton({required this.onTap, required this.busy});
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      key: const Key('profile_signout_button'),
      onPressed: busy ? null : onTap,
      icon: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.logout, color: NinhoColors.error),
      label: const Text(
        'Sair da conta',
        style: TextStyle(color: NinhoColors.error, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.label, this.radius = 24});
  final String label;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initial = label.isEmpty
        ? '?'
        : label.characters.first.toUpperCase();
    return Container(
      width: radius * 2,
      height: radius * 2,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: NinhoColors.primaryFixed,
        shape: BoxShape.circle,
        border: Border.all(
          color: NinhoColors.surfaceContainerHigh,
          width: 4,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14944931),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        initial,
        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
          color: NinhoColors.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.keyValue,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final String keyValue;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: Key(keyValue),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(NinhoRadii.full),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileBottomNav extends StatelessWidget {
  const _ProfileBottomNav({required this.onTap});
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: NinhoColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14944931),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, bottom + 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.home_outlined,
              label: 'Início',
              onTap: () => onTap(0),
              keyValue: 'profile_nav_home',
            ),
            _NavItem(
              icon: Icons.checklist,
              label: 'Tarefas',
              onTap: () => onTap(1),
              keyValue: 'profile_nav_tasks',
            ),
            _NavItem(
              icon: Icons.grid_view,
              label: 'Mural',
              onTap: () => onTap(2),
              keyValue: 'profile_nav_feed',
            ),
            _NavItem(
              icon: Icons.storefront_outlined,
              label: 'Loja',
              onTap: () => onTap(3),
              keyValue: 'profile_nav_shop',
            ),
            _NavItem(
              icon: Icons.person,
              label: 'Perfil',
              selected: true,
              onTap: () => onTap(4),
              keyValue: 'profile_nav_profile',
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.keyValue,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String keyValue;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? NinhoColors.primary : NinhoColors.onSurfaceVariant;
    return Expanded(
      child: InkWell(
        key: Key(keyValue),
        borderRadius: BorderRadius.circular(NinhoRadii.regular),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, fill: selected ? 1 : 0),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
