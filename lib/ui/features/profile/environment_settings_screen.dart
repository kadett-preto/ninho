import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/environments_repository.dart';
import '../../../data/repositories/shop_repository.dart';
import '../../core/colors.dart';
import '../../core/routes.dart';
import '../../core/spacing.dart';

// Stitch — "Configurações do Ambiente - Harmonia Lar" (00cead6f).
// Fase 11.8 / IDEA.md §5.2 + §5.5: hub de configurações do ninho.
//
// Coverage mínimo viável:
//   * Nome (edit dialog, RPC update_environment_name)
//   * Timezone (read-only por ora — IDEA §12 cobre i18n/IANA picker)
//   * Toggle Transferência de Tarefa (set_transfer_item_enabled)
//   * Toggle Modo Viagem (start_vacation / end_vacation)
//   * Links: Notificações, Transferir Propriedade, Membros, Cômodos
//   * Arquivar ambiente: redireciona para tela de Sair (owner solo arquiva).
enum EnvSettingsStatus { idle, loading, ready, error }

class EnvironmentSettingsController extends ChangeNotifier {
  EnvironmentSettingsController({
    EnvironmentsRepository? environmentsRepository,
    ShopRepository? shopRepository,
  })  : _envRepo = environmentsRepository ?? EnvironmentsRepository(),
        _shopRepo = shopRepository ?? const ShopRepository();

  final EnvironmentsRepository _envRepo;
  final ShopRepository _shopRepo;

  EnvSettingsStatus _status = EnvSettingsStatus.idle;
  EnvSettingsStatus get status => _status;

  String? _error;
  String? get error => _error;

  String? _envId;
  String? get environmentId => _envId;

  EnvironmentSummary? _summary;
  EnvironmentSummary? get summary => _summary;

  EnvironmentFlags _flags = const EnvironmentFlags(
    transferItemEnabled: true,
    vacationMode: false,
  );
  EnvironmentFlags get flags => _flags;

  int _roomCount = 0;
  int get roomCount => _roomCount;

  int _memberCount = 0;
  int get memberCount => _memberCount;

  bool get isOwner => _summary?.isOwner == true;

  String? _pendingAction;
  String? get pendingAction => _pendingAction;

  Future<void> load() async {
    _status = EnvSettingsStatus.loading;
    _error = null;
    notifyListeners();
    try {
      _envId = await _envRepo.fetchCurrentEnvironmentId();
      if (_envId == null) {
        _status = EnvSettingsStatus.error;
        _error = 'Você ainda não tem ninho.';
        notifyListeners();
        return;
      }
      final results = await Future.wait<Object?>([
        _envRepo.fetchEnvironmentSummary(environmentId: _envId!),
        _envRepo.fetchFlags(_envId!),
        _envRepo.fetchRooms(_envId!),
        _envRepo.listMembers(_envId!),
      ]);
      _summary = results[0] as EnvironmentSummary?;
      _flags = results[1] as EnvironmentFlags;
      _roomCount = (results[2] as List).length;
      _memberCount = (results[3] as List).length;
      _status = EnvSettingsStatus.ready;
    } catch (e) {
      _status = EnvSettingsStatus.error;
      _error = _humanize(e);
    } finally {
      notifyListeners();
    }
  }

  Future<bool> renameEnvironment(String newName) async {
    final id = _envId;
    if (id == null) return false;
    _pendingAction = 'rename';
    _error = null;
    notifyListeners();
    try {
      await _envRepo.updateName(environmentId: id, name: newName);
      if (_summary != null) {
        _summary = EnvironmentSummary(
          id: _summary!.id,
          name: newName.trim(),
          ownerId: _summary!.ownerId,
          role: _summary!.role,
          createdAt: _summary!.createdAt,
        );
      }
      return true;
    } catch (e) {
      _error = _humanize(e);
      return false;
    } finally {
      _pendingAction = null;
      notifyListeners();
    }
  }

  Future<bool> setTransferItemEnabled(bool enabled) async {
    final id = _envId;
    if (id == null) return false;
    _pendingAction = 'transfer_item';
    _error = null;
    notifyListeners();
    try {
      final v = await _shopRepo.setTransferItemEnabled(
        environmentId: id,
        enabled: enabled,
      );
      _flags = EnvironmentFlags(
        transferItemEnabled: v,
        vacationMode: _flags.vacationMode,
      );
      return true;
    } catch (e) {
      _error = _humanize(e);
      return false;
    } finally {
      _pendingAction = null;
      notifyListeners();
    }
  }

  Future<bool> setVacationMode(bool enabled) async {
    final id = _envId;
    if (id == null) return false;
    _pendingAction = 'vacation';
    _error = null;
    notifyListeners();
    try {
      if (enabled) {
        await _envRepo.startVacation(id);
      } else {
        await _envRepo.endVacation(id);
      }
      _flags = EnvironmentFlags(
        transferItemEnabled: _flags.transferItemEnabled,
        vacationMode: enabled,
      );
      return true;
    } catch (e) {
      _error = _humanize(e);
      return false;
    } finally {
      _pendingAction = null;
      notifyListeners();
    }
  }

  String _humanize(Object e) {
    final msg = e.toString();
    if (msg.contains('42501')) return 'Apenas o owner pode mudar isso.';
    if (msg.contains('22023')) {
      if (msg.contains('viagem')) return 'Modo viagem já está como está.';
      if (msg.contains('14')) return 'Limite anual de 14 dias de viagem atingido.';
      return 'Operação inválida.';
    }
    if (msg.contains('28000')) return 'Sessão expirada. Faça login de novo.';
    return 'Não conseguimos aplicar agora. Tente outra vez.';
  }
}

class EnvironmentSettingsScreen extends StatelessWidget {
  const EnvironmentSettingsScreen({
    super.key,
    this.environmentsRepository,
    this.shopRepository,
  });

  final EnvironmentsRepository? environmentsRepository;
  final ShopRepository? shopRepository;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<EnvironmentSettingsController>(
      create: (_) => EnvironmentSettingsController(
        environmentsRepository: environmentsRepository,
        shopRepository: shopRepository,
      )..load(),
      child: const _View(),
    );
  }
}

class _View extends StatelessWidget {
  const _View();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<EnvironmentSettingsController>();
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: NinhoColors.background,
      appBar: AppBar(
        backgroundColor: NinhoColors.background,
        elevation: 0,
        leading: IconButton(
          key: const Key('env_settings_back'),
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
          'Ambiente',
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
  final EnvironmentSettingsController controller;

  @override
  Widget build(BuildContext context) {
    switch (controller.status) {
      case EnvSettingsStatus.idle:
      case EnvSettingsStatus.loading:
        return const Center(
          child: CircularProgressIndicator(color: NinhoColors.primary),
        );
      case EnvSettingsStatus.error:
        return _ErrorView(
          message: controller.error ?? 'Erro desconhecido',
          onRetry: controller.load,
        );
      case EnvSettingsStatus.ready:
        return _ReadyView(controller: controller);
    }
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
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
              key: const Key('env_settings_error'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: NinhoColors.error,
              ),
            ),
            const SizedBox(height: NinhoSpacing.stackMd),
            FilledButton.tonal(
              key: const Key('env_settings_retry'),
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
  const _ReadyView({required this.controller});
  final EnvironmentSettingsController controller;

  Future<void> _promptRename(BuildContext context) async {
    final initial = controller.summary?.name ?? '';
    final input = TextEditingController(text: initial);
    final result = await showDialog<String?>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Renomear ninho'),
        content: TextField(
          key: const Key('env_rename_input'),
          controller: input,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Nome do ninho',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(null),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('env_rename_save'),
            onPressed: () => Navigator.of(dialogCtx).pop(input.text),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (result == null || result.trim().isEmpty) return;
    final ok = await controller.renameEnvironment(result);
    if (!context.mounted) return;
    if (!ok && controller.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(controller.error!)),
      );
    }
  }

  void _snackError(BuildContext context, String? msg) {
    if (msg == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOwner = controller.isOwner;
    final summary = controller.summary;
    final flags = controller.flags;
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
          _SectionLabel('Geral'),
          _Row(
            keyValue: 'env_row_name',
            icon: Icons.home_outlined,
            title: 'Nome do ambiente',
            subtitle: summary?.name ?? '-',
            trailing: isOwner ? const Icon(Icons.edit, size: 18) : null,
            onTap: isOwner ? () => _promptRename(context) : null,
          ),
          _Row(
            keyValue: 'env_row_timezone',
            icon: Icons.schedule_outlined,
            title: 'Fuso horário',
            subtitle: 'América/São Paulo (GMT-3)',
            comingSoon: true,
          ),
          const SizedBox(height: NinhoSpacing.stackMd),
          _SectionLabel('Tarefas e tempo'),
          _Toggle(
            keyValue: 'env_toggle_transfer',
            icon: Icons.swap_horiz_outlined,
            title: 'Transferência de Tarefa',
            subtitle: 'Permitir trocar responsabilidades.',
            value: flags.transferItemEnabled,
            enabled: isOwner &&
                controller.pendingAction != 'transfer_item',
            onChanged: (v) async {
              final ok = await controller.setTransferItemEnabled(v);
              if (!context.mounted) return;
              if (!ok) _snackError(context, controller.error);
            },
          ),
          _Toggle(
            keyValue: 'env_toggle_vacation',
            icon: Icons.flight_takeoff_outlined,
            title: 'Modo Viagem',
            subtitle: 'Pausa tarefas (até 14 dias/ano).',
            value: flags.vacationMode,
            enabled: isOwner && controller.pendingAction != 'vacation',
            onChanged: (v) async {
              final ok = await controller.setVacationMode(v);
              if (!context.mounted) return;
              if (!ok) _snackError(context, controller.error);
            },
          ),
          const SizedBox(height: NinhoSpacing.stackMd),
          _SectionLabel('Notificações'),
          _Row(
            keyValue: 'env_row_notifications',
            icon: Icons.notifications_outlined,
            title: 'Horários e tipos',
            subtitle: 'Manhã, Tarde, Noite',
            onTap: () => context.go(NinhoRoutes.notificationSettings),
          ),
          const SizedBox(height: NinhoSpacing.stackMd),
          _SectionLabel('Estrutura'),
          _Row(
            keyValue: 'env_row_members',
            icon: Icons.group_outlined,
            title: 'Membros',
            subtitle: '${controller.memberCount} moradores',
            onTap: () => context.go(NinhoRoutes.environmentMembers),
          ),
          _Row(
            keyValue: 'env_row_rooms',
            icon: Icons.dashboard_outlined,
            title: 'Cômodos',
            subtitle: 'Gerenciar ${controller.roomCount} cômodos',
            onTap: () => context.go(NinhoRoutes.environmentRooms),
          ),
          if (isOwner) ...[
            const SizedBox(height: NinhoSpacing.stackMd),
            _SectionLabel('Propriedade'),
            _Row(
              keyValue: 'env_row_transfer_owner',
              icon: Icons.key_outlined,
              title: 'Transferir Propriedade',
              subtitle: 'Passar a gestão para outro membro.',
              onTap: () => context.go(NinhoRoutes.profileTransferOwnership),
            ),
          ],
          const SizedBox(height: NinhoSpacing.stackLg),
          TextButton.icon(
            key: const Key('env_archive_button'),
            onPressed: () => context.go(NinhoRoutes.profile),
            icon: const Icon(Icons.archive_outlined, color: NinhoColors.error),
            label: Text(
              'Arquivar ambiente',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: NinhoColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: NinhoSpacing.stackMd,
        bottom: NinhoSpacing.stackSm,
        left: 4,
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: NinhoColors.onSurfaceVariant,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.keyValue,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.comingSoon = false,
  });

  final String keyValue;
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: NinhoSpacing.unit),
      child: Material(
        color: NinhoColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(NinhoRadii.lg),
        child: InkWell(
          key: Key(keyValue),
          borderRadius: BorderRadius.circular(NinhoRadii.lg),
          onTap: comingSoon
              ? () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Em breve.')),
                )
              : onTap,
          child: Padding(
            padding: const EdgeInsets.all(NinhoSpacing.stackMd),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: NinhoColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(NinhoRadii.lg),
                  ),
                  child: Icon(
                    icon,
                    color: NinhoColors.onSurfaceVariant,
                    size: 22,
                  ),
                ),
                const SizedBox(width: NinhoSpacing.stackMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: NinhoColors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: NinhoColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                ?trailing,
                if (trailing == null)
                  const Icon(Icons.chevron_right, color: NinhoColors.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.keyValue,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String keyValue;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: NinhoSpacing.unit),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: NinhoColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(NinhoRadii.lg),
        ),
        child: Padding(
          padding: const EdgeInsets.all(NinhoSpacing.stackMd),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: NinhoColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(NinhoRadii.lg),
                ),
                child: Icon(
                  icon,
                  color: NinhoColors.onSurfaceVariant,
                  size: 22,
                ),
              ),
              const SizedBox(width: NinhoSpacing.stackMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: NinhoColors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: NinhoColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                key: Key(keyValue),
                value: value,
                onChanged: enabled ? onChanged : null,
                activeThumbColor: NinhoColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
