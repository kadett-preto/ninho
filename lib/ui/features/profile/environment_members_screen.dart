import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/environments_repository.dart';
import '../../core/colors.dart';
import '../../core/routes.dart';
import '../../core/spacing.dart';

// Stitch — "Lista de Membros - Harmonia Lar" (db4f6fd8).
// Fase 11.8: lista membros ativos do ninho. Owner pode remover ou
// convidar; member regular tem read-only.
enum MembersStatus { idle, loading, ready, error }

class EnvironmentMembersController extends ChangeNotifier {
  EnvironmentMembersController({EnvironmentsRepository? repository})
      : _repo = repository ?? EnvironmentsRepository();

  final EnvironmentsRepository _repo;

  MembersStatus _status = MembersStatus.idle;
  MembersStatus get status => _status;

  String? _error;
  String? get error => _error;

  String? _envId;
  String? get environmentId => _envId;

  EnvironmentSummary? _summary;
  EnvironmentSummary? get summary => _summary;

  List<EnvironmentMember> _members = const [];
  List<EnvironmentMember> get members => _members;

  bool get isOwner => _summary?.isOwner == true;

  Future<void> load() async {
    _status = MembersStatus.loading;
    _error = null;
    notifyListeners();
    try {
      _envId = await _repo.fetchCurrentEnvironmentId();
      if (_envId == null) {
        _status = MembersStatus.error;
        _error = 'Você ainda não tem ninho.';
        notifyListeners();
        return;
      }
      final results = await Future.wait<Object?>([
        _repo.fetchEnvironmentSummary(environmentId: _envId!),
        _repo.listMembers(_envId!),
      ]);
      _summary = results[0] as EnvironmentSummary?;
      _members = results[1] as List<EnvironmentMember>;
      _status = MembersStatus.ready;
    } catch (e) {
      _status = MembersStatus.error;
      _error = _humanize(e);
    } finally {
      notifyListeners();
    }
  }

  Future<bool> removeMember(String userId) async {
    final id = _envId;
    if (id == null) return false;
    try {
      await _repo.removeMember(environmentId: id, userId: userId);
      _members = [
        for (final m in _members)
          if (m.userId != userId) m,
      ];
      notifyListeners();
      return true;
    } catch (e) {
      _error = _humanize(e);
      notifyListeners();
      return false;
    }
  }

  String _humanize(Object e) {
    final msg = e.toString();
    if (msg.contains('42501')) {
      return 'Apenas o owner pode remover membros.';
    }
    if (msg.contains('22023')) {
      if (msg.contains('owner')) {
        return 'Transfira a propriedade antes de remover esse owner.';
      }
      return 'Operação inválida.';
    }
    if (msg.contains('28000')) return 'Sessão expirada. Faça login de novo.';
    return 'Não conseguimos completar a ação agora.';
  }
}

class EnvironmentMembersScreen extends StatelessWidget {
  const EnvironmentMembersScreen({super.key, this.environmentsRepository});

  final EnvironmentsRepository? environmentsRepository;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<EnvironmentMembersController>(
      create: (_) => EnvironmentMembersController(
        repository: environmentsRepository,
      )..load(),
      child: const _View(),
    );
  }
}

class _View extends StatelessWidget {
  const _View();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<EnvironmentMembersController>();
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: NinhoColors.background,
      appBar: AppBar(
        backgroundColor: NinhoColors.background,
        elevation: 0,
        leading: IconButton(
          key: const Key('members_back'),
          icon: const Icon(Icons.arrow_back, color: NinhoColors.onSurface),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(NinhoRoutes.environmentSettings);
            }
          },
        ),
        centerTitle: true,
        title: Text(
          'Membros',
          style: theme.textTheme.titleMedium?.copyWith(
            color: NinhoColors.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(child: _Body(controller: ctrl)),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.controller});
  final EnvironmentMembersController controller;

  Future<void> _confirmRemove(
    BuildContext context,
    EnvironmentMember member,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Remover morador?'),
        content: Text(
          '${member.displayName ?? "Morador"} deixará de ver o ninho. '
          'Tarefas em aberto desse morador ficarão sem responsável.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('member_remove_confirm'),
            style: FilledButton.styleFrom(backgroundColor: NinhoColors.error),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await controller.removeMember(member.userId);
    if (!context.mounted) return;
    if (!ok && controller.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(controller.error!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (controller.status) {
      case MembersStatus.idle:
      case MembersStatus.loading:
        return const Center(
          child: CircularProgressIndicator(color: NinhoColors.primary),
        );
      case MembersStatus.error:
        return _MembersError(
          message: controller.error ?? 'Erro desconhecido',
          onRetry: controller.load,
        );
      case MembersStatus.ready:
        return _ReadyView(
          controller: controller,
          onRemove: (m) => _confirmRemove(context, m),
        );
    }
  }
}

class _MembersError extends StatelessWidget {
  const _MembersError({required this.message, required this.onRetry});
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
              key: const Key('members_error'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: NinhoColors.error,
              ),
            ),
            const SizedBox(height: NinhoSpacing.stackMd),
            FilledButton.tonal(
              key: const Key('members_retry'),
              onPressed: onRetry,
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadyView extends StatelessWidget {
  const _ReadyView({required this.controller, required this.onRemove});
  final EnvironmentMembersController controller;
  final ValueChanged<EnvironmentMember> onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          Text(
            controller.summary?.name ?? 'Ninho',
            style: theme.textTheme.titleMedium?.copyWith(
              color: NinhoColors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: NinhoSpacing.stackMd),
          for (final m in controller.members)
            Padding(
              padding: const EdgeInsets.only(bottom: NinhoSpacing.unit),
              child: _MemberRow(
                member: m,
                isOwner: controller.isOwner,
                canRemove: controller.isOwner && !m.isOwner,
                onRemove: () => onRemove(m),
              ),
            ),
          const SizedBox(height: NinhoSpacing.stackMd),
          FilledButton.icon(
            key: const Key('members_invite'),
            onPressed: () => context.go(NinhoRoutes.invite),
            icon: const Icon(Icons.person_add_outlined),
            label: const Text('Convidar membro'),
            style: FilledButton.styleFrom(
              backgroundColor: NinhoColors.primary,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(NinhoRadii.lg),
              ),
            ),
          ),
          const SizedBox(height: NinhoSpacing.stackSm),
          Text(
            'Plano gratuito: até 2 pessoas.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: NinhoColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.isOwner,
    required this.canRemove,
    required this.onRemove,
  });

  final EnvironmentMember member;
  final bool isOwner;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = (member.displayName?.trim().isNotEmpty ?? false)
        ? member.displayName!.trim().substring(0, 1).toUpperCase()
        : '?';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: NinhoColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(NinhoRadii.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(NinhoSpacing.stackMd),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: NinhoColors.primaryFixed,
                shape: BoxShape.circle,
              ),
              child: Text(
                initial,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: NinhoColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: NinhoSpacing.stackMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.displayName?.trim().isNotEmpty == true
                        ? member.displayName!.trim()
                        : 'Morador',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: NinhoColors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    member.isOwner ? 'Owner' : 'Morador',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: NinhoColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (canRemove)
              IconButton(
                key: Key('member_more_${member.userId}'),
                icon: const Icon(
                  Icons.more_vert,
                  color: NinhoColors.onSurfaceVariant,
                ),
                onPressed: onRemove,
                tooltip: 'Remover morador',
              ),
          ],
        ),
      ),
    );
  }
}
