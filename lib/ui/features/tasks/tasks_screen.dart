import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/environments_repository.dart';
import '../../../data/repositories/suggestions_repository.dart'
    show TaskDifficulty;
import '../../../data/repositories/tasks_repository.dart';
import '../../core/colors.dart';
import '../../core/routes.dart';
import '../../core/spacing.dart';
import 'tasks_controller.dart';

// Stitch — "Gerenciamento de Tarefas" (55659509c4af477ea18567f8519ac5a5).
// IDEA.md §5.4 (tasks). Filtros client-side; RLS já isolou o ninho.
class TasksScreen extends StatelessWidget {
  const TasksScreen({
    super.key,
    this.environmentsRepository,
    this.tasksRepository,
    this.currentUserId,
  });

  final EnvironmentsRepository? environmentsRepository;
  final TasksRepository? tasksRepository;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<TasksController>(
      create: (_) => TasksController(
        environmentsRepository: environmentsRepository,
        tasksRepository: tasksRepository,
        currentUserId: currentUserId,
      )..load(),
      child: const _TasksView(),
    );
  }
}

class _TasksView extends StatelessWidget {
  const _TasksView();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<TasksController>();
    return Scaffold(
      backgroundColor: NinhoColors.background,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                const _TopBar(),
                _FilterChips(controller: ctrl),
                _PeriodToggle(controller: ctrl),
                Expanded(child: _Body(controller: ctrl)),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _TasksBottomNav(onTap: (i) => _onTabTap(context, i)),
    );
  }

  void _onTabTap(BuildContext context, int index) {
    if (index == 1) return;
    if (index == 0) context.go(NinhoRoutes.home);
    if (index == 3) context.go(NinhoRoutes.shop);
    // Mural/Perfil ainda não têm rota dedicada.
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        NinhoSpacing.marginMobile,
        NinhoSpacing.stackMd,
        NinhoSpacing.marginMobile,
        NinhoSpacing.stackSm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Tarefas',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: NinhoColors.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          DecoratedBox(
            decoration: const BoxDecoration(
              color: NinhoColors.primary,
              shape: BoxShape.circle,
              boxShadow: [_WarmShadow()],
            ),
            child: IconButton(
              key: const Key('tasks_add_button'),
              icon: const Icon(Icons.add, color: NinhoColors.onPrimary),
              onPressed: () => context.go('${NinhoRoutes.tasks}/new'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.controller});
  final TasksController controller;

  @override
  Widget build(BuildContext context) {
    final byRoomActive = controller.roomFilter != null;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: NinhoSpacing.marginMobile,
        vertical: NinhoSpacing.stackSm,
      ),
      child: Row(
        children: [
          _Chip(
            label: 'Todas',
            selected: controller.filter == TaskFilter.all && !byRoomActive,
            onTap: () {
              controller.clearRoomFilter();
              controller.setFilter(TaskFilter.all);
            },
            keyValue: 'tasks_chip_all',
          ),
          const SizedBox(width: 8),
          _Chip(
            label: 'Minhas',
            selected: controller.filter == TaskFilter.mine,
            onTap: () => controller.setFilter(TaskFilter.mine),
            keyValue: 'tasks_chip_mine',
          ),
          const SizedBox(width: 8),
          _Chip(
            label: byRoomActive
                ? (controller.rooms[controller.roomFilter!]?.name ?? 'Cômodo')
                : 'Por cômodo',
            selected: byRoomActive,
            onTap: () => _openRoomPicker(context),
            keyValue: 'tasks_chip_room',
          ),
          const SizedBox(width: 8),
          _Chip(
            label: 'Pendentes',
            selected: controller.filter == TaskFilter.pending,
            onTap: () => controller.setFilter(TaskFilter.pending),
            keyValue: 'tasks_chip_pending',
          ),
          const SizedBox(width: 8),
          _Chip(
            label: 'Concluídas',
            selected: controller.filter == TaskFilter.completed,
            onTap: () => controller.setFilter(TaskFilter.completed),
            keyValue: 'tasks_chip_completed',
          ),
        ],
      ),
    );
  }

  Future<void> _openRoomPicker(BuildContext context) async {
    final rooms = controller.rooms.values.toList(growable: false);
    if (rooms.isEmpty) return;
    final picked = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: NinhoColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(NinhoSpacing.marginMobile),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: NinhoSpacing.stackMd),
                  child: Text(
                    'Filtrar por cômodo',
                    style: Theme.of(sheetCtx).textTheme.titleMedium,
                  ),
                ),
                if (controller.roomFilter != null)
                  ListTile(
                    key: const Key('tasks_room_picker_clear'),
                    title: const Text('Todos os cômodos'),
                    leading: const Icon(Icons.clear),
                    onTap: () => Navigator.of(sheetCtx).pop(null),
                  ),
                for (final r in rooms)
                  ListTile(
                    key: Key('tasks_room_picker_${r.id}'),
                    title: Text(r.name),
                    trailing: Text(r.sizeCategory.toUpperCase()),
                    selected: controller.roomFilter == r.id,
                    onTap: () => Navigator.of(sheetCtx).pop(r.id),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (!context.mounted) return;
    if (picked == null) {
      controller.clearRoomFilter();
    } else {
      controller.setRoomFilter(picked);
    }
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.keyValue,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String keyValue;

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? NinhoColors.primary
        : NinhoColors.surfaceContainerHigh;
    final fg = selected ? NinhoColors.onPrimary : NinhoColors.onSurface;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key(keyValue),
        borderRadius: BorderRadius.circular(NinhoRadii.lg),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(NinhoRadii.lg),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              label.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PeriodToggle extends StatelessWidget {
  const _PeriodToggle({required this.controller});
  final TasksController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        NinhoSpacing.marginMobile,
        NinhoSpacing.stackSm,
        NinhoSpacing.marginMobile,
        NinhoSpacing.stackSm,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: NinhoColors.surfaceContainer,
          borderRadius: BorderRadius.circular(NinhoRadii.lg),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              Expanded(
                child: _PeriodButton(
                  key: const Key('tasks_period_today'),
                  label: 'Hoje',
                  selected: controller.period == TaskPeriod.today,
                  onTap: () => controller.setPeriod(TaskPeriod.today),
                ),
              ),
              Expanded(
                child: _PeriodButton(
                  key: const Key('tasks_period_week'),
                  label: 'Semana',
                  selected: controller.period == TaskPeriod.week,
                  onTap: () => controller.setPeriod(TaskPeriod.week),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeriodButton extends StatelessWidget {
  const _PeriodButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? NinhoColors.surfaceContainerLowest : Colors.transparent,
      borderRadius: BorderRadius.circular(NinhoRadii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(NinhoRadii.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: selected
                  ? NinhoColors.onSurface
                  : NinhoColors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.controller});
  final TasksController controller;

  @override
  Widget build(BuildContext context) {
    switch (controller.status) {
      case TasksScreenStatus.idle:
      case TasksScreenStatus.loading:
        return const Center(
          child: CircularProgressIndicator(color: NinhoColors.primary),
        );
      case TasksScreenStatus.error:
        return _ErrorView(message: controller.error ?? 'Erro desconhecido');
      case TasksScreenStatus.ready:
        final filtered = controller.filteredItems();
        if (filtered.isEmpty) {
          return const _EmptyView();
        }
        return ListView.separated(
          key: const Key('tasks_list'),
          padding: const EdgeInsets.fromLTRB(
            NinhoSpacing.marginMobile,
            NinhoSpacing.stackSm,
            NinhoSpacing.marginMobile,
            120,
          ),
          itemCount: filtered.length,
          separatorBuilder: (_, _) =>
              const SizedBox(height: NinhoSpacing.stackMd),
          itemBuilder: (_, i) =>
              _TaskCard(task: filtered[i], controller: controller),
        );
    }
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(NinhoSpacing.marginMobile),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.task_alt,
              size: 56,
              color: NinhoColors.outlineVariant,
            ),
            const SizedBox(height: NinhoSpacing.stackMd),
            Text(
              'Nada por aqui',
              key: const Key('tasks_empty_title'),
              style: theme.textTheme.titleMedium?.copyWith(
                color: NinhoColors.onSurface,
              ),
            ),
            const SizedBox(height: NinhoSpacing.stackSm),
            Text(
              'Mude o filtro ou peça sugestões da IA pra começar.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: NinhoColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: NinhoSpacing.stackLg),
            FilledButton.icon(
              key: const Key('tasks_empty_suggestions_cta'),
              onPressed: () => context.go(NinhoRoutes.suggestions),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Sugestões da IA'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(NinhoSpacing.marginMobile),
      child: Center(
        child: Text(
          message,
          key: const Key('tasks_error'),
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: NinhoColors.error),
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, required this.controller});

  final TaskListItem task;
  final TasksController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completed = controller.completedInCurrentPeriod(task);
    final isMine =
        task.assigneeId != null && task.assigneeId == controller.currentUserId;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('task_card_${task.id}'),
        borderRadius: BorderRadius.circular(NinhoRadii.xl),
        onTap: () => context.go('${NinhoRoutes.taskDetail}/${task.id}'),
        child: Ink(
          decoration: BoxDecoration(
            color: completed
                ? NinhoColors.surfaceContainerHigh
                : NinhoColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(NinhoRadii.xl),
            boxShadow: const [_WarmShadow()],
          ),
          child: Opacity(
            opacity: completed ? 0.65 : 1,
            child: Padding(
              padding: const EdgeInsets.all(NinhoSpacing.paddingCard),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CheckMark(
                    completed: completed,
                    onTap: completed
                        ? null
                        : () => context.go(
                            '${NinhoRoutes.taskDetail}/${task.id}/complete',
                          ),
                    keyValue: 'task_check_${task.id}',
                  ),
                  const SizedBox(width: NinhoSpacing.stackMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: NinhoColors.onSurface,
                            fontWeight: FontWeight.w600,
                            decoration: completed
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                        ),
                        if (task.roomName != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            task.roomName!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: NinhoColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: NinhoSpacing.stackSm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _DifficultyBadge(
                        difficulty: task.difficulty,
                        muted: completed,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (task.recurrenceRule != null &&
                              task.recurrenceRule!.isNotEmpty) ...[
                            const Icon(
                              Icons.loop,
                              size: 18,
                              color: NinhoColors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                          ],
                          _MiniAvatar(
                            label: isMine
                                ? 'Eu'
                                : (task.assigneeId == null ? '?' : 'Outro'),
                            highlighted: isMine,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckMark extends StatelessWidget {
  const _CheckMark({
    required this.completed,
    required this.onTap,
    required this.keyValue,
  });

  final bool completed;
  final VoidCallback? onTap;
  final String keyValue;

  @override
  Widget build(BuildContext context) {
    if (completed) {
      return Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: NinhoColors.secondary,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.check,
          size: 16,
          color: NinhoColors.onSecondary,
        ),
      );
    }
    return InkWell(
      key: Key(keyValue),
      borderRadius: BorderRadius.circular(NinhoRadii.full),
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(color: NinhoColors.outline, width: 2),
        ),
      ),
    );
  }
}

class _DifficultyBadge extends StatelessWidget {
  const _DifficultyBadge({required this.difficulty, required this.muted});

  final TaskDifficulty difficulty;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    if (muted) {
      return _BadgePill(
        label: _label(difficulty),
        bg: NinhoColors.surfaceVariant,
        fg: NinhoColors.onSurfaceVariant,
      );
    }
    final (bg, fg) = switch (difficulty) {
      TaskDifficulty.mamao => (
        NinhoColors.secondaryFixed,
        NinhoColors.onSecondaryFixedVariant,
      ),
      TaskDifficulty.embacada => (
        NinhoColors.tertiaryFixed,
        NinhoColors.onTertiaryFixedVariant,
      ),
      TaskDifficulty.treta => (
        NinhoColors.primaryFixed,
        NinhoColors.onPrimaryFixedVariant,
      ),
    };
    return _BadgePill(label: _label(difficulty), bg: bg, fg: fg);
  }

  String _label(TaskDifficulty d) => switch (d) {
    TaskDifficulty.mamao => 'Mamão 🥭',
    TaskDifficulty.embacada => 'Embaçada 😅',
    TaskDifficulty.treta => 'Treta 😤',
  };
}

class _BadgePill extends StatelessWidget {
  const _BadgePill({required this.label, required this.bg, required this.fg});
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(NinhoRadii.full),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: fg,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

class _MiniAvatar extends StatelessWidget {
  const _MiniAvatar({required this.label, required this.highlighted});

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: highlighted
            ? NinhoColors.primaryFixed
            : NinhoColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(NinhoRadii.full),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: highlighted
              ? NinhoColors.onPrimaryFixedVariant
              : NinhoColors.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TasksBottomNav extends StatelessWidget {
  const _TasksBottomNav({required this.onTap});
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
              keyValue: 'tasks_nav_home',
            ),
            _NavItem(
              icon: Icons.checklist,
              label: 'Tarefas',
              selected: true,
              onTap: () => onTap(1),
              keyValue: 'tasks_nav_tasks',
            ),
            _NavItem(
              icon: Icons.grid_view,
              label: 'Mural',
              onTap: () => onTap(2),
              keyValue: 'tasks_nav_feed',
            ),
            _NavItem(
              icon: Icons.storefront_outlined,
              label: 'Loja',
              onTap: () => onTap(3),
              keyValue: 'tasks_nav_shop',
            ),
            _NavItem(
              icon: Icons.person_outline,
              label: 'Perfil',
              onTap: () => onTap(4),
              keyValue: 'tasks_nav_profile',
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
    final color = selected
        ? NinhoColors.primaryContainer
        : NinhoColors.onSurfaceVariant;
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

class _WarmShadow extends BoxShadow {
  const _WarmShadow()
    : super(
        color: const Color(0x14944931),
        blurRadius: 16,
        offset: const Offset(0, 4),
      );
}
