import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repositories/invites_repository.dart';
import '../../core/colors.dart';
import '../../core/routes.dart';
import '../../core/spacing.dart';

// Stitch — "Convite com Logo Animado" (14083929657446416935) e
// "Convite Expirado" (18283400647997996900). IDEA.md §5.3 + §7.3.
//
// Fluxo:
//   1. Token chega via deep link (/i/:token) ou QR.
//   2. initState chama previewInvite — leitura sem consumir, valida estado
//      do convite (expirado/revogado/usado/não encontrado) e devolve nome
//      do ninho + membros + cômodos + streak.
//   3. Tap em "Entrar no ninho" chama acceptInvite (consome) e redireciona
//      pra /home. "Não" devolve o usuário pra splash.
//   4. Erros viram telas dedicadas (expirado = Stitch específico; resto =
//      mensagem genérica acolhedora).
enum _ScreenState { loading, preview, expired, error, accepting }

class AcceptInviteScreen extends StatefulWidget {
  const AcceptInviteScreen({
    super.key,
    required this.token,
    this.invitesRepository,
  });

  final String token;
  final InvitesRepository? invitesRepository;

  @override
  State<AcceptInviteScreen> createState() => _AcceptInviteScreenState();
}

class _AcceptInviteScreenState extends State<AcceptInviteScreen> {
  late final InvitesRepository _repo;

  _ScreenState _state = _ScreenState.loading;
  InvitePreview? _preview;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _repo = widget.invitesRepository ?? InvitesRepository();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _state = _ScreenState.loading;
      _errorMessage = null;
    });
    try {
      final preview = await _repo.previewInvite(token: widget.token);
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _state = _ScreenState.preview;
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      // Expirado/revogado/usado vêm com errcode 22023 do RPC. 42704 =
      // não encontrado — também é "Convite Expirado" do ponto de vista UX
      // (link inválido = "esse convite não vale mais").
      final isExpiredLike =
          msg.contains('22023') ||
          msg.contains('42704') ||
          msg.contains('expirado') ||
          msg.contains('revogado') ||
          msg.contains('já utilizado') ||
          msg.contains('não encontrado');
      setState(() {
        _state = isExpiredLike ? _ScreenState.expired : _ScreenState.error;
        _errorMessage = _humanize(msg);
      });
    }
  }

  Future<void> _accept() async {
    setState(() {
      _state = _ScreenState.accepting;
      _errorMessage = null;
    });
    try {
      await _repo.acceptInvite(token: widget.token);
      if (!mounted) return;
      // Sucesso → home (já é membro, pode usar o ninho).
      context.go(NinhoRoutes.home);
    } catch (e) {
      if (!mounted) return;
      // Se o convite virou expirado/usado entre o preview e o accept,
      // cai no estado expirado pra UX consistente.
      final msg = e.toString();
      final isExpiredLike =
          msg.contains('22023') ||
          msg.contains('42704') ||
          msg.contains('expirado') ||
          msg.contains('revogado') ||
          msg.contains('já utilizado');
      setState(() {
        _state = isExpiredLike ? _ScreenState.expired : _ScreenState.preview;
        _errorMessage = isExpiredLike ? null : _humanize(msg);
      });
    }
  }

  void _decline() {
    // "Não" / "Voltar": leva pra splash que reavalia sessão. Mantém o
    // usuário longe do ninho até ele clicar no link de novo.
    context.go(NinhoRoutes.splash);
  }

  String _humanize(String msg) {
    if (msg.contains('54000')) {
      return 'Muitas tentativas. Aguarde um minuto e tente de novo.';
    }
    if (msg.contains('28000') || msg.contains('Sessão')) {
      return 'Sessão expirada. Faça login de novo.';
    }
    return 'Algo deu errado. Tente outra vez em instantes.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NinhoColors.surface,
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    switch (_state) {
      case _ScreenState.loading:
        return const _LoadingBody();
      case _ScreenState.preview:
      case _ScreenState.accepting:
        return _PreviewBody(
          preview: _preview!,
          submitting: _state == _ScreenState.accepting,
          errorText: _errorMessage,
          onAccept: _accept,
          onDecline: _decline,
        );
      case _ScreenState.expired:
        return _ExpiredBody(onBack: _decline);
      case _ScreenState.error:
        return _ErrorBody(message: _errorMessage, onRetry: _load);
    }
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _PreviewBody extends StatelessWidget {
  const _PreviewBody({
    required this.preview,
    required this.submitting,
    required this.errorText,
    required this.onAccept,
    required this.onDecline,
  });

  final InvitePreview preview;
  final bool submitting;
  final String? errorText;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: NinhoSpacing.marginMobile,
      ),
      child: Column(
        children: [
          SizedBox(
            height: 56,
            child: Row(
              children: [
                IconButton(
                  key: const Key('accept_invite_back_button'),
                  icon: const Icon(Icons.arrow_back),
                  onPressed: onDecline,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                const SizedBox(height: NinhoSpacing.stackMd),
                Center(
                  child: Container(
                    width: 112,
                    height: 112,
                    decoration: const BoxDecoration(
                      color: NinhoColors.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.home_filled,
                      size: 56,
                      color: NinhoColors.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: NinhoSpacing.stackLg),
                Text(
                  'Você foi convidado pro',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: NinhoColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: NinhoSpacing.stackSm),
                Text(
                  preview.environmentName,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: NinhoColors.primary,
                  ),
                ),
                const SizedBox(height: NinhoSpacing.stackLg),
                _InfoCard(
                  icon: Icons.people_outline,
                  label: 'Moradores',
                  value: _membersLine(preview),
                ),
                const SizedBox(height: NinhoSpacing.stackSm),
                _InfoCard(
                  icon: Icons.grid_view_rounded,
                  label: 'Cômodos',
                  value: '${preview.roomCount} ${preview.roomCount == 1 ? "cômodo" : "cômodos"}',
                ),
                const SizedBox(height: NinhoSpacing.stackSm),
                _InfoCard(
                  icon: Icons.local_fire_department_outlined,
                  label: 'Streak do ninho',
                  value: '${preview.environmentStreak} ${preview.environmentStreak == 1 ? "dia" : "dias"}',
                ),
                const SizedBox(height: NinhoSpacing.stackSm),
                _InfoCard(
                  icon: Icons.schedule_outlined,
                  label: 'Ninho aberto',
                  value: _relativeTime(preview.environmentCreatedAt),
                ),
                const SizedBox(height: NinhoSpacing.stackLg),
                Text(
                  preview.alreadyMember
                      ? 'Você já mora aqui. Tap em "Entrar" só atualiza sua sessão.'
                      : 'Você vai entrar como morador. O dono do ninho pode mudar isso depois.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: NinhoColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (errorText != null) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: NinhoSpacing.stackSm),
              child: Text(
                errorText!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: NinhoColors.error,
                ),
              ),
            ),
          ],
          FilledButton(
            key: const Key('accept_invite_primary_button'),
            onPressed: submitting ? null : onAccept,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            child: submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: NinhoColors.onPrimary,
                    ),
                  )
                : const Text('Entrar no ninho'),
          ),
          const SizedBox(height: NinhoSpacing.stackSm),
          TextButton(
            key: const Key('accept_invite_decline_button'),
            onPressed: submitting ? null : onDecline,
            style: TextButton.styleFrom(
              foregroundColor: NinhoColors.onSurfaceVariant,
            ),
            child: const Text('Não, obrigada'),
          ),
          const SizedBox(height: NinhoSpacing.stackSm),
        ],
      ),
    );
  }

  String _membersLine(InvitePreview p) {
    if (p.memberNames.isEmpty) return '${p.memberCount}';
    if (p.memberNames.length == p.memberCount) {
      return p.memberNames.join(' · ');
    }
    final extra = p.memberCount - p.memberNames.length;
    return '${p.memberNames.join(' · ')} +$extra';
  }

  String _relativeTime(DateTime when) {
    final diff = DateTime.now().difference(when);
    if (diff.inDays >= 365) {
      final years = (diff.inDays / 365).floor();
      return 'há $years ${years == 1 ? "ano" : "anos"}';
    }
    if (diff.inDays >= 30) {
      final months = (diff.inDays / 30).floor();
      return 'há $months ${months == 1 ? "mês" : "meses"}';
    }
    if (diff.inDays >= 1) {
      return 'há ${diff.inDays} ${diff.inDays == 1 ? "dia" : "dias"}';
    }
    return 'há poucas horas';
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(NinhoSpacing.paddingCard),
      decoration: BoxDecoration(
        color: NinhoColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: NinhoColors.secondaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: NinhoColors.onSecondaryContainer, size: 20),
          ),
          const SizedBox(width: NinhoSpacing.gutterMobile),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: NinhoColors.onSurfaceVariant,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: NinhoColors.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpiredBody extends StatelessWidget {
  const _ExpiredBody({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: NinhoSpacing.marginMobile,
      ),
      child: Column(
        children: [
          SizedBox(
            height: 56,
            child: Row(
              children: [
                IconButton(
                  key: const Key('accept_invite_expired_back_button'),
                  icon: const Icon(Icons.arrow_back),
                  onPressed: onBack,
                ),
              ],
            ),
          ),
          const Spacer(),
          Container(
            width: 112,
            height: 112,
            decoration: const BoxDecoration(
              color: NinhoColors.surfaceContainer,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.do_not_disturb,
              size: 56,
              color: NinhoColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: NinhoSpacing.stackLg),
          Text(
            'Opa, esse convite expirou',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: NinhoColors.primary,
            ),
          ),
          const SizedBox(height: NinhoSpacing.stackSm),
          Text(
            'Esse convite não está mais valendo. Peça um novo pra quem te chamou.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: NinhoColors.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          FilledButton(
            key: const Key('accept_invite_expired_primary_button'),
            onPressed: onBack,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            child: const Text('Voltar'),
          ),
          const SizedBox(height: NinhoSpacing.stackSm),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: NinhoSpacing.marginMobile,
      ),
      child: Column(
        children: [
          const Spacer(),
          const Icon(
            Icons.cloud_off_outlined,
            size: 56,
            color: NinhoColors.onSurfaceVariant,
          ),
          const SizedBox(height: NinhoSpacing.stackMd),
          Text(
            message ?? 'Algo deu errado. Tente outra vez em instantes.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: NinhoColors.onSurface,
            ),
          ),
          const Spacer(),
          FilledButton(
            key: const Key('accept_invite_retry_button'),
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            child: const Text('Tentar de novo'),
          ),
          const SizedBox(height: NinhoSpacing.stackSm),
        ],
      ),
    );
  }
}
