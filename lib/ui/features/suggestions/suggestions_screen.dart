import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/environments_repository.dart';
import '../../../data/repositories/suggestions_repository.dart';
import '../../core/colors.dart';
import '../../core/routes.dart';
import '../../core/spacing.dart';
import 'suggestions_controller.dart';

// Stitch — "Sugestões da IA" (10485bb86c9040658544e1afe99d9dd9).
// IDEA.md §6.3 (IA) + §5.4 (tasks).
class SuggestionsScreen extends StatelessWidget {
  const SuggestionsScreen({
    super.key,
    this.environmentsRepository,
    this.suggestionsRepository,
  });

  final EnvironmentsRepository? environmentsRepository;
  final SuggestionsRepository? suggestionsRepository;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SuggestionsController>(
      create: (_) => SuggestionsController(
        environmentsRepository: environmentsRepository,
        suggestionsRepository: suggestionsRepository,
      )..load(),
      child: const _SuggestionsView(),
    );
  }
}

class _SuggestionsView extends StatelessWidget {
  const _SuggestionsView();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SuggestionsController>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: NinhoColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              children: [
                _Header(),
                Expanded(child: _Body(controller: ctrl, theme: theme)),
                _Footer(controller: ctrl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: NinhoColors.background,
      padding: const EdgeInsets.fromLTRB(
        NinhoSpacing.marginMobile,
        24,
        NinhoSpacing.marginMobile,
        16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            key: const Key('suggestions_back'),
            padding: EdgeInsets.zero,
            alignment: Alignment.centerLeft,
            icon: const Icon(Icons.arrow_back, color: NinhoColors.onSurface),
            onPressed: () => context.go(NinhoRoutes.home),
          ),
          const SizedBox(height: NinhoSpacing.stackSm),
          Row(
            children: [
              Flexible(
                child: Text(
                  'Sugestões da IA',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: NinhoColors.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.auto_awesome,
                color: NinhoColors.tertiaryContainer,
                size: 24,
              ),
            ],
          ),
          const SizedBox(height: NinhoSpacing.stackSm),
          Text(
            'Geramos essas tarefas com base nos seus cômodos. Escolha o que faz sentido.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: NinhoColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.controller, required this.theme});
  final SuggestionsController controller;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    switch (controller.status) {
      case SuggestionsStatus.idle:
      case SuggestionsStatus.loading:
        return const Center(
          child: CircularProgressIndicator(color: NinhoColors.primary),
        );
      case SuggestionsStatus.error:
        return _ErrorView(message: controller.error ?? 'Erro desconhecido');
      case SuggestionsStatus.ready:
      case SuggestionsStatus.submitting:
        if (controller.items.isEmpty) {
          return const _ErrorView(
            message: 'A IA não trouxe sugestões. Tente de novo.',
          );
        }
        return _SuggestionsList(controller: controller, theme: theme);
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
          key: const Key('suggestions_error'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: NinhoColors.error,
              ),
        ),
      ),
    );
  }
}

class _SuggestionsList extends StatelessWidget {
  const _SuggestionsList({required this.controller, required this.theme});
  final SuggestionsController controller;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final groups = controller.groupedByRoom();
    return ListView.builder(
      key: const Key('suggestions_list'),
      padding: const EdgeInsets.fromLTRB(
        NinhoSpacing.marginMobile,
        0,
        NinhoSpacing.marginMobile,
        16,
      ),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final entry = groups[index];
        final room = entry.key;
        final items = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: NinhoSpacing.stackLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RoomHeader(room: room),
              const SizedBox(height: NinhoSpacing.stackMd),
              for (final pair in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: NinhoSpacing.stackSm),
                  child: _SuggestionCard(
                    index: pair.key,
                    item: pair.value,
                    controller: controller,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _RoomHeader extends StatelessWidget {
  const _RoomHeader({required this.room});
  final RoomRow room;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          _iconFor(room),
          color: NinhoColors.primary,
          size: 22,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            room.name,
            style: theme.textTheme.titleMedium?.copyWith(
              color: NinhoColors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: NinhoColors.surfaceContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            room.sizeCategory.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: NinhoColors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  IconData _iconFor(RoomRow room) {
    final n = room.name.toLowerCase();
    if (n.contains('cozin')) return Icons.restaurant;
    if (n.contains('banh')) return Icons.bathtub_outlined;
    if (n.contains('quart')) return Icons.bed_outlined;
    if (n.contains('lavand')) return Icons.local_laundry_service_outlined;
    if (n.contains('escrit') || n.contains('home office')) {
      return Icons.desk_outlined;
    }
    return Icons.chair_outlined;
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.index,
    required this.item,
    required this.controller,
  });

  final int index;
  final SuggestionItem item;
  final SuggestionsController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = item.suggestion;
    return InkWell(
      key: Key('suggestion_card_$index'),
      borderRadius: BorderRadius.circular(24),
      onTap: () => controller.toggle(index, !item.selected),
      child: Container(
        padding: const EdgeInsets.all(NinhoSpacing.paddingCard),
        decoration: BoxDecoration(
          color: NinhoColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14944931),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: NinhoColors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (s.description != null && s.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      s.description!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: NinhoColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _DifficultyBadge(difficulty: s.difficulty),
                      _IntervalBadge(intervalDays: s.intervalDays),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: NinhoSpacing.stackMd),
            Column(
              children: [
                Checkbox(
                  key: Key('suggestion_check_$index'),
                  value: item.selected,
                  onChanged: (v) => controller.toggle(index, v ?? false),
                  activeColor: NinhoColors.primary,
                ),
                IconButton(
                  key: Key('suggestion_edit_$index'),
                  icon: const Icon(Icons.edit, size: 20),
                  color: NinhoColors.outline,
                  onPressed: () => _openEdit(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEdit(BuildContext context) async {
    final result = await showDialog<TaskSuggestion>(
      context: context,
      builder: (_) => _EditDialog(initial: item.suggestion),
    );
    if (result != null) {
      controller.edit(index, result);
    }
  }
}

class _DifficultyBadge extends StatelessWidget {
  const _DifficultyBadge({required this.difficulty});
  final TaskDifficulty difficulty;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, emoji, label) = switch (difficulty) {
      TaskDifficulty.mamao => (
          NinhoColors.secondaryContainer,
          NinhoColors.onSecondaryContainer,
          '🥭',
          'Mamão',
        ),
      TaskDifficulty.embacada => (
          NinhoColors.tertiaryFixed,
          NinhoColors.onTertiaryContainer,
          '😅',
          'Embaçada',
        ),
      TaskDifficulty.treta => (
          NinhoColors.primaryFixed,
          NinhoColors.onPrimaryContainer,
          '😤',
          'Treta',
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$emoji $label',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg),
      ),
    );
  }
}

class _IntervalBadge extends StatelessWidget {
  const _IntervalBadge({required this.intervalDays});
  final int intervalDays;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: NinhoColors.surfaceContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _intervalLabel(intervalDays),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: NinhoColors.onSurfaceVariant,
            ),
      ),
    );
  }
}

String _intervalLabel(int days) {
  return switch (days) {
    1 => 'Diária',
    3 => 'A cada 3 dias',
    7 => 'Semanal',
    14 => 'Quinzenal',
    30 => 'Mensal',
    _ => 'A cada $days dias',
  };
}

class _Footer extends StatelessWidget {
  const _Footer({required this.controller});
  final SuggestionsController controller;

  @override
  Widget build(BuildContext context) {
    final hasItems = controller.items.isNotEmpty;
    final canSubmit = controller.selectedCount > 0 &&
        controller.status != SuggestionsStatus.submitting;
    return Container(
      padding: const EdgeInsets.all(NinhoSpacing.marginMobile),
      decoration: const BoxDecoration(
        color: NinhoColors.surfaceContainerLowest,
        border: Border(
          top: BorderSide(color: NinhoColors.surfaceVariant, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x0D944931),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          FilledButton(
            key: const Key('suggestions_submit'),
            onPressed: canSubmit ? () => _submit(context) : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              backgroundColor: NinhoColors.primary,
            ),
            child: controller.status == SuggestionsStatus.submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Adicionar ${controller.selectedCount} tarefa${controller.selectedCount == 1 ? '' : 's'}',
                  ),
          ),
          const SizedBox(height: NinhoSpacing.stackSm),
          TextButton(
            key: const Key('suggestions_toggle_all'),
            onPressed: hasItems ? controller.toggleAll : null,
            child: Text(
              controller.allSelected ? 'Desmarcar todas' : 'Selecionar todas',
              style: const TextStyle(color: NinhoColors.secondary),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    final result = await controller.submit();
    if (!context.mounted) return;
    if (result == null) {
      final msg = controller.error;
      if (msg != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${result.insertedCount} tarefa${result.insertedCount == 1 ? '' : 's'} no ninho.',
        ),
      ),
    );
    context.go(NinhoRoutes.home);
  }
}

class _EditDialog extends StatefulWidget {
  const _EditDialog({required this.initial});
  final TaskSuggestion initial;

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late final TextEditingController _titleCtrl;
  late TaskDifficulty _difficulty;
  late int _interval;

  static const _intervals = [1, 3, 7, 14, 30];

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.initial.title);
    _difficulty = widget.initial.difficulty;
    _interval = widget.initial.intervalDays;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Text('Editar tarefa'),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('edit_title'),
                controller: _titleCtrl,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Título',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<TaskDifficulty>(
                key: const Key('edit_difficulty'),
                initialValue: _difficulty,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Dificuldade',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: TaskDifficulty.mamao,
                    child: Text('Mamão'),
                  ),
                  DropdownMenuItem(
                    value: TaskDifficulty.embacada,
                    child: Text('Embaçada'),
                  ),
                  DropdownMenuItem(
                    value: TaskDifficulty.treta,
                    child: Text('Treta'),
                  ),
                ],
                onChanged: (v) =>
                    setState(() => _difficulty = v ?? _difficulty),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                key: const Key('edit_interval'),
                initialValue: _interval,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Recorrência',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final i in _intervals)
                    DropdownMenuItem(value: i, child: Text(_intervalLabel(i))),
                ],
                onChanged: (v) => setState(() => _interval = v ?? _interval),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('edit_save'),
          onPressed: _save,
          child: const Text('Salvar'),
        ),
      ],
    );
  }

  void _save() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    Navigator.of(context).pop(
      widget.initial.copyWith(
        title: title,
        difficulty: _difficulty,
        intervalDays: _interval,
      ),
    );
  }
}
