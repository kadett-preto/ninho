import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/services/auth_service.dart';
import '../../../data/services/posthog_service.dart';
import '../../core/colors.dart';
import '../../core/routes.dart';
import '../../core/spacing.dart';
import '../tasks/task_demo_data.dart';

// Stitch — "Início" (63345f0e4cd44e0fbc15ef27f70c8cc9).
// Fase 6.1/6.2: dashboard Hoje com tab bar. Dados reais de tasks entram nas
// próximas subtasks da Fase 6; esta tela mantém o contrato visual navegável.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Falha ao sair: $e')));
      setState(() => _signingOut = false);
    }
  }

  void _showProfileSheet() {
    final email = AuthService.currentUser?.email ?? 'Sessão local';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: NinhoColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(NinhoSpacing.marginMobile),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Perfil',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: NinhoColors.onSurface,
                  ),
                ),
                const SizedBox(height: NinhoSpacing.stackSm),
                Text(
                  email,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: NinhoColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: NinhoSpacing.stackLg),
                OutlinedButton.icon(
                  key: const Key('home_logout_button'),
                  onPressed: _signingOut ? null : _signOut,
                  icon: _signingOut
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.logout),
                  label: const Text('Sair do ninho'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    foregroundColor: NinhoColors.primary,
                    side: const BorderSide(color: NinhoColors.outlineVariant),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleTab(int index) {
    if (index == 0) return;
    if (index == 1) {
      context.go(NinhoRoutes.tasks);
      return;
    }
    if (index == 3) {
      context.go(NinhoRoutes.shop);
      return;
    }
    if (index == 4) {
      _showProfileSheet();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NinhoColors.background,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: CustomScrollView(
                  slivers: [
                    const SliverToBoxAdapter(child: _HomeTopBar()),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        NinhoSpacing.marginMobile,
                        NinhoSpacing.stackMd,
                        NinhoSpacing.marginMobile,
                        120,
                      ),
                      sliver: SliverList.list(
                        children: const [
                          _WelcomeSection(),
                          SizedBox(height: NinhoSpacing.stackLg),
                          _StatsRow(),
                          SizedBox(height: NinhoSpacing.stackLg),
                          _TasksSection(),
                          SizedBox(height: NinhoSpacing.stackLg),
                          _CalmFooter(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: _HomeBottomNav(onTap: _handleTab),
    );
  }
}

class _HomeTopBar extends StatelessWidget {
  const _HomeTopBar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = _currentFirstName();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        NinhoSpacing.marginMobile,
        NinhoSpacing.stackMd,
        NinhoSpacing.marginMobile,
        NinhoSpacing.stackSm,
      ),
      child: Row(
        children: [
          _Avatar(initial: name.substring(0, 1).toUpperCase()),
          const SizedBox(width: 12),
          Text(
            'ninho',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: NinhoColors.primary,
            ),
          ),
          const Spacer(),
          DecoratedBox(
            decoration: const BoxDecoration(
              color: NinhoColors.surfaceContainerLow,
              shape: BoxShape.circle,
              boxShadow: [_AmbientShadow()],
            ),
            child: IconButton(
              key: const Key('home_notifications_button'),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Nada novo por enquanto.')),
                );
              },
              color: NinhoColors.primary,
              icon: const Icon(Icons.notifications_none),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: NinhoColors.primaryFixed,
        shape: BoxShape.circle,
        border: Border.all(color: NinhoColors.surfaceContainerHigh, width: 2),
      ),
      child: Text(
        initial,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: NinhoColors.primary,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _WelcomeSection extends StatelessWidget {
  const _WelcomeSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = _currentFirstName();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Oi, $name',
          style: theme.textTheme.headlineMedium?.copyWith(
            color: NinhoColors.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _formatToday(DateTime.now()),
          style: theme.textTheme.bodySmall?.copyWith(
            color: NinhoColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          _StatPill(
            icon: Icons.local_fire_department_outlined,
            label: '12 dias',
            background: NinhoColors.secondaryContainer,
            foreground: NinhoColors.onSecondaryContainer,
          ),
          SizedBox(width: 12),
          _StatPill(
            icon: Icons.home_outlined,
            label: '8 dias',
            background: NinhoColors.primaryContainer,
            foreground: NinhoColors.onPrimaryContainer,
          ),
          SizedBox(width: 12),
          _StatPill(
            icon: Icons.auto_awesome,
            label: '145',
            background: NinhoColors.surfaceContainerHigh,
            foreground: NinhoColors.onSurface,
            iconColor: NinhoColors.tertiary,
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(NinhoRadii.full),
        boxShadow: const [_AmbientShadow()],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: iconColor ?? foreground),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: foreground),
            ),
          ],
        ),
      ),
    );
  }
}

class _TasksSection extends StatelessWidget {
  const _TasksSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tarefas de hoje',
          style: theme.textTheme.titleMedium?.copyWith(
            color: NinhoColors.onSurface,
          ),
        ),
        const SizedBox(height: NinhoSpacing.stackMd),
        for (final task in _todayTasks) ...[
          _TaskCard(task: task),
          const SizedBox(height: NinhoSpacing.stackMd),
        ],
      ],
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task});

  final TaskDemo task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('home_task_card_${task.id}'),
        borderRadius: BorderRadius.circular(NinhoRadii.xl),
        onTap: () => context.go('${NinhoRoutes.taskDetail}/${task.id}'),
        child: Ink(
          decoration: BoxDecoration(
            color: NinhoColors.surface,
            borderRadius: BorderRadius.circular(NinhoRadii.xl),
            border: Border.all(color: NinhoColors.surfaceContainerHigh),
            boxShadow: const [_AmbientShadow()],
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(width: 8, color: task.accent),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(NinhoSpacing.paddingCard),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: task.iconBackground,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            task.icon,
                            color: task.iconColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: NinhoSpacing.stackMd),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontSize: 16,
                                  height: 22 / 16,
                                  fontWeight: FontWeight.w600,
                                  color: NinhoColors.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    task.roomIcon,
                                    size: 14,
                                    color: NinhoColors.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      task.room,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            fontSize: 12,
                                            color: NinhoColors.onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  _DifficultyBadge(task: task),
                                  const SizedBox(width: 8),
                                  _MiniAvatar(initial: task.assigneeInitial),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: NinhoSpacing.stackSm),
                        SizedBox.square(
                          dimension: 40,
                          child: OutlinedButton(
                            key: Key('home_task_check_${task.id}'),
                            onPressed: () => context.go(
                              '${NinhoRoutes.taskDetail}/${task.id}/complete',
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              shape: const CircleBorder(),
                              side: const BorderSide(
                                color: NinhoColors.outlineVariant,
                                width: 2,
                              ),
                              foregroundColor: NinhoColors.outlineVariant,
                            ),
                            child: const Icon(Icons.check, size: 22),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DifficultyBadge extends StatelessWidget {
  const _DifficultyBadge({required this.task});

  final TaskDemo task;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: task.difficultyBackground,
        borderRadius: BorderRadius.circular(NinhoRadii.full),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Text(
          task.difficultyLabel,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontSize: 10,
            color: task.difficultyForeground,
          ),
        ),
      ),
    );
  }
}

class _MiniAvatar extends StatelessWidget {
  const _MiniAvatar({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: NinhoColors.primaryFixed,
        shape: BoxShape.circle,
        border: Border.all(color: NinhoColors.surfaceContainerHigh),
      ),
      child: Text(
        initial,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontSize: 10,
          letterSpacing: 0,
          color: NinhoColors.primary,
        ),
      ),
    );
  }
}

class _CalmFooter extends StatelessWidget {
  const _CalmFooter();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        SizedBox.square(
          dimension: 96,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: NinhoColors.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.scale(
                  scale: 0.6,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      color: NinhoColors.secondaryFixedDim,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox.expand(),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(16, 0),
                  child: Transform.scale(
                    scale: 0.3,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        color: NinhoColors.tertiaryFixedDim,
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox.expand(),
                    ),
                  ),
                ),
                const Icon(Icons.eco_outlined, color: NinhoColors.secondary),
              ],
            ),
          ),
        ),
        const SizedBox(height: NinhoSpacing.stackMd),
        Text(
          'Tudo tranquilo por aqui',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: NinhoColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _HomeBottomNav extends StatelessWidget {
  const _HomeBottomNav({required this.onTap});

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
              icon: Icons.home,
              label: 'Início',
              selected: true,
              onTap: () => onTap(0),
            ),
            _NavItem(
              icon: Icons.checklist,
              label: 'Tarefas',
              onTap: () => onTap(1),
            ),
            _NavItem(
              icon: Icons.grid_view,
              label: 'Mural',
              onTap: () => onTap(2),
            ),
            _NavItem(
              icon: Icons.storefront_outlined,
              label: 'Loja',
              onTap: () => onTap(3),
            ),
            _NavItem(
              key: const Key('home_profile_tab'),
              icon: Icons.person_outline,
              label: 'Perfil',
              onTap: () => onTap(4),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? NinhoColors.primaryContainer
        : NinhoColors.onSurfaceVariant;
    return Expanded(
      child: InkWell(
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
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmbientShadow extends BoxShadow {
  const _AmbientShadow()
    : super(
        color: const Color(0x14944931),
        blurRadius: 16,
        offset: const Offset(0, 4),
      );
}

const _todayTasks = taskDemoItems;

String _currentFirstName() {
  final user = AuthService.currentUser;
  final metadataName = user?.userMetadata?['name'];
  final rawName = metadataName is String && metadataName.trim().isNotEmpty
      ? metadataName.trim()
      : user?.email?.split('@').first.trim();
  if (rawName == null || rawName.isEmpty) return 'Marina';
  final normalized = rawName.split(RegExp(r'[\s._-]+')).first;
  if (normalized.isEmpty) return 'Marina';
  return normalized.substring(0, 1).toUpperCase() + normalized.substring(1);
}

String _formatToday(DateTime date) {
  const weekdays = [
    'Segunda-feira',
    'Terça-feira',
    'Quarta-feira',
    'Quinta-feira',
    'Sexta-feira',
    'Sábado',
    'Domingo',
  ];
  const months = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];
  return '${weekdays[date.weekday - 1]}, ${date.day} de ${months[date.month - 1]}';
}
