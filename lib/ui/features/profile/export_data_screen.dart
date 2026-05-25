import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../data/repositories/users_repository.dart';
import '../../core/colors.dart';
import '../../core/routes.dart';
import '../../core/spacing.dart';

// Stitch — "Exportar Meus Dados - Harmonia Lar" (8c521a39).
// LGPD §5.10: gera JSON com snapshot dos dados pessoais do caller via
// RPC `export_user_data` (SECURITY DEFINER) e oferece share/download.
enum ExportStatus { idle, generating, ready, error }

typedef ShareXFn = Future<void> Function(XFile file, {required String subject});

class ExportDataController extends ChangeNotifier {
  ExportDataController({
    UsersRepository? usersRepository,
    ShareXFn? shareFn,
    DateTime Function()? now,
  }) : _usersRepo = usersRepository ?? UsersRepository(),
       _shareFn = shareFn ?? _defaultShare,
       _now = now ?? DateTime.now;

  final UsersRepository _usersRepo;
  final ShareXFn _shareFn;
  final DateTime Function() _now;

  ExportStatus _status = ExportStatus.idle;
  ExportStatus get status => _status;

  String? _error;
  String? get error => _error;

  int? _payloadBytes;
  int? get payloadBytes => _payloadBytes;

  static Future<void> _defaultShare(
    XFile file, {
    required String subject,
  }) async {
    await SharePlus.instance.share(
      ShareParams(files: [file], subject: subject),
    );
  }

  Future<void> generateAndShare() async {
    _status = ExportStatus.generating;
    _error = null;
    notifyListeners();
    try {
      final data = await _usersRepo.exportUserData();
      final json = const JsonEncoder.withIndent('  ').convert(data);
      final bytes = Uint8List.fromList(utf8.encode(json));
      _payloadBytes = bytes.length;
      final timestamp = _now().toIso8601String().split('T').first;
      final file = XFile.fromData(
        bytes,
        mimeType: 'application/json',
        name: 'ninho-export-$timestamp.json',
      );
      await _shareFn(file, subject: 'Meus dados do Ninho');
      _status = ExportStatus.ready;
    } catch (e) {
      _status = ExportStatus.error;
      _error = _humanize(e);
    } finally {
      notifyListeners();
    }
  }

  String _humanize(Object e) {
    final msg = e.toString();
    if (msg.contains('54000')) {
      return 'Você atingiu o limite de exportações de hoje. Tente amanhã.';
    }
    if (msg.contains('28000')) return 'Sessão expirada. Faça login de novo.';
    if (msg.contains('42501')) return 'Sem permissão para exportar dados.';
    return 'Não conseguimos gerar o arquivo agora. Tente outra vez.';
  }
}

class ExportDataScreen extends StatelessWidget {
  const ExportDataScreen({super.key, this.usersRepository, this.shareFn});

  final UsersRepository? usersRepository;
  final ShareXFn? shareFn;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ExportDataController>(
      create: (_) => ExportDataController(
        usersRepository: usersRepository,
        shareFn: shareFn,
      ),
      child: const _View(),
    );
  }
}

class _View extends StatelessWidget {
  const _View();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ExportDataController>();
    return Scaffold(
      backgroundColor: NinhoColors.background,
      appBar: AppBar(
        backgroundColor: NinhoColors.background,
        elevation: 0,
        leading: IconButton(
          key: const Key('export_back'),
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
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: NinhoColors.onSurface,
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
              child: _Body(controller: ctrl),
            ),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.controller});
  final ExportDataController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: NinhoSpacing.stackLg),
        Container(
          width: 96,
          height: 96,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: NinhoColors.secondaryFixed,
            borderRadius: BorderRadius.circular(NinhoRadii.xl),
          ),
          child: const Icon(
            Icons.cloud_download_outlined,
            color: NinhoColors.onSecondaryFixedVariant,
            size: 44,
          ),
        ),
        const SizedBox(height: NinhoSpacing.stackLg),
        Text(
          'Exportar meus dados',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: NinhoColors.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: NinhoSpacing.stackMd),
        Text(
          'Geramos um arquivo JSON com seu perfil, tarefas, conclusões, '
          'streaks, poeira e histórico. Você baixa ou compartilha como '
          'quiser.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: NinhoColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: NinhoSpacing.stackLg),
        const _CategoryList(),
        const SizedBox(height: NinhoSpacing.stackLg),
        if (controller.status == ExportStatus.error && controller.error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: NinhoSpacing.stackMd),
            child: Text(
              controller.error!,
              key: const Key('export_error'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: NinhoColors.error,
              ),
            ),
          ),
        if (controller.status == ExportStatus.ready) ...[
          Text(
            controller.payloadBytes != null
                ? 'Arquivo pronto (${_humanBytes(controller.payloadBytes!)}). Use o menu de compartilhamento.'
                : 'Arquivo pronto. Use o menu de compartilhamento.',
            key: const Key('export_success'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: NinhoColors.secondary,
            ),
          ),
          const SizedBox(height: NinhoSpacing.stackMd),
        ],
        FilledButton.icon(
          key: const Key('export_generate_button'),
          onPressed: controller.status == ExportStatus.generating
              ? null
              : controller.generateAndShare,
          icon: controller.status == ExportStatus.generating
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.ios_share),
          label: Text(
            controller.status == ExportStatus.ready
                ? 'Gerar novamente'
                : 'Gerar arquivo',
          ),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(NinhoRadii.lg),
            ),
          ),
        ),
        const SizedBox(height: NinhoSpacing.stackMd),
        Text(
          'Você pode pedir um novo arquivo até 5 vezes por dia.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: NinhoColors.outline,
          ),
        ),
      ],
    );
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList();

  static const _items = <(IconData, String)>[
    (Icons.person_outline, 'Perfil'),
    (Icons.checklist, 'Tarefas'),
    (Icons.check_circle_outline, 'Conclusões'),
    (Icons.local_fire_department_outlined, 'Streaks'),
    (Icons.auto_awesome, 'Poeira'),
    (Icons.swap_horiz, 'Transferências'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: NinhoColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(NinhoRadii.xl),
        border: Border.all(color: NinhoColors.surfaceContainerHigh),
      ),
      child: Column(
        children: [
          for (var i = 0; i < _items.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: NinhoSpacing.paddingCard,
                vertical: 12,
              ),
              child: Row(
                children: [
                  Icon(_items[i].$1, color: NinhoColors.primary, size: 22),
                  const SizedBox(width: NinhoSpacing.stackMd),
                  Expanded(
                    child: Text(
                      _items[i].$2,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: NinhoColors.onSurface,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.check_circle,
                    color: NinhoColors.secondary,
                    size: 20,
                  ),
                ],
              ),
            ),
            if (i < _items.length - 1)
              const Divider(
                height: 1,
                color: NinhoColors.surfaceContainerHigh,
                indent: 16,
                endIndent: 16,
              ),
          ],
        ],
      ),
    );
  }
}

String _humanBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
}
