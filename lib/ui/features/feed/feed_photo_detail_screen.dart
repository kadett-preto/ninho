import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/feed_repository.dart';
import '../../../data/repositories/suggestions_repository.dart'
    show TaskDifficulty;
import '../../core/colors.dart';
import '../../core/routes.dart';
import '../../core/spacing.dart';
import 'feed_photo_detail_controller.dart';

// Stitch — "Detalhe da Foto — Mural" (7f0a41702d9842d9b34d38fccbabb8ab).
class FeedPhotoDetailScreen extends StatelessWidget {
  const FeedPhotoDetailScreen({
    super.key,
    required this.eventId,
    this.repository,
  });

  final String eventId;
  final FeedRepository? repository;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<FeedPhotoDetailController>(
      create: (_) =>
          FeedPhotoDetailController(eventId: eventId, repository: repository)
            ..load(),
      child: const _View(),
    );
  }
}

class _View extends StatelessWidget {
  const _View();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<FeedPhotoDetailController>();
    return Scaffold(
      backgroundColor: NinhoColors.background,
      appBar: AppBar(
        backgroundColor: NinhoColors.background,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          key: const Key('feed_photo_back'),
          icon: const Icon(Icons.arrow_back, color: NinhoColors.primary),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(NinhoRoutes.home);
            }
          },
        ),
        title: Text(
          'mural',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: NinhoColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          PopupMenuButton<_PhotoMenuAction>(
            key: const Key('feed_photo_menu'),
            icon: const Icon(Icons.more_vert, color: NinhoColors.primary),
            onSelected: (action) => _handleMenu(context, action),
            itemBuilder: (_) {
              final detail = ctrl.detail;
              return [
                const PopupMenuItem(
                  value: _PhotoMenuAction.report,
                  child: Text('Denunciar'),
                ),
                if (detail?.canDeletePhoto ?? false)
                  const PopupMenuItem(
                    value: _PhotoMenuAction.deletePhoto,
                    child: Text('Remover minha foto'),
                  ),
                if (detail?.canModerate ?? false)
                  const PopupMenuItem(
                    value: _PhotoMenuAction.hide,
                    child: Text('Ocultar do mural'),
                  ),
                if (detail?.canModerate ?? false)
                  const PopupMenuItem(
                    value: _PhotoMenuAction.delete,
                    child: Text('Deletar item'),
                  ),
              ];
            },
          ),
        ],
      ),
      body: _Body(controller: ctrl),
      bottomNavigationBar: ctrl.status == FeedPhotoDetailStatus.ready
          ? const _CommentInput()
          : null,
    );
  }

  Future<void> _handleMenu(
    BuildContext context,
    _PhotoMenuAction action,
  ) async {
    final ctrl = context.read<FeedPhotoDetailController>();
    switch (action) {
      case _PhotoMenuAction.report:
        final ok = await ctrl.report();
        if (!context.mounted) return;
        _showSnack(
          context,
          ok
              ? 'Sinal registrado.'
              : ctrl.error ?? 'Não foi possível denunciar.',
        );
      case _PhotoMenuAction.deletePhoto:
        final confirmed = await _confirm(
          context,
          title: 'Remover foto?',
          body: 'A foto sai do mural para todos os moradores.',
          confirmLabel: 'Remover',
        );
        if (!confirmed || !context.mounted) return;
        final ok = await ctrl.deleteOwnPhoto();
        if (!context.mounted) return;
        if (ok) {
          _showSnack(context, 'Foto removida do mural.');
          context.go(NinhoRoutes.feed);
        } else {
          _showSnack(context, ctrl.error ?? 'Não foi possível remover.');
        }
      case _PhotoMenuAction.hide:
        final confirmed = await _confirm(
          context,
          title: 'Ocultar item?',
          body: 'O item deixa de aparecer no mural dos moradores.',
          confirmLabel: 'Ocultar',
        );
        if (!confirmed || !context.mounted) return;
        final ok = await ctrl.hide();
        if (!context.mounted) return;
        if (ok) {
          _showSnack(context, 'Item ocultado do mural.');
          context.go(NinhoRoutes.feed);
        } else {
          _showSnack(context, ctrl.error ?? 'Não foi possível ocultar.');
        }
      case _PhotoMenuAction.delete:
        final confirmed = await _confirm(
          context,
          title: 'Deletar item?',
          body: 'Esta ação remove o item do mural.',
          confirmLabel: 'Deletar',
        );
        if (!confirmed || !context.mounted) return;
        final ok = await ctrl.delete();
        if (!context.mounted) return;
        if (ok) {
          _showSnack(context, 'Item deletado do mural.');
          context.go(NinhoRoutes.feed);
        } else {
          _showSnack(context, ctrl.error ?? 'Não foi possível deletar.');
        }
    }
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

enum _PhotoMenuAction { report, deletePhoto, hide, delete }

class _Body extends StatelessWidget {
  const _Body({required this.controller});
  final FeedPhotoDetailController controller;

  @override
  Widget build(BuildContext context) {
    switch (controller.status) {
      case FeedPhotoDetailStatus.idle:
      case FeedPhotoDetailStatus.loading:
        return const Center(
          child: CircularProgressIndicator(color: NinhoColors.primary),
        );
      case FeedPhotoDetailStatus.error:
        return _ErrorView(
          message: controller.error ?? 'Não foi possível abrir esta foto.',
        );
      case FeedPhotoDetailStatus.ready:
        return _Content(detail: controller.detail!);
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
          key: const Key('feed_photo_error'),
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: NinhoColors.error),
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.detail});
  final FeedPhotoDetail detail;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              NinhoSpacing.marginMobile,
              NinhoSpacing.stackSm,
              NinhoSpacing.marginMobile,
              120,
            ),
            children: [
              _PhotoCard(url: detail.photoUrl),
              const SizedBox(height: NinhoSpacing.stackMd),
              _AuthorRow(detail: detail),
              const SizedBox(height: NinhoSpacing.stackMd),
              Text(
                detail.caption,
                key: const Key('feed_photo_caption'),
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: NinhoColors.onSurface),
              ),
              const SizedBox(height: NinhoSpacing.stackSm),
              _TaskContext(detail: detail),
              const SizedBox(height: NinhoSpacing.stackMd),
              _ReactionRow(detail: detail),
              const SizedBox(height: NinhoSpacing.stackLg),
              const Divider(color: NinhoColors.surfaceVariant),
              const SizedBox(height: NinhoSpacing.stackMd),
              _CommentsSection(comments: detail.comments),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({required this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(NinhoRadii.xl),
        child: DecoratedBox(
          decoration: const BoxDecoration(color: NinhoColors.surfaceContainer),
          child: url == null
              ? const Center(
                  child: Icon(
                    Icons.photo_outlined,
                    size: 56,
                    color: NinhoColors.outline,
                  ),
                )
              : Image.network(
                  url!,
                  key: const Key('feed_photo_image'),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      size: 56,
                      color: NinhoColors.outline,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _AuthorRow extends StatelessWidget {
  const _AuthorRow({required this.detail});
  final FeedPhotoDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: NinhoColors.secondaryFixed,
          child: Text(
            detail.actorLabel.characters.first.toUpperCase(),
            style: theme.textTheme.titleMedium?.copyWith(
              color: NinhoColors.onSecondaryFixedVariant,
            ),
          ),
        ),
        const SizedBox(width: NinhoSpacing.stackSm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                detail.actorLabel,
                key: const Key('feed_photo_author'),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: NinhoColors.onSurface,
                ),
              ),
              Text(
                _relativeTime(detail.createdAt),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: NinhoColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TaskContext extends StatelessWidget {
  const _TaskContext({required this.detail});
  final FeedPhotoDetail detail;

  @override
  Widget build(BuildContext context) {
    final room = detail.roomName;
    return Wrap(
      spacing: NinhoSpacing.stackSm,
      runSpacing: NinhoSpacing.stackSm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          detail.taskTitle,
          key: const Key('feed_photo_task_title'),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: NinhoColors.onSurfaceVariant),
        ),
        if (room != null && room.isNotEmpty) ...[
          Text(
            '·',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: NinhoColors.onSurfaceVariant,
            ),
          ),
          Text(
            room,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: NinhoColors.onSurfaceVariant,
            ),
          ),
        ],
        _DifficultyBadge(difficulty: detail.difficulty),
      ],
    );
  }
}

class _ReactionRow extends StatelessWidget {
  const _ReactionRow({required this.detail});
  final FeedPhotoDetail detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ReactionButton(
          keyValue: 'feed_reaction_heart',
          icon: Icons.favorite,
          color: NinhoColors.primary,
          count: detail.heartCount,
        ),
        const SizedBox(width: NinhoSpacing.stackSm),
        _ReactionButton(
          keyValue: 'feed_reaction_celebrate',
          icon: Icons.celebration,
          color: NinhoColors.secondary,
          count: detail.celebrationCount,
        ),
      ],
    );
  }
}

class _ReactionButton extends StatelessWidget {
  const _ReactionButton({
    required this.keyValue,
    required this.icon,
    required this.color,
    required this.count,
  });

  final String keyValue;
  final IconData icon;
  final Color color;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: NinhoColors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(NinhoRadii.lg),
      child: InkWell(
        key: Key(keyValue),
        borderRadius: BorderRadius.circular(NinhoRadii.lg),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: NinhoSpacing.stackSm),
              Text(
                '$count',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: NinhoColors.onSurface),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommentsSection extends StatelessWidget {
  const _CommentsSection({required this.comments});
  final List<FeedComment> comments;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Comentários',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: NinhoColors.onSurface),
        ),
        const SizedBox(height: NinhoSpacing.stackMd),
        if (comments.isEmpty)
          Text(
            'Sem comentários ainda.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: NinhoColors.onSurfaceVariant,
            ),
          )
        else
          for (final comment in comments) ...[
            _CommentBubble(comment: comment),
            const SizedBox(height: NinhoSpacing.stackMd),
          ],
      ],
    );
  }
}

class _CommentBubble extends StatelessWidget {
  const _CommentBubble({required this.comment});
  final FeedComment comment;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: NinhoColors.tertiaryFixed,
          child: Text(
            comment.authorLabel.characters.first.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: NinhoColors.onTertiaryFixedVariant,
            ),
          ),
        ),
        const SizedBox(width: NinhoSpacing.stackSm),
        Expanded(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: NinhoColors.surfaceContainerLow,
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(NinhoRadii.lg),
                bottomLeft: Radius.circular(NinhoRadii.lg),
                bottomRight: Radius.circular(NinhoRadii.lg),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    comment.authorLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: NinhoColors.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    comment.body,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: NinhoColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CommentInput extends StatefulWidget {
  const _CommentInput();

  @override
  State<_CommentInput> createState() => _CommentInputState();
}

class _CommentInputState extends State<_CommentInput> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: DecoratedBox(
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            NinhoSpacing.marginMobile,
            12,
            NinhoSpacing.marginMobile,
            12,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('feed_comment_input'),
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: 'Adicione um comentário...',
                    filled: true,
                    fillColor: NinhoColors.surfaceContainerHigh,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(NinhoRadii.full),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: NinhoSpacing.stackSm),
              IconButton.filled(
                key: const Key('feed_comment_send'),
                onPressed: _send,
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _send() {
    if (_controller.text.trim().isEmpty) return;
    _controller.clear();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Comentário enviado.')));
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

String _relativeTime(DateTime value) {
  final now = DateTime.now();
  final diff = now.difference(value);
  final time =
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  if (diff.inHours < 24 && now.day == value.day) return 'Hoje, $time';
  if (diff.inDays == 1) return 'Ontem, $time';
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}, $time';
}
