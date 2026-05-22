import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/colors.dart';
import '../../core/routes.dart';
import '../../core/spacing.dart';
import 'task_demo_data.dart';

// Stitch — "Detalhes da Tarefa" (309bf756f62a4f23afec37c474dc7002).
class TaskDetailScreen extends StatelessWidget {
  const TaskDetailScreen({super.key, required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context) {
    final task = taskDemoById(taskId);
    return Scaffold(
      backgroundColor: NinhoColors.background,
      appBar: AppBar(
        backgroundColor: NinhoColors.background,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          key: const Key('task_detail_back_button'),
          color: NinhoColors.onSurfaceVariant,
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(NinhoRoutes.home);
            }
          },
        ),
        title: Text(
          'Detalhes da Tarefa',
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(color: NinhoColors.primary),
        ),
        actions: [
          IconButton(
            key: const Key('task_detail_more_button'),
            color: NinhoColors.onSurfaceVariant,
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: constraints.maxWidth > 480 ? 480 : constraints.maxWidth,
                height: constraints.maxHeight,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    NinhoSpacing.marginMobile,
                    NinhoSpacing.stackMd,
                    NinhoSpacing.marginMobile,
                    180,
                  ),
                  children: [
                    _TaskHeader(task: task),
                    const SizedBox(height: NinhoSpacing.stackLg),
                    _DetailsCard(task: task),
                    const SizedBox(height: NinhoSpacing.stackLg),
                    _Description(task: task),
                    const SizedBox(height: NinhoSpacing.stackLg),
                    const _History(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: _BottomActions(task: task),
    );
  }
}

class _TaskHeader extends StatelessWidget {
  const _TaskHeader({required this.task});

  final TaskDemo task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          task.title,
          style: theme.textTheme.displayLarge?.copyWith(
            color: NinhoColors.onBackground,
          ),
        ),
        const SizedBox(height: NinhoSpacing.stackSm),
        _DifficultyBadge(task: task),
      ],
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Text(
          task.difficultyLabel,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: task.difficultyForeground),
        ),
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.task});

  final TaskDemo task;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: NinhoColors.surfaceContainer,
        borderRadius: BorderRadius.circular(NinhoRadii.xl),
        boxShadow: const [_WarmShadow()],
      ),
      child: Padding(
        padding: const EdgeInsets.all(NinhoSpacing.paddingCard),
        child: Column(
          children: [
            _DetailRow(
              icon: Icons.home_outlined,
              iconColor: NinhoColors.secondary,
              label: 'Cômodo',
              value: task.room,
            ),
            const SizedBox(height: NinhoSpacing.stackMd),
            _DetailRow(
              avatar: task.assigneeInitial,
              label: 'Responsável',
              value: task.responsible,
            ),
            const SizedBox(height: NinhoSpacing.stackMd),
            _DetailRow(
              icon: Icons.loop,
              iconColor: NinhoColors.tertiary,
              label: 'Recorrência',
              value: task.recurrence,
            ),
            const SizedBox(height: NinhoSpacing.stackMd),
            _DetailRow(
              icon: Icons.calendar_today_outlined,
              iconColor: NinhoColors.onSurfaceVariant,
              label: 'Início',
              value: task.startDate,
            ),
            const SizedBox(height: NinhoSpacing.stackMd),
            _DetailRow(
              icon: Icons.auto_awesome,
              iconColor: NinhoColors.primary,
              iconBackground: NinhoColors.primaryFixed,
              label: 'Recompensa',
              value: '${task.reward} poeiras',
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.icon,
    this.iconColor,
    this.iconBackground = NinhoColors.surfaceContainerHigh,
    this.avatar,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? iconColor;
  final Color iconBackground;
  final String? avatar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: avatar == null ? iconBackground : NinhoColors.primaryFixed,
            shape: BoxShape.circle,
          ),
          child: avatar == null
              ? Icon(icon, color: iconColor, size: 22)
              : Text(
                  avatar!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: NinhoColors.primary,
                    letterSpacing: 0,
                  ),
                ),
        ),
        const SizedBox(width: NinhoSpacing.stackMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: NinhoColors.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: NinhoColors.onBackground,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Description extends StatelessWidget {
  const _Description({required this.task});

  final TaskDemo task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Detalhes',
          style: theme.textTheme.titleMedium?.copyWith(
            color: NinhoColors.onBackground,
          ),
        ),
        const SizedBox(height: NinhoSpacing.stackSm),
        DecoratedBox(
          decoration: BoxDecoration(
            color: NinhoColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(NinhoRadii.md),
            border: Border.all(color: NinhoColors.surfaceVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(NinhoSpacing.stackMd),
            child: Text(
              task.description,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: NinhoColors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _History extends StatelessWidget {
  const _History();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Últimas vezes',
          style: theme.textTheme.titleMedium?.copyWith(
            color: NinhoColors.onBackground,
          ),
        ),
        const SizedBox(height: NinhoSpacing.stackSm),
        const SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              _HistoryTile(
                icon: Icons.local_dining_outlined,
                background: NinhoColors.secondaryContainer,
              ),
              SizedBox(width: NinhoSpacing.stackMd),
              _HistoryTile(
                icon: Icons.countertops_outlined,
                background: NinhoColors.primaryFixed,
              ),
              SizedBox(width: NinhoSpacing.stackMd),
              _HistoryTile(
                icon: Icons.photo_library_outlined,
                background: NinhoColors.surfaceContainerHigh,
                foreground: NinhoColors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.icon,
    required this.background,
    this.foreground = NinhoColors.primary,
  });

  final IconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 96,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(NinhoRadii.md),
        ),
        child: Icon(icon, color: foreground, size: 32),
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({required this.task});

  final TaskDemo task;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: NinhoColors.surfaceContainer,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14944931),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            NinhoSpacing.marginMobile,
            NinhoSpacing.stackMd,
            NinhoSpacing.marginMobile,
            bottom > 0 ? 0 : NinhoSpacing.stackSm,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.icon(
                  key: const Key('task_detail_complete_button'),
                  onPressed: () {
                    context.go('${NinhoRoutes.taskDetail}/${task.id}/complete');
                  },
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Marcar como feita'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                ),
                const SizedBox(height: NinhoSpacing.stackMd),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ActionShortcut(
                      icon: Icons.edit_outlined,
                      label: 'Editar',
                      onTap: () => context.go(
                        '${NinhoRoutes.taskDetail}/${task.id}/edit',
                      ),
                    ),
                    _ActionShortcut(
                      icon: Icons.swap_horiz,
                      label: 'Transferir',
                      badge: '-5',
                      onTap: () {},
                    ),
                    _ActionShortcut(
                      icon: Icons.delete_outline,
                      label: 'Excluir',
                      onTap: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionShortcut extends StatelessWidget {
  const _ActionShortcut({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(NinhoRadii.lg),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: NinhoColors.surfaceContainerHigh,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: NinhoColors.onSurfaceVariant),
                ),
                if (badge != null)
                  Positioned(
                    top: -4,
                    right: -8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: NinhoColors.error,
                        borderRadius: BorderRadius.circular(NinhoRadii.full),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        child: Text(
                          badge!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                            color: NinhoColors.onError,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: NinhoColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WarmShadow extends BoxShadow {
  const _WarmShadow()
    : super(
        color: const Color(0x14944931),
        blurRadius: 16,
        offset: const Offset(0, 4),
      );
}
