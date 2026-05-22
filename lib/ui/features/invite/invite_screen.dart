import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../data/repositories/environments_repository.dart';
import '../../../data/repositories/invites_repository.dart';
import '../../core/colors.dart';
import '../../core/routes.dart';
import '../../core/spacing.dart';

// Stitch — "Convidar Parceiro" (a36ab0c9bb9849c8aad916f159c32536).
// IDEA.md §5.3 (convite QR/link) + §7.3 (segurança).
//
// Fluxo: tela carrega → busca environment_id atual → chama Edge Function
// create-invite → exibe QR + link copiável + share. Token claro existe só na
// memória da tela; ao sair, app só vê o hash via banco.
//
// `fromSetup=true` muda copy do CTA principal ("Concluir configuração") e
// adiciona "Pular por agora" como no Stitch — usado ao final do wizard de
// cadastro. Sem isso, CTA é "Pronto" e nav vai pra /home direto.
class InviteScreen extends StatefulWidget {
  const InviteScreen({
    super.key,
    this.fromSetup = false,
    this.environmentsRepository,
    this.invitesRepository,
    this.inviteBaseUrl = 'https://ninho.app',
  });

  final bool fromSetup;
  final EnvironmentsRepository? environmentsRepository;
  final InvitesRepository? invitesRepository;
  final String inviteBaseUrl;

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  late final EnvironmentsRepository _envRepo;
  late final InvitesRepository _invitesRepo;

  bool _loading = true;
  String? _error;
  Invite? _invite;

  @override
  void initState() {
    super.initState();
    _envRepo = widget.environmentsRepository ?? EnvironmentsRepository();
    _invitesRepo = widget.invitesRepository ?? InvitesRepository();
    _generate();
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final envId = await _envRepo.fetchCurrentEnvironmentId();
      if (envId == null) {
        throw StateError('Você precisa cadastrar um ninho primeiro.');
      }
      final invite = await _invitesRepo.createInvite(environmentId: envId);
      if (!mounted) return;
      setState(() {
        _invite = invite;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Não conseguimos gerar o convite agora. Tente outra vez.';
        _loading = false;
      });
    }
  }

  Future<void> _copy() async {
    final link = _invite?.linkFor(widget.inviteBaseUrl);
    if (link == null) return;
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copiado.')),
    );
  }

  Future<void> _share() async {
    final link = _invite?.linkFor(widget.inviteBaseUrl);
    if (link == null) return;
    await SharePlus.instance.share(
      ShareParams(
        text: 'Vem cuidar do ninho comigo! $link',
        subject: 'Convite para o nosso ninho',
      ),
    );
  }

  void _finish() {
    context.go(NinhoRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final link = _invite?.linkFor(widget.inviteBaseUrl);

    return Scaffold(
      backgroundColor: NinhoColors.background,
      appBar: widget.fromSetup
          ? null
          : AppBar(
              backgroundColor: NinhoColors.background,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go(NinhoRoutes.home),
              ),
            ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(NinhoSpacing.marginMobile),
              child: Column(
                children: [
                  Text(
                    'Convide quem mora com você',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: NinhoColors.primary,
                    ),
                  ),
                  const SizedBox(height: NinhoSpacing.stackSm),
                  Text(
                    'No plano gratuito o ninho é pra 2 pessoas.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: NinhoColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: NinhoSpacing.stackLg),
                  _QrCard(link: link, loading: _loading, error: _error),
                  if (link != null) ...[
                    const SizedBox(height: NinhoSpacing.stackLg),
                    _LinkRow(link: link, onCopy: _copy),
                    const SizedBox(height: NinhoSpacing.stackLg),
                    _ShareButtons(onShare: _share),
                  ],
                  const SizedBox(height: NinhoSpacing.stackLg),
                  if (widget.fromSetup) ...[
                    TextButton(
                      key: const Key('invite_skip_button'),
                      onPressed: _finish,
                      style: TextButton.styleFrom(
                        foregroundColor: NinhoColors.onSurfaceVariant,
                      ),
                      child: const Text('Pular por agora'),
                    ),
                    const SizedBox(height: NinhoSpacing.stackSm),
                  ],
                  FilledButton(
                    key: const Key('invite_primary_button'),
                    onPressed: _loading ? null : _finish,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                    ),
                    child: Text(
                      widget.fromSetup ? 'Concluir configuração' : 'Pronto',
                    ),
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

class _QrCard extends StatelessWidget {
  const _QrCard({required this.link, required this.loading, required this.error});

  final String? link;
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 320,
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
      child: Column(
        children: [
          SizedBox(
            width: 192,
            height: 192,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: NinhoColors.surfaceContainerHigh,
                alignment: Alignment.center,
                child: _qrContent(theme),
              ),
            ),
          ),
          const SizedBox(height: NinhoSpacing.stackMd),
          Text(
            'ESCANEIE PARA ENTRAR',
            style: theme.textTheme.labelSmall?.copyWith(
              color: NinhoColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _qrContent(ThemeData theme) {
    if (loading) {
      return const CircularProgressIndicator(color: NinhoColors.primary);
    }
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(NinhoSpacing.gutterMobile),
        child: Text(
          error!,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(color: NinhoColors.error),
        ),
      );
    }
    if (link == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.all(8),
      child: QrImageView(
        key: const Key('invite_qr'),
        data: link!,
        version: QrVersions.auto,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: NinhoColors.primary,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: NinhoColors.onSurface,
        ),
        backgroundColor: NinhoColors.surfaceContainerHigh,
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.link, required this.onCopy});

  final String link;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: NinhoColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              link,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: NinhoColors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: NinhoSpacing.stackSm),
          FilledButton.icon(
            key: const Key('invite_copy_button'),
            onPressed: onCopy,
            icon: const Icon(Icons.content_copy, size: 18),
            label: const Text('Copiar'),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareButtons extends StatelessWidget {
  const _ShareButtons({required this.onShare});

  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _shareBtn(Icons.chat_bubble, 'WhatsApp', onShare),
        const SizedBox(width: NinhoSpacing.stackMd),
        _shareBtn(Icons.forum, 'Mensagens', onShare),
        const SizedBox(width: NinhoSpacing.stackMd),
        _shareBtn(Icons.share, 'Mais opções', onShare, keyName: 'invite_share_button'),
      ],
    );
  }

  Widget _shareBtn(IconData icon, String label, VoidCallback onTap,
      {String? keyName}) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        key: keyName != null ? Key(keyName) : null,
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: NinhoColors.surfaceContainerHigh,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x14944931),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: NinhoColors.primary),
        ),
      ),
    );
  }
}
