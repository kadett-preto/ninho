import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/environments_repository.dart';
import '../../../data/services/supabase_client.dart';
import '../../core/colors.dart';
import '../../core/routes.dart';
import '../../core/spacing.dart';

// Stitch — "Transferir Propriedade - Harmonia Lar" (f10b6a24).
// Fase 11.6 / IDEA.md §5.5: owner escolhe um membro ativo do ninho
// para receber a propriedade; RPC `transfer_ownership` é atômico e só
// dispara depois do checkbox de entendimento + tap explícito.
enum TransferStatus { idle, loading, ready, submitting, done, error }

class TransferOwnershipController extends ChangeNotifier {
  TransferOwnershipController({
    EnvironmentsRepository? environmentsRepository,
    String? currentUserId,
  }) : _envRepo = environmentsRepository ?? EnvironmentsRepository(),
       _currentUserIdOverride = currentUserId;

  final EnvironmentsRepository _envRepo;
  final String? _currentUserIdOverride;

  String? _envId;

  TransferStatus _status = TransferStatus.idle;
  TransferStatus get status => _status;

  String? _error;
  String? get error => _error;

  String? _currentUserId;
  String? get currentUserId => _currentUserId;

  List<EnvironmentMember> _candidates = const [];
  List<EnvironmentMember> get candidates => _candidates;

  EnvironmentMember? _selected;
  EnvironmentMember? get selected => _selected;

  bool _acknowledged = false;
  bool get acknowledged => _acknowledged;

  bool get canSubmit =>
      _selected != null &&
      _acknowledged &&
      _status != TransferStatus.submitting;

  Future<void> load() async {
    _status = TransferStatus.loading;
    _error = null;
    notifyListeners();
    try {
      if (_currentUserIdOverride != null) {
        _currentUserId = _currentUserIdOverride;
      } else {
        _currentUserId = SupabaseService.client.auth.currentUser?.id;
      }
      _envId = await _envRepo.fetchCurrentEnvironmentId();
      if (_envId == null) {
        _status = TransferStatus.error;
        _error = 'Você ainda não tem ninho.';
        notifyListeners();
        return;
      }
      final all = await _envRepo.listMembers(_envId!);
      // Owner não pode transferir pra si mesmo.
      _candidates = [
        for (final m in all)
          if (m.userId != _currentUserId) m,
      ];
      _status = TransferStatus.ready;
    } catch (e) {
      _status = TransferStatus.error;
      _error = _humanize(e);
    } finally {
      notifyListeners();
    }
  }

  void select(EnvironmentMember member) {
    _selected = member;
    notifyListeners();
  }

  void setAcknowledged(bool value) {
    _acknowledged = value;
    notifyListeners();
  }

  Future<bool> submit() async {
    final envId = _envId;
    final target = _selected;
    if (envId == null || target == null || !_acknowledged) return false;
    _status = TransferStatus.submitting;
    _error = null;
    notifyListeners();
    try {
      await _envRepo.transferOwnership(
        environmentId: envId,
        newOwnerId: target.userId,
      );
      _status = TransferStatus.done;
      notifyListeners();
      return true;
    } catch (e) {
      _status = TransferStatus.error;
      _error = _humanize(e);
      notifyListeners();
      return false;
    }
  }

  String _humanize(Object e) {
    final msg = e.toString();
    if (msg.contains('42501')) {
      return 'Sem permissão. Apenas o owner pode transferir o ninho.';
    }
    if (msg.contains('22023')) {
      return 'Escolha um membro ativo diferente de você.';
    }
    if (msg.contains('28000')) return 'Sessão expirada. Faça login de novo.';
    return 'Não conseguimos transferir agora. Tente outra vez.';
  }
}

class TransferOwnershipScreen extends StatelessWidget {
  const TransferOwnershipScreen({
    super.key,
    this.environmentsRepository,
    this.currentUserId,
  });

  final EnvironmentsRepository? environmentsRepository;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<TransferOwnershipController>(
      create: (_) => TransferOwnershipController(
        environmentsRepository: environmentsRepository,
        currentUserId: currentUserId,
      )..load(),
      child: const _View(),
    );
  }
}

class _View extends StatelessWidget {
  const _View();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<TransferOwnershipController>();
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: NinhoColors.background,
      appBar: AppBar(
        backgroundColor: NinhoColors.background,
        elevation: 0,
        leading: IconButton(
          key: const Key('transfer_back'),
          icon: const Icon(Icons.arrow_back, color: NinhoColors.onSurface),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(NinhoRoutes.profile);
            }
          },
        ),
        centerTitle: true,
        title: Text(
          'Ambientes',
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

class _Body extends StatefulWidget {
  const _Body({required this.controller});
  final TransferOwnershipController controller;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  Future<void> _submit() async {
    final ok = await widget.controller.submit();
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Propriedade transferida com sucesso.')),
      );
      context.go(NinhoRoutes.profile);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    switch (ctrl.status) {
      case TransferStatus.idle:
      case TransferStatus.loading:
        return const Center(
          child: CircularProgressIndicator(color: NinhoColors.primary),
        );
      case TransferStatus.error:
        if (ctrl.candidates.isEmpty) {
          return _ErrorEmpty(
            message: ctrl.error ?? 'Erro desconhecido',
            onRetry: ctrl.load,
          );
        }
        return _ReadyBody(controller: ctrl, onSubmit: _submit);
      case TransferStatus.ready:
      case TransferStatus.submitting:
      case TransferStatus.done:
        return _ReadyBody(controller: ctrl, onSubmit: _submit);
    }
  }
}

class _ErrorEmpty extends StatelessWidget {
  const _ErrorEmpty({required this.message, required this.onRetry});
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
              key: const Key('transfer_error'),
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: NinhoColors.error),
            ),
            const SizedBox(height: NinhoSpacing.stackMd),
            FilledButton.tonal(
              key: const Key('transfer_retry'),
              onPressed: onRetry,
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadyBody extends StatelessWidget {
  const _ReadyBody({required this.controller, required this.onSubmit});
  final TransferOwnershipController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final submitting = controller.status == TransferStatus.submitting;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  NinhoSpacing.marginMobile,
                  NinhoSpacing.stackLg,
                  NinhoSpacing.marginMobile,
                  NinhoSpacing.stackMd,
                ),
                children: [
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: NinhoColors.primaryFixed,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.key,
                        color: NinhoColors.primary,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(height: NinhoSpacing.stackMd),
                  Text(
                    'Transferir o controle do ambiente',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: NinhoColors.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: NinhoSpacing.stackSm),
                  Text(
                    'O novo owner poderá gerenciar cômodos, membros e '
                    'configurações.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: NinhoColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: NinhoSpacing.stackLg),
                  if (controller.candidates.isEmpty)
                    Text(
                      'Você é o único morador ativo. Convide alguém '
                      'antes de transferir.',
                      key: const Key('transfer_empty'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: NinhoColors.onSurfaceVariant,
                      ),
                    )
                  else
                    Column(
                      children: [
                        for (final m in controller.candidates)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: NinhoSpacing.unit / 2,
                            ),
                            child: _MemberTile(
                              member: m,
                              selected: controller.selected?.userId == m.userId,
                              onTap: submitting
                                  ? null
                                  : () => controller.select(m),
                            ),
                          ),
                      ],
                    ),
                  const SizedBox(height: NinhoSpacing.stackLg),
                  Row(
                    children: [
                      Checkbox(
                        key: const Key('transfer_ack_checkbox'),
                        value: controller.acknowledged,
                        onChanged: submitting
                            ? null
                            : (v) => controller.setAcknowledged(v ?? false),
                        activeColor: NinhoColors.primary,
                      ),
                      Expanded(
                        child: Text(
                          'Entendo que deixarei de ser owner.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: NinhoColors.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (controller.error != null) ...[
                    const SizedBox(height: NinhoSpacing.stackSm),
                    Text(
                      controller.error!,
                      key: const Key('transfer_error_text'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: NinhoColors.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                NinhoSpacing.marginMobile,
                0,
                NinhoSpacing.marginMobile,
                NinhoSpacing.stackLg,
              ),
              child: Column(
                children: [
                  FilledButton(
                    key: const Key('transfer_submit'),
                    onPressed: controller.canSubmit ? onSubmit : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: NinhoColors.primary,
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(NinhoRadii.lg),
                      ),
                    ),
                    child: submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: NinhoColors.onPrimary,
                            ),
                          )
                        : const Text(
                            'Transferir ownership',
                            style: TextStyle(
                              color: NinhoColors.onPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                  const SizedBox(height: NinhoSpacing.stackSm),
                  Builder(
                    builder: (ctx) => TextButton(
                      key: const Key('transfer_cancel'),
                      onPressed: submitting
                          ? null
                          : () {
                              if (ctx.canPop()) {
                                ctx.pop();
                              } else {
                                ctx.go(NinhoRoutes.profile);
                              }
                            },
                      style: TextButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        foregroundColor: NinhoColors.primary,
                      ),
                      child: const Text('Cancelar'),
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

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.selected,
    required this.onTap,
  });
  final EnvironmentMember member;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = (member.displayName?.trim().isNotEmpty ?? false)
        ? member.displayName!.trim().substring(0, 1).toUpperCase()
        : '?';
    return Material(
      color: selected
          ? NinhoColors.primaryContainer
          : NinhoColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(NinhoRadii.lg),
      child: InkWell(
        key: Key('transfer_member_${member.userId}'),
        borderRadius: BorderRadius.circular(NinhoRadii.lg),
        onTap: onTap,
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
                      member.isOwner ? 'Owner atual' : 'Morador',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: NinhoColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? NinhoColors.primary : NinhoColors.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
