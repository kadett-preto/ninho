import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/environments_repository.dart';
import '../../../data/repositories/feed_repository.dart';
import '../../../data/repositories/suggestions_repository.dart'
    show TaskDifficulty;
import '../../core/colors.dart';
import '../../core/routes.dart';
import '../../core/spacing.dart';
import '../../core/widgets/ninho_bottom_nav.dart';
import 'feed_controller.dart';

// Stitch — "Mural do Ambiente" (5a57a56c0a2e41a0ad5b185827798f95).
class FeedScreen extends StatelessWidget {
  const FeedScreen({
    super.key,
    this.environmentsRepository,
    this.repository,
    this.realtimeEnabled = true,
  });

  final EnvironmentsRepository? environmentsRepository;
  final FeedRepository? repository;
  final bool realtimeEnabled;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<FeedController>(
      create: (_) => FeedController(
        environmentsRepository: environmentsRepository,
        repository: repository,
        realtimeEnabled: realtimeEnabled,
      )..load(),
      child: const _View(),
    );
  }
}

class _View extends StatelessWidget {
  const _View();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<FeedController>();
    return Scaffold(
      backgroundColor: NinhoColors.background,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(environmentName: ctrl.environmentName),
                Expanded(child: _Body(controller: ctrl)),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: NinhoBottomNav(
        active: NinhoTab.feed,
        onTap: (tab) => _onTabTap(context, tab),
      ),
    );
  }

  void _onTabTap(BuildContext context, NinhoTab tab) {
    switch (tab) {
      case NinhoTab.feed:
        return;
      case NinhoTab.home:
        context.go(NinhoRoutes.home);
      case NinhoTab.tasks:
        context.go(NinhoRoutes.tasks);
      case NinhoTab.shop:
        context.go(NinhoRoutes.shop);
      case NinhoTab.profile:
        context.go(NinhoRoutes.profile);
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.environmentName});
  final String environmentName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        NinhoSpacing.marginMobile,
        NinhoSpacing.stackMd,
        NinhoSpacing.marginMobile,
        NinhoSpacing.stackSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'mural',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: NinhoColors.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            environmentName,
            key: const Key('feed_environment_name'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: NinhoColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.controller});
  final FeedController controller;

  @override
  Widget build(BuildContext context) {
    switch (controller.status) {
      case FeedStatus.idle:
      case FeedStatus.loading:
        return const Center(
          child: CircularProgressIndicator(color: NinhoColors.primary),
        );
      case FeedStatus.error:
        return _ErrorView(message: controller.error ?? 'Erro desconhecido');
      case FeedStatus.ready:
        if (controller.items.isEmpty) return const _EmptyView();
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            NinhoSpacing.marginMobile,
            NinhoSpacing.stackMd,
            NinhoSpacing.marginMobile,
            120,
          ),
          itemBuilder: (_, index) =>
              _TimelineCard(item: controller.items[index]),
          separatorBuilder: (_, _) =>
              const SizedBox(height: NinhoSpacing.stackMd),
          itemCount: controller.items.length,
        );
    }
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
          key: const Key('feed_error'),
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: NinhoColors.error),
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(NinhoSpacing.marginMobile),
        child: Text(
          'As próximas conclusões aparecem aqui.',
          key: const Key('feed_empty'),
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: NinhoColors.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.item});
  final FeedTimelineItem item;

  @override
  Widget build(BuildContext context) {
    if (item.hasPhoto) return _PhotoCard(item: item);
    if (item.isStreak) return _StreakCard(item: item);
    if (item.isWeeklySummary) return _SummaryCard(item: item);
    if (item.isNewMember) return _NewMemberCard(item: item);
    return _CompletedTaskCard(item: item);
  }
}

class _CompletedTaskCard extends StatelessWidget {
  const _CompletedTaskCard({required this.item});
  final FeedTimelineItem item;

  @override
  Widget build(BuildContext context) {
    final title = item.title ?? 'tarefa';
    return _BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Avatar(label: item.actorLabel),
              const SizedBox(width: NinhoSpacing.unit),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: '${item.actorLabel} concluiu ',
                    children: [
                      TextSpan(
                        text: title,
                        style: const TextStyle(
                          color: NinhoColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  key: const Key('feed_completed_text'),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: NinhoColors.onSurface),
                ),
              ),
              Text(
                _relativeTime(item.createdAt),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: NinhoColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (item.difficulty != null) ...[
            const SizedBox(height: NinhoSpacing.stackSm),
            Align(
              alignment: Alignment.centerRight,
              child: _DifficultyBadge(difficulty: item.difficulty!),
            ),
          ],
        ],
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({required this.item});
  final FeedTimelineItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: NinhoColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(NinhoRadii.xl),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('feed_photo_card_${item.id}'),
        onTap: () => context.go('${NinhoRoutes.feed}/${item.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _Avatar(label: item.actorLabel),
                  const SizedBox(width: NinhoSpacing.unit),
                  Expanded(
                    child: Text(
                      item.actorLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: NinhoColors.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    _relativeTime(item.createdAt),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: NinhoColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.network(
                item.photoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: NinhoColors.surfaceContainerHigh,
                  child: Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: NinhoColors.outline,
                      size: 44,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(NinhoSpacing.paddingCard),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.caption,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: NinhoColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: NinhoSpacing.stackSm),
                  _ReactionRow(item: item),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.item});
  final FeedTimelineItem item;

  @override
  Widget build(BuildContext context) {
    final count = item.streakCount ?? 0;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: NinhoColors.primary,
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
        child: Row(
          children: [
            const CircleAvatar(
              radius: 24,
              backgroundColor: NinhoColors.primaryFixed,
              child: Icon(
                Icons.local_fire_department,
                color: NinhoColors.primary,
              ),
            ),
            const SizedBox(width: NinhoSpacing.stackMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count dias de streak!',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: NinhoColors.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    item.summary ?? 'O ninho está em harmonia.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: NinhoColors.primaryFixed,
                    ),
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

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.item});
  final FeedTimelineItem item;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: NinhoColors.secondaryContainer,
        borderRadius: BorderRadius.circular(NinhoRadii.xl),
        border: Border.all(color: NinhoColors.secondaryFixedDim),
      ),
      child: Padding(
        padding: const EdgeInsets.all(NinhoSpacing.paddingCard),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: NinhoColors.secondary),
                const SizedBox(width: NinhoSpacing.stackSm),
                Expanded(
                  child: Text(
                    'Resumo da semana',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: NinhoColors.onSecondaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: NinhoSpacing.stackSm),
            Text(
              item.summary ?? 'Semana registrada no mural.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: NinhoColors.onSecondaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewMemberCard extends StatelessWidget {
  const _NewMemberCard({required this.item});
  final FeedTimelineItem item;

  @override
  Widget build(BuildContext context) {
    return _BaseCard(
      color: NinhoColors.surfaceContainerLow,
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${item.memberName ?? item.actorLabel} entrou no ninho',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: NinhoColors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            _relativeTime(item.createdAt),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: NinhoColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _BaseCard extends StatelessWidget {
  const _BaseCard({
    required this.child,
    this.color = NinhoColors.surfaceContainerLowest,
  });

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
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
        child: child,
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: NinhoColors.primaryFixed,
      child: Text(
        label.characters.first.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: NinhoColors.onPrimaryFixedVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ReactionRow extends StatelessWidget {
  const _ReactionRow({required this.item});
  final FeedTimelineItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ReactionPill(icon: Icons.favorite_border, count: item.heartCount),
        const SizedBox(width: NinhoSpacing.unit),
        _ReactionPill(icon: Icons.sign_language, count: item.celebrationCount),
      ],
    );
  }
}

class _ReactionPill extends StatelessWidget {
  const _ReactionPill({required this.icon, required this.count});
  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: NinhoColors.outlineVariant),
        borderRadius: BorderRadius.circular(NinhoRadii.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: NinhoColors.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: NinhoColors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DifficultyBadge extends StatelessWidget {
  const _DifficultyBadge({required this.difficulty});
  final TaskDifficulty difficulty;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (difficulty) {
      TaskDifficulty.mamao => (
        NinhoColors.secondaryFixed,
        NinhoColors.onSecondaryFixedVariant,
        'Mamão',
      ),
      TaskDifficulty.embacada => (
        NinhoColors.tertiaryFixed,
        NinhoColors.onTertiaryFixedVariant,
        'Embaçada',
      ),
      TaskDifficulty.treta => (
        NinhoColors.primaryFixed,
        NinhoColors.onPrimaryFixedVariant,
        'Treta',
      ),
    };
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
          ),
        ),
      ),
    );
  }
}

// Bottom nav extraído para `lib/ui/core/widgets/ninho_bottom_nav.dart`
// (Fase 12.2).

String _relativeTime(DateTime value) {
  final now = DateTime.now();
  final diff = now.difference(value);
  final time =
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  if (diff.inHours < 24 && now.day == value.day) return 'Hoje, $time';
  if (diff.inDays == 1) return 'Ontem, $time';
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}';
}
