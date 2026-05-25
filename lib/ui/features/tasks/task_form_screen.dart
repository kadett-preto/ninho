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
import 'task_form_controller.dart';

// Stitch — "Criar Tarefa" (36b5246bf0744fe4878f4a57ba90d84b).
// Mesma tela cobre 6.8 (criar) e 6.9 (editar) — diferenciada por taskId.
class TaskFormScreen extends StatelessWidget {
  const TaskFormScreen({
    super.key,
    this.taskId,
    this.environmentsRepository,
    this.tasksRepository,
    this.currentUserId,
  });

  final String? taskId;
  final EnvironmentsRepository? environmentsRepository;
  final TasksRepository? tasksRepository;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<TaskFormController>(
      create: (_) => TaskFormController(
        taskId: taskId,
        environmentsRepository: environmentsRepository,
        tasksRepository: tasksRepository,
        currentUserId: currentUserId,
      )..load(),
      child: const _TaskFormView(),
    );
  }
}

class _TaskFormView extends StatelessWidget {
  const _TaskFormView();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<TaskFormController>();
    return Scaffold(
      backgroundColor: NinhoColors.background,
      appBar: AppBar(
        backgroundColor: NinhoColors.background,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          key: const Key('task_form_back'),
          icon: const Icon(Icons.arrow_back, color: NinhoColors.primary),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(NinhoRoutes.tasks);
            }
          },
        ),
        title: Text(
          ctrl.isEditing ? 'Editar tarefa' : 'Nova tarefa',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: NinhoColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: _Body(controller: ctrl),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.controller});
  final TaskFormController controller;

  @override
  Widget build(BuildContext context) {
    switch (controller.status) {
      case TaskFormStatus.idle:
      case TaskFormStatus.loading:
        return const Center(
          child: CircularProgressIndicator(color: NinhoColors.primary),
        );
      case TaskFormStatus.error:
        return _ErrorView(message: controller.error ?? 'Erro desconhecido');
      case TaskFormStatus.ready:
      case TaskFormStatus.submitting:
        return _Form(controller: controller);
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
          key: const Key('task_form_error'),
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: NinhoColors.error),
        ),
      ),
    );
  }
}

class _Form extends StatefulWidget {
  const _Form({required this.controller});
  final TaskFormController controller;

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.controller.title);
    _descCtrl = TextEditingController(text: widget.controller.description);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        NinhoSpacing.marginMobile,
        NinhoSpacing.stackMd,
        NinhoSpacing.marginMobile,
        120,
      ),
      children: [
        if (!ctrl.isEditing) ...[
          _ModeCards(),
          const SizedBox(height: NinhoSpacing.stackLg),
        ],
        _Label('Título da tarefa'),
        const SizedBox(height: NinhoSpacing.stackSm),
        TextField(
          key: const Key('task_form_title'),
          controller: _titleCtrl,
          maxLength: 120,
          onChanged: ctrl.setTitle,
          decoration: _underlineDecoration(hint: 'Ex: Lavar a louça'),
        ),
        const SizedBox(height: NinhoSpacing.stackMd),
        _Label('Descrição (opcional)'),
        const SizedBox(height: NinhoSpacing.stackSm),
        TextField(
          key: const Key('task_form_description'),
          controller: _descCtrl,
          maxLines: 3,
          maxLength: 500,
          onChanged: ctrl.setDescription,
          decoration: _underlineDecoration(hint: 'Detalhes da tarefa...'),
        ),
        const SizedBox(height: NinhoSpacing.stackMd),
        _Label('Cômodo'),
        const SizedBox(height: NinhoSpacing.stackSm),
        _RoomDropdown(controller: ctrl),
        const SizedBox(height: NinhoSpacing.stackMd),
        _Label('Responsável'),
        const SizedBox(height: NinhoSpacing.stackSm),
        _AssigneeRow(controller: ctrl),
        const SizedBox(height: NinhoSpacing.stackMd),
        _Label('Dificuldade'),
        const SizedBox(height: NinhoSpacing.stackSm),
        _DifficultyRow(controller: ctrl),
        const SizedBox(height: NinhoSpacing.stackMd),
        _Label('Data de início'),
        const SizedBox(height: NinhoSpacing.stackSm),
        _DateField(controller: ctrl),
        const SizedBox(height: NinhoSpacing.stackMd),
        _Label('Recorrência'),
        const SizedBox(height: NinhoSpacing.stackSm),
        _RecurrenceChips(controller: ctrl),
        const SizedBox(height: NinhoSpacing.stackLg),
        FilledButton.icon(
          key: const Key('task_form_submit'),
          onPressed: ctrl.status == TaskFormStatus.submitting
              ? null
              : () => _onSubmit(context, ctrl),
          icon: ctrl.status == TaskFormStatus.submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check),
          label: Text(ctrl.isEditing ? 'Salvar alterações' : 'Salvar tarefa'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
        ),
        if (ctrl.isEditing) ...[
          const SizedBox(height: NinhoSpacing.stackMd),
          OutlinedButton.icon(
            key: const Key('task_form_archive'),
            onPressed: ctrl.status == TaskFormStatus.submitting
                ? null
                : () => _onArchive(context, ctrl),
            icon: const Icon(Icons.archive_outlined),
            label: const Text('Arquivar tarefa'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              foregroundColor: NinhoColors.error,
              side: const BorderSide(color: NinhoColors.outlineVariant),
            ),
          ),
        ],
        if (ctrl.error != null) ...[
          const SizedBox(height: NinhoSpacing.stackMd),
          Text(
            ctrl.error!,
            key: const Key('task_form_inline_error'),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: NinhoColors.error),
          ),
        ],
      ],
    );
  }

  InputDecoration _underlineDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: NinhoColors.surfaceContainerLow,
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.transparent, width: 2),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: NinhoColors.secondary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  Future<void> _onSubmit(BuildContext context, TaskFormController ctrl) async {
    final result = await ctrl.submit();
    if (!context.mounted) return;
    if (result == null) {
      final msg = ctrl.error;
      if (msg != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.created ? 'Tarefa criada.' : 'Tarefa atualizada.'),
      ),
    );
    context.go(NinhoRoutes.tasks);
  }

  Future<void> _onArchive(BuildContext context, TaskFormController ctrl) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Arquivar tarefa?'),
          content: const Text(
            'A tarefa sai da lista ativa. O histórico continua disponível.',
          ),
          actions: [
            TextButton(
              key: const Key('task_form_archive_cancel'),
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              key: const Key('task_form_archive_confirm'),
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(backgroundColor: NinhoColors.error),
              child: const Text('Arquivar'),
            ),
          ],
        );
      },
    );
    if (confirm != true) return;
    final ok = await ctrl.archive();
    if (!context.mounted) return;
    if (!ok) {
      final msg = ctrl.error;
      if (msg != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
      return;
    }
    context.go(NinhoRoutes.tasks);
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: NinhoColors.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      ),
    );
  }
}

class _ModeCards extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: NinhoColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(NinhoRadii.xl),
            border: Border.all(color: NinhoColors.primary, width: 2),
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
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: NinhoColors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.edit,
                    color: NinhoColors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: NinhoSpacing.stackMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Criar manualmente',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: NinhoColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Você define tudo.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: NinhoColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: NinhoSpacing.stackMd),
        Material(
          color: Colors.transparent,
          child: InkWell(
            key: const Key('task_form_use_ia'),
            borderRadius: BorderRadius.circular(NinhoRadii.xl),
            onTap: () => context.go(NinhoRoutes.suggestions),
            child: Ink(
              decoration: BoxDecoration(
                color: NinhoColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(NinhoRadii.xl),
                border: Border.all(color: NinhoColors.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(NinhoSpacing.paddingCard),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: NinhoColors.tertiaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: NinhoColors.onTertiaryContainer,
                      ),
                    ),
                    const SizedBox(width: NinhoSpacing.stackMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Gerar com IA',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: NinhoColors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'A gente sugere tarefas pelos seus cômodos.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: NinhoColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoomDropdown extends StatelessWidget {
  const _RoomDropdown({required this.controller});
  final TaskFormController controller;

  @override
  Widget build(BuildContext context) {
    final items = controller.rooms;
    final selected = controller.roomId;
    // Se o roomId atual não está mais entre os cômodos do ninho (raro mas
    // possível se o cômodo foi deletado), tratamos como "sem cômodo" para
    // evitar assert do DropdownButton.
    final knownIds = {for (final r in items) r.id};
    final value = (selected != null && knownIds.contains(selected))
        ? selected
        : null;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: NinhoColors.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(NinhoRadii.regular),
        ),
        border: const Border(
          bottom: BorderSide(color: Colors.transparent, width: 2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String?>(
            key: const Key('task_form_room'),
            value: value,
            isExpanded: true,
            hint: const Text('Sem cômodo'),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Sem cômodo'),
              ),
              for (final r in items)
                DropdownMenuItem<String?>(value: r.id, child: Text(r.name)),
            ],
            onChanged: controller.setRoom,
          ),
        ),
      ),
    );
  }
}

class _AssigneeRow extends StatelessWidget {
  const _AssigneeRow({required this.controller});
  final TaskFormController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final assigned =
        controller.assigneeId != null &&
        controller.assigneeId == controller.currentUserId;
    final label = assigned ? 'Eu' : 'Sem responsável';
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: NinhoColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(NinhoRadii.lg),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: assigned
                  ? NinhoColors.secondaryContainer
                  : NinhoColors.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: Text(
              assigned ? 'E' : '—',
              style: theme.textTheme.labelSmall?.copyWith(
                color: assigned
                    ? NinhoColors.onSecondaryContainer
                    : NinhoColors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(width: NinhoSpacing.stackSm),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: NinhoColors.onSurface,
              ),
            ),
          ),
          IconButton(
            key: const Key('task_form_toggle_assignee'),
            tooltip: assigned ? 'Remover responsável' : 'Atribuir a mim',
            icon: const Icon(Icons.swap_horiz),
            color: NinhoColors.onSurfaceVariant,
            onPressed: controller.toggleAssignee,
          ),
        ],
      ),
    );
  }
}

class _DifficultyRow extends StatelessWidget {
  const _DifficultyRow({required this.controller});
  final TaskFormController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _DifficultyButton(
            value: TaskDifficulty.mamao,
            label: 'Mamão 🥭',
            controller: controller,
            keyValue: 'task_form_difficulty_mamao',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _DifficultyButton(
            value: TaskDifficulty.embacada,
            label: 'Embaçada 😅',
            controller: controller,
            keyValue: 'task_form_difficulty_embacada',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _DifficultyButton(
            value: TaskDifficulty.treta,
            label: 'Treta 😤',
            controller: controller,
            keyValue: 'task_form_difficulty_treta',
          ),
        ),
      ],
    );
  }
}

class _DifficultyButton extends StatelessWidget {
  const _DifficultyButton({
    required this.value,
    required this.label,
    required this.controller,
    required this.keyValue,
  });

  final TaskDifficulty value;
  final String label;
  final TaskFormController controller;
  final String keyValue;

  @override
  Widget build(BuildContext context) {
    final selected = controller.difficulty == value;
    final (bg, fg) = switch (value) {
      TaskDifficulty.mamao => (
        NinhoColors.secondaryFixedDim,
        NinhoColors.onSecondaryFixedVariant,
      ),
      TaskDifficulty.embacada => (
        NinhoColors.tertiaryFixedDim,
        NinhoColors.onTertiaryFixedVariant,
      ),
      TaskDifficulty.treta => (
        NinhoColors.primaryFixedDim,
        NinhoColors.onPrimaryFixedVariant,
      ),
    };
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key(keyValue),
        borderRadius: BorderRadius.circular(NinhoRadii.full),
        onTap: () => controller.setDifficulty(value),
        child: Ink(
          decoration: BoxDecoration(
            color: selected ? bg : NinhoColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(NinhoRadii.full),
            border: selected
                ? null
                : Border.all(color: NinhoColors.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: selected ? fg : NinhoColors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.controller});
  final TaskFormController controller;

  @override
  Widget build(BuildContext context) {
    final d = controller.startDate;
    final label =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    return InkWell(
      key: const Key('task_form_date'),
      borderRadius: BorderRadius.circular(NinhoRadii.regular),
      onTap: () async {
        final now = DateTime.now();
        // Locale do picker fica para Fase 12 (i18n). Default Material
        // (inglês) é aceitável até lá.
        final picked = await showDatePicker(
          context: context,
          initialDate: controller.startDate,
          firstDate: DateTime(now.year - 1),
          lastDate: DateTime(now.year + 2),
        );
        if (picked != null) controller.setStartDate(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: NinhoColors.surfaceContainerLow,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(NinhoRadii.regular),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: NinhoColors.onSurface),
              ),
            ),
            const Icon(
              Icons.calendar_today_outlined,
              size: 20,
              color: NinhoColors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecurrenceChips extends StatelessWidget {
  const _RecurrenceChips({required this.controller});
  final TaskFormController controller;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final r in TaskRecurrence.values)
          _RecurrenceChip(value: r, label: r.label, controller: controller),
      ],
    );
  }
}

class _RecurrenceChip extends StatelessWidget {
  const _RecurrenceChip({
    required this.value,
    required this.label,
    required this.controller,
  });

  final TaskRecurrence value;
  final String label;
  final TaskFormController controller;

  @override
  Widget build(BuildContext context) {
    final selected = controller.recurrence == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('task_form_recurrence_${value.name}'),
        borderRadius: BorderRadius.circular(NinhoRadii.lg),
        onTap: () => controller.setRecurrence(value),
        child: Ink(
          decoration: BoxDecoration(
            color: selected
                ? NinhoColors.primaryContainer
                : NinhoColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(NinhoRadii.lg),
            border: selected
                ? null
                : Border.all(color: NinhoColors.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: selected
                    ? NinhoColors.onPrimaryContainer
                    : NinhoColors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
