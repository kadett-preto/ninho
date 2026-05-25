import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/environments_repository.dart';
import '../../../data/repositories/shop_repository.dart';
import '../../../data/repositories/streaks_repository.dart';
import '../../../data/repositories/suggestions_repository.dart'
    show TaskDifficulty;
import '../../../data/repositories/tasks_repository.dart';
import '../../../data/services/auth_service.dart';
import '../../core/colors.dart';
import '../../core/widgets/ninho_bottom_nav.dart';
import '../../core/routes.dart';
import '../../core/spacing.dart';
import 'home_controller.dart';

// Stitch — "Início" (63345f0e4cd44e0fbc15ef27f70c8cc9).
// Fase 6.2: dashboard Hoje com dados reais (tasks esperadas hoje p/ o user,
// streaks individual + ninho, saldo de poeira). RLS no banco isola tudo.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    this.environmentsRepository,
    this.tasksRepository,
    this.streaksRepository,
    this.shopRepository,
    this.currentUserId,
  });

  final EnvironmentsRepository? environmentsRepository;
  final TasksRepository? tasksRepository;
  final StreaksRepository? streaksRepository;
  final ShopRepository? shopRepository;
  // Injetável p/ testes — em produção o controller pega do AuthService.
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<HomeController>(
      create: (_) => HomeController(
        environmentsRepository: environmentsRepository,
        tasksRepository: tasksRepository,
        streaksRepository: streaksRepository,
        shopRepository: shopRepository,
        currentUserId: currentUserId,
      )..load(),
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatefulWidget {
  const _HomeView();

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> {
  void _handleTab(NinhoTab tab) {
    switch (tab) {
      case NinhoTab.home:
        return;
      case NinhoTab.tasks:
        context.go(NinhoRoutes.tasks);
      case NinhoTab.feed:
        context.go(NinhoRoutes.feed);
      case NinhoTab.shop:
        context.go(NinhoRoutes.shop);
      case NinhoTab.profile:
        context.go(NinhoRoutes.profile);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<HomeController>();
    return Scaffold(
      backgroundColor: NinhoColors.background,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: _Body(controller: ctrl),
          ),
        ),
      ),
      bottomNavigationBar: NinhoBottomNav(
        active: NinhoTab.home,
        onTap: _handleTab,
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.controller});
  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    switch (controller.status) {
      case HomeStatus.idle:
      case HomeStatus.loading:
        return const Center(
          child: CircularProgressIndicator(color: NinhoColors.primary),
        );
      case HomeStatus.error:
        return _ErrorBody(
          message: controller.error ?? 'Erro desconhecido',
          onRetry: controller.load,
        );
      case HomeStatus.noEnvironment:
        return const _NoEnvBody();
      case HomeStatus.ready:
        return _ReadyBody(controller: controller);
    }
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(NinhoSpacing.marginMobile),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              key: const Key('home_error'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: NinhoColors.error,
              ),
            ),
            const SizedBox(height: NinhoSpacing.stackMd),
            FilledButton.tonal(
              key: const Key('home_retry'),
              onPressed: onRetry,
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoEnvBody extends StatelessWidget {
  const _NoEnvBody();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(NinhoSpacing.marginMobile),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Você ainda não tem ninho.',
              key: const Key('home_no_env'),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: NinhoColors.onSurface,
              ),
            ),
            const SizedBox(height: NinhoSpacing.stackMd),
            FilledButton(
              onPressed: () => context.go(NinhoRoutes.setupStep1),
              child: const Text('Criar meu ninho'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadyBody extends StatelessWidget {
  const _ReadyBody({required this.controller});
  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: controller.load,
      color: NinhoColors.primary,
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
              children: [
                const _WelcomeSection(),
                const SizedBox(height: NinhoSpacing.stackLg),
                _StatsRow(
                  userStreak: controller.userStreak,
                  envStreak: controller.environmentStreak,
                  dust: controller.dustBalance,
                ),
                const SizedBox(height: NinhoSpacing.stackLg),
                _TasksSection(tasks: controller.todayTasks),
                const SizedBox(height: NinhoSpacing.stackLg),
                if (controller.todayTasks.isEmpty) const _CalmFooter(),
              ],
            ),
          ),
        ],
      ),
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
              onPressed: () => context.go(NinhoRoutes.notificationSettings),
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
  const _StatsRow({
    required this.userStreak,
    required this.envStreak,
    required this.dust,
  });

  final int userStreak;
  final int envStreak;
  final int dust;

  @override
  Widget build(BuildContext context) {
    String dayLabel(int n) => n == 1 ? '1 dia' : '$n dias';
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          _StatPill(
            key: const Key('home_stat_env_streak'),
            icon: Icons.local_fire_department_outlined,
            label: dayLabel(envStreak),
            background: NinhoColors.secondaryContainer,
            foreground: NinhoColors.onSecondaryContainer,
          ),
          const SizedBox(width: 12),
          _StatPill(
            key: const Key('home_stat_user_streak'),
            icon: Icons.home_outlined,
            label: dayLabel(userStreak),
            background: NinhoColors.primaryContainer,
            foreground: NinhoColors.onPrimaryContainer,
          ),
          const SizedBox(width: 12),
          _StatPill(
            key: const Key('home_stat_dust'),
            icon: Icons.auto_awesome,
            label: '$dust',
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
    super.key,
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
  const _TasksSection({required this.tasks});

  final List<TaskListItem> tasks;

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
        if (tasks.isEmpty)
          _EmptyTasksCard(theme: theme)
        else
          for (final task in tasks) ...[
            _TaskCard(task: task),
            const SizedBox(height: NinhoSpacing.stackMd),
          ],
      ],
    );
  }
}

class _EmptyTasksCard extends StatelessWidget {
  const _EmptyTasksCard({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: NinhoColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(NinhoRadii.xl),
        border: Border.all(color: NinhoColors.surfaceContainerHigh),
      ),
      child: Padding(
        padding: const EdgeInsets.all(NinhoSpacing.paddingCard),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hoje você tá de boa',
              key: const Key('home_tasks_empty'),
              style: theme.textTheme.titleMedium?.copyWith(
                color: NinhoColors.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Nenhuma tarefa esperada pra você hoje. Aproveita o descanso.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: NinhoColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task});

  final TaskListItem task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = _DifficultyStyle.of(task.difficulty);
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
                Container(width: 8, color: style.accent),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(NinhoSpacing.paddingCard),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: style.iconBackground,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.cleaning_services_outlined,
                            color: style.iconColor,
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
                                  const Icon(
                                    Icons.home_outlined,
                                    size: 14,
                                    color: NinhoColors.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      task.roomName ?? 'Sem cômodo',
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
                              _DifficultyBadge(
                                difficulty: task.difficulty,
                                style: style,
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

class _DifficultyStyle {
  const _DifficultyStyle({
    required this.accent,
    required this.iconBackground,
    required this.iconColor,
    required this.badgeBackground,
    required this.badgeForeground,
    required this.label,
  });

  final Color accent;
  final Color iconBackground;
  final Color iconColor;
  final Color badgeBackground;
  final Color badgeForeground;
  final String label;

  static _DifficultyStyle of(TaskDifficulty difficulty) {
    switch (difficulty) {
      case TaskDifficulty.mamao:
        return const _DifficultyStyle(
          accent: NinhoColors.secondaryFixedDim,
          iconBackground: NinhoColors.secondaryContainer,
          iconColor: NinhoColors.onSecondaryContainer,
          badgeBackground: NinhoColors.secondaryFixedDim,
          badgeForeground: NinhoColors.onSecondaryFixedVariant,
          label: 'Mamão',
        );
      case TaskDifficulty.embacada:
        return const _DifficultyStyle(
          accent: NinhoColors.tertiaryFixedDim,
          iconBackground: NinhoColors.tertiaryContainer,
          iconColor: NinhoColors.onTertiaryContainer,
          badgeBackground: NinhoColors.tertiaryFixedDim,
          badgeForeground: NinhoColors.onTertiaryFixedVariant,
          label: 'Embaçada',
        );
      case TaskDifficulty.treta:
        return const _DifficultyStyle(
          accent: NinhoColors.primaryContainer,
          iconBackground: NinhoColors.primaryContainer,
          iconColor: NinhoColors.onPrimaryContainer,
          badgeBackground: NinhoColors.primaryContainer,
          badgeForeground: NinhoColors.onPrimaryContainer,
          label: 'Treta',
        );
    }
  }
}

class _DifficultyBadge extends StatelessWidget {
  const _DifficultyBadge({required this.difficulty, required this.style});

  final TaskDifficulty difficulty;
  final _DifficultyStyle style;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: style.badgeBackground,
        borderRadius: BorderRadius.circular(NinhoRadii.full),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Text(
          style.label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontSize: 10,
            color: style.badgeForeground,
          ),
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

// Bottom nav extraído para `lib/ui/core/widgets/ninho_bottom_nav.dart`
// (Fase 12.2). HomeScreen passa o mapping de tab→rota aqui.

class _AmbientShadow extends BoxShadow {
  const _AmbientShadow()
    : super(
        color: const Color(0x14944931),
        blurRadius: 16,
        offset: const Offset(0, 4),
      );
}

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
