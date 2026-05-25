import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/users_repository.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/posthog_service.dart';
import '../../core/colors.dart';
import '../../core/routes.dart';
import '../../core/spacing.dart';

// Stitch — "Excluir Conta - Harmonia Lar" (c56e7ed4).
// LGPD §5.10 + §5.5: soft-delete da conta com tratamento de owner sem
// transferir (auto-promoção do membro mais antigo).
enum DeleteStatus { idle, loadingPreview, ready, deleting, error, done }

class DeleteAccountController extends ChangeNotifier {
  DeleteAccountController({
    UsersRepository? usersRepository,
    Future<void> Function()? signOutFn,
  }) : _usersRepo = usersRepository ?? UsersRepository(),
       _signOutFn = signOutFn ?? AuthService.signOut;

  final UsersRepository _usersRepo;
  final Future<void> Function() _signOutFn;

  DeleteStatus _status = DeleteStatus.idle;
  DeleteStatus get status => _status;

  String? _error;
  String? get error => _error;

  List<OwnedEnvironment> _ownedEnvs = const [];
  List<OwnedEnvironment> get ownedEnvs => _ownedEnvs;

  AccountDeletionResult? _result;
  AccountDeletionResult? get result => _result;

  Future<void> loadPreview() async {
    _status = DeleteStatus.loadingPreview;
    _error = null;
    notifyListeners();
    try {
      _ownedEnvs = await _usersRepo.listOwnedEnvironments();
      _status = DeleteStatus.ready;
    } catch (e) {
      _status = DeleteStatus.error;
      _error = _humanize(e);
    } finally {
      notifyListeners();
    }
  }

  Future<bool> confirmDelete() async {
    _status = DeleteStatus.deleting;
    _error = null;
    notifyListeners();
    try {
      _result = await _usersRepo.requestAccountDeletion();
      // PostHog opt-out + Supabase sign-out — sessão derruba e splash
      // reage. Falhas silenciosas (já saiu, etc.) não bloqueiam o fluxo.
      try {
        await PosthogService.optOutAndReset();
      } catch (_) {}
      try {
        await _signOutFn();
      } catch (_) {}
      _status = DeleteStatus.done;
      notifyListeners();
      return true;
    } catch (e) {
      _status = DeleteStatus.error;
      _error = _humanize(e);
      notifyListeners();
      return false;
    }
  }

  String _humanize(Object e) {
    final msg = e.toString();
    if (msg.contains('28000')) return 'Sessão expirada. Faça login de novo.';
    if (msg.contains('42501')) return 'Sem permissão para excluir a conta.';
    return 'Não conseguimos processar a exclusão agora. Tente outra vez.';
  }
}

class DeleteAccountScreen extends StatelessWidget {
  const DeleteAccountScreen({super.key, this.usersRepository, this.signOutFn});

  final UsersRepository? usersRepository;
  final Future<void> Function()? signOutFn;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<DeleteAccountController>(
      create: (_) => DeleteAccountController(
        usersRepository: usersRepository,
        signOutFn: signOutFn,
      )..loadPreview(),
      child: const _View(),
    );
  }
}

class _View extends StatefulWidget {
  const _View();

  @override
  State<_View> createState() => _ViewState();
}

class _ViewState extends State<_View> {
  late final TextEditingController _input;
  static const _expected = 'EXCLUIR';

  @override
  void initState() {
    super.initState();
    _input = TextEditingController();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  bool get _matches => _input.text.trim().toUpperCase() == _expected;

  Future<void> _confirm(DeleteAccountController ctrl) async {
    if (!_matches) return;
    final ok = await ctrl.confirmDelete();
    if (!mounted) return;
    if (ok) {
      // Sessão derrubada — splash reavalia e leva pra /login.
      context.go(NinhoRoutes.splash);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<DeleteAccountController>();
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: NinhoColors.background,
      appBar: AppBar(
        backgroundColor: NinhoColors.background,
        elevation: 0,
        leading: IconButton(
          key: const Key('delete_back'),
          icon: const Icon(Icons.arrow_back, color: NinhoColors.primary),
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
          'ninho',
          style: theme.textTheme.titleMedium?.copyWith(
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(NinhoSpacing.marginMobile),
              child: _Body(
                controller: ctrl,
                input: _input,
                matches: _matches,
                onChanged: () => setState(() {}),
                onConfirm: () => _confirm(ctrl),
                onCancel: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(NinhoRoutes.profile);
                  }
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.controller,
    required this.input,
    required this.matches,
    required this.onChanged,
    required this.onConfirm,
    required this.onCancel,
  });

  final DeleteAccountController controller;
  final TextEditingController input;
  final bool matches;
  final VoidCallback onChanged;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDeleting = controller.status == DeleteStatus.deleting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: NinhoSpacing.stackLg),
        Text(
          'Excluir sua conta',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: NinhoColors.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: NinhoSpacing.stackMd),
        Text(
          'Seus dados entram em processo de exclusão e são apagados de '
          'vez em até 30 dias. Você pode reativar entrando de novo nesse '
          'período.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: NinhoColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: NinhoSpacing.stackLg),
        if (controller.status == DeleteStatus.loadingPreview)
          const Center(
            child: CircularProgressIndicator(color: NinhoColors.primary),
          )
        else ...[
          if (controller.ownedEnvs.isNotEmpty)
            _OwnerWarning(envs: controller.ownedEnvs),
          if (controller.ownedEnvs.isNotEmpty)
            const SizedBox(height: NinhoSpacing.stackMd),
          _ConfirmInput(
            controller: input,
            matches: matches,
            onChanged: (_) => onChanged(),
            enabled: !isDeleting,
          ),
        ],
        const SizedBox(height: NinhoSpacing.stackLg),
        if (controller.error != null) ...[
          Text(
            controller.error!,
            key: const Key('delete_error'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: NinhoColors.error,
            ),
          ),
          const SizedBox(height: NinhoSpacing.stackMd),
        ],
        FilledButton(
          key: const Key('delete_confirm_button'),
          onPressed: matches && !isDeleting ? onConfirm : null,
          style: FilledButton.styleFrom(
            backgroundColor: NinhoColors.primary,
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(NinhoRadii.lg),
            ),
          ),
          child: isDeleting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: NinhoColors.onPrimary,
                  ),
                )
              : Text(
                  'Excluir conta',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: NinhoColors.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
        const SizedBox(height: NinhoSpacing.stackSm),
        TextButton(
          key: const Key('delete_cancel_button'),
          onPressed: isDeleting ? null : onCancel,
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            foregroundColor: NinhoColors.primary,
          ),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}

class _OwnerWarning extends StatelessWidget {
  const _OwnerWarning({required this.envs});
  final List<OwnedEnvironment> envs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSolo = envs.any((e) => e.isSolo);
    final hasMembers = envs.any((e) => !e.isSolo);
    final text = StringBuffer('Você é owner de ${envs.length} ');
    text.write(envs.length == 1 ? 'ninho' : 'ninhos');
    text.write('. ');
    if (hasMembers) {
      text.write(
        'Se sair sem transferir, o membro mais antigo será promovido. ',
      );
    }
    if (hasSolo) {
      text.write('Ninhos sem outros moradores serão arquivados.');
    }
    return DecoratedBox(
      key: const Key('delete_owner_warning'),
      decoration: BoxDecoration(
        color: NinhoColors.errorContainer,
        borderRadius: BorderRadius.circular(NinhoRadii.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(NinhoSpacing.paddingCard),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.error,
              color: NinhoColors.onErrorContainer,
              size: 20,
            ),
            const SizedBox(width: NinhoSpacing.stackSm),
            Expanded(
              child: Text(
                text.toString(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: NinhoColors.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmInput extends StatelessWidget {
  const _ConfirmInput({
    required this.controller,
    required this.matches,
    required this.onChanged,
    required this.enabled,
  });

  final TextEditingController controller;
  final bool matches;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DIGITE "EXCLUIR" PARA CONFIRMAR',
          style: theme.textTheme.labelSmall?.copyWith(
            color: NinhoColors.onSurfaceVariant,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: NinhoSpacing.stackSm),
        TextField(
          key: const Key('delete_confirm_input'),
          controller: controller,
          enabled: enabled,
          onChanged: onChanged,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            hintText: 'DIGITE EXCLUIR PARA CONFIRMAR',
            filled: true,
            fillColor: NinhoColors.surfaceContainerHigh,
            suffixIcon: matches
                ? const Icon(Icons.check_circle, color: NinhoColors.secondary)
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(NinhoRadii.md),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
