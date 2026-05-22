import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repositories/tasks_repository.dart';
import '../../../data/services/room_photo_service.dart';
import '../../../domain/models/room_photo_draft.dart';
import '../../core/colors.dart';
import '../../core/routes.dart';
import '../../core/spacing.dart';
import 'task_demo_data.dart';

// Stitch — "Confirmação de Tarefa" (d73dc74d40c5425b91bb017fab82b593).
class TaskCompletionScreen extends StatefulWidget {
  const TaskCompletionScreen({
    super.key,
    required this.taskId,
    this.tasksRepository,
    this.photoService,
  });

  final String taskId;
  final TasksRepository? tasksRepository;
  final RoomPhotoService? photoService;

  @override
  State<TaskCompletionScreen> createState() => _TaskCompletionScreenState();
}

class _TaskCompletionScreenState extends State<TaskCompletionScreen> {
  late final TasksRepository _repo;
  late final RoomPhotoService _photoService;
  RoomPhotoDraft? _photoDraft;
  bool _submitting = false;
  bool _pickingPhoto = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repo = widget.tasksRepository ?? const TasksRepository();
    _photoService = widget.photoService ?? ImagePickerRoomPhotoService();
  }

  Future<void> _pickPhoto() async {
    if (_submitting || _pickingPhoto) return;
    final action = await showModalBottomSheet<_PhotoAction>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tirar foto'),
              onTap: () => Navigator.of(context).pop(_PhotoAction.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Escolher da galeria'),
              onTap: () => Navigator.of(context).pop(_PhotoAction.gallery),
            ),
            if (_photoDraft != null)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remover foto'),
                onTap: () => Navigator.of(context).pop(_PhotoAction.remove),
              ),
          ],
        ),
      ),
    );

    if (!mounted) return;
    if (action == null) return;
    if (action == _PhotoAction.remove) {
      setState(() {
        _photoDraft = null;
        _error = null;
      });
      return;
    }

    setState(() {
      _pickingPhoto = true;
      _error = null;
    });
    try {
      final source = switch (action) {
        _PhotoAction.camera => RoomPhotoSource.camera,
        _PhotoAction.gallery => RoomPhotoSource.gallery,
        _PhotoAction.remove => throw StateError('Ação inválida'),
      };
      final draft = await _photoService.pickAndPrepare(source);
      if (!mounted) return;
      if (draft == null) {
        setState(() => _pickingPhoto = false);
        return;
      }
      setState(() {
        _photoDraft = draft;
        _pickingPhoto = false;
      });
    } on RoomPhotoValidationException catch (error) {
      if (!mounted) return;
      setState(() {
        _pickingPhoto = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pickingPhoto = false;
        _error = 'Não conseguimos preparar essa foto.';
      });
    }
  }

  Future<void> _finish({required bool withPhoto}) async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      // A Home ainda usa IDs demo até 6.7 ligar dados reais. UUID real chama a
      // RPC transacional; demo mantém o fluxo visual testável sem tocar backend.
      if (_looksLikeUuid(widget.taskId)) {
        String? photoPath;
        if (withPhoto && _photoDraft != null) {
          photoPath = await _repo.uploadCompletionPhoto(
            taskId: widget.taskId,
            draft: _photoDraft!,
          );
        }
        await _repo.completeTask(taskId: widget.taskId, photoPath: photoPath);
      }
      if (!mounted) return;
      context.go(NinhoRoutes.home);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Não conseguimos concluir agora. Tente de novo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = taskDemoById(widget.taskId);
    return Scaffold(
      backgroundColor: NinhoColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                NinhoSpacing.marginMobile,
                NinhoSpacing.stackLg,
                NinhoSpacing.marginMobile,
                NinhoSpacing.stackLg,
              ),
              children: [
                const SizedBox(height: NinhoSpacing.stackLg),
                const Center(child: _CelebrationMark()),
                const SizedBox(height: NinhoSpacing.stackLg),
                _Headline(task: task),
                const SizedBox(height: NinhoSpacing.stackLg),
                _PhotoCard(
                  hasPhoto: _photoDraft != null,
                  pickingPhoto: _pickingPhoto,
                  onPressed: _pickPhoto,
                ),
                const SizedBox(height: NinhoSpacing.stackMd),
                Text(
                  'A foto aparece no mural pra todo mundo ver.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: NinhoColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: NinhoSpacing.stackLg),
                if (_error != null) ...[
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: NinhoColors.error),
                  ),
                  const SizedBox(height: NinhoSpacing.stackMd),
                ],
                FilledButton(
                  key: const Key('task_completion_finish_button'),
                  onPressed: _submitting
                      ? null
                      : () => _finish(withPhoto: true),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: NinhoColors.onPrimary,
                          ),
                        )
                      : const Text('Concluir tarefa'),
                ),
                const SizedBox(height: NinhoSpacing.stackMd),
                TextButton(
                  key: const Key('task_completion_skip_photo_button'),
                  onPressed: _submitting
                      ? null
                      : () => _finish(withPhoto: false),
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    foregroundColor: NinhoColors.secondary,
                  ),
                  child: const Text('Pular foto'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _PhotoAction { camera, gallery, remove }

bool _looksLikeUuid(String value) {
  return RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(value);
}

class _CelebrationMark extends StatelessWidget {
  const _CelebrationMark();

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 192,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              color: NinhoColors.surfaceContainer,
              shape: BoxShape.circle,
            ),
            child: SizedBox.expand(),
          ),
          const Positioned(
            top: -16,
            left: -16,
            child: _Blob(size: 128, color: NinhoColors.secondaryFixed),
          ),
          const Positioned(
            right: -8,
            bottom: -8,
            child: _Blob(size: 112, color: NinhoColors.primaryFixed),
          ),
          const Positioned(
            top: 64,
            left: 56,
            child: _Blob(size: 80, color: NinhoColors.tertiaryFixed),
          ),
          const Positioned(
            top: 8,
            right: 32,
            child: _Dot(size: 12, color: NinhoColors.primary),
          ),
          const Positioned(
            bottom: 16,
            left: 24,
            child: _Dot(size: 8, color: NinhoColors.secondary),
          ),
          const Positioned(
            left: -16,
            child: _Dot(size: 16, color: NinhoColors.tertiary),
          ),
          const Positioned(
            right: 0,
            bottom: 48,
            child: _Dot(size: 10, color: NinhoColors.primaryContainer),
          ),
          const Icon(Icons.celebration, color: NinhoColors.primary, size: 80),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.72,
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.task});

  final TaskDemo task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          'Mandou bem!',
          textAlign: TextAlign.center,
          style: theme.textTheme.displayLarge?.copyWith(
            color: NinhoColors.onSurface,
          ),
        ),
        const SizedBox(height: NinhoSpacing.stackSm),
        Text(
          task.title,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            color: NinhoColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: NinhoSpacing.stackSm),
        DecoratedBox(
          decoration: BoxDecoration(
            color: NinhoColors.tertiaryFixed,
            borderRadius: BorderRadius.circular(NinhoRadii.full),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14944931),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.auto_awesome,
                  color: NinhoColors.onTertiaryFixed,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '+${task.reward} poeiras',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: NinhoColors.onTertiaryFixed,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({
    required this.hasPhoto,
    required this.pickingPhoto,
    required this.onPressed,
  });

  final bool hasPhoto;
  final bool pickingPhoto;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedButton(
      key: const Key('task_completion_photo_button'),
      onPressed: pickingPhoto ? null : onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(172),
        foregroundColor: NinhoColors.primary,
        side: const BorderSide(
          color: NinhoColors.outlineVariant,
          width: 2,
          strokeAlign: BorderSide.strokeAlignInside,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NinhoRadii.xl),
        ),
        backgroundColor: NinhoColors.surfaceContainerLowest,
      ),
      child: Padding(
        padding: const EdgeInsets.all(NinhoSpacing.paddingCard),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: NinhoColors.surfaceContainer,
                shape: BoxShape.circle,
              ),
              child: pickingPhoto
                  ? const Padding(
                      padding: EdgeInsets.all(18),
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Icon(
                      hasPhoto
                          ? Icons.check_circle_outline
                          : Icons.add_a_photo_outlined,
                      size: 32,
                    ),
            ),
            const SizedBox(height: NinhoSpacing.stackSm),
            Text(
              hasPhoto
                  ? 'Foto pronta para enviar'
                  : 'Adicionar foto do resultado',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: NinhoColors.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hasPhoto ? 'Toque para trocar ou remover' : '(opcional)',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: NinhoColors.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
