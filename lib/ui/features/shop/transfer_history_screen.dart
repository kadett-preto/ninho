import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/environments_repository.dart';
import '../../../data/repositories/shop_repository.dart';
import '../../../data/services/auth_service.dart';
import '../../core/colors.dart';
import '../../core/routes.dart';
import '../../core/spacing.dart';

// Ninho — Fase 9.6: histórico de transferências de tarefa.
// IDEA.md §5.8. Repo já filtra por RLS (só ninhos onde sou membro).
enum TransferHistoryStatus { idle, loading, ready, error }

class TransferHistoryController extends ChangeNotifier {
  TransferHistoryController({
    EnvironmentsRepository? environmentsRepository,
    ShopRepository? shopRepository,
    String? currentUserId,
  }) : _envRepo = environmentsRepository ?? EnvironmentsRepository(),
       _shopRepo = shopRepository ?? const ShopRepository(),
       _explicitUserId = currentUserId;

  final EnvironmentsRepository _envRepo;
  final ShopRepository _shopRepo;
  final String? _explicitUserId;

  TransferHistoryStatus _status = TransferHistoryStatus.idle;
  TransferHistoryStatus get status => _status;

  String? _error;
  String? get error => _error;

  List<TransferHistoryEntry> _entries = const [];
  List<TransferHistoryEntry> get entries => _entries;

  String? get currentUserId => _explicitUserId ?? AuthService.currentUser?.id;

  Future<void> load() async {
    _status = TransferHistoryStatus.loading;
    _error = null;
    notifyListeners();
    try {
      final envId = await _envRepo.fetchCurrentEnvironmentId();
      if (envId == null) {
        throw StateError('Você precisa cadastrar um ninho primeiro.');
      }
      _entries = await _shopRepo.fetchTransferHistory(
        environmentId: envId,
        limit: 50,
      );
      _status = TransferHistoryStatus.ready;
    } catch (e) {
      _status = TransferHistoryStatus.error;
      _error = _humanize(e);
    } finally {
      notifyListeners();
    }
  }

  String _humanize(Object e) {
    if (e is StateError) return e.message;
    final msg = e.toString();
    if (msg.contains('42501')) return 'Sem permissão para ver o histórico.';
    return 'Não conseguimos carregar o histórico agora.';
  }
}

class TransferHistoryScreen extends StatelessWidget {
  const TransferHistoryScreen({
    super.key,
    this.environmentsRepository,
    this.shopRepository,
    this.currentUserId,
  });

  final EnvironmentsRepository? environmentsRepository;
  final ShopRepository? shopRepository;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<TransferHistoryController>(
      create: (_) => TransferHistoryController(
        environmentsRepository: environmentsRepository,
        shopRepository: shopRepository,
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
    final ctrl = context.watch<TransferHistoryController>();
    return Scaffold(
      backgroundColor: NinhoColors.background,
      appBar: AppBar(
        backgroundColor: NinhoColors.background,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          key: const Key('transfer_history_back'),
          icon: const Icon(Icons.arrow_back, color: NinhoColors.primary),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(NinhoRoutes.shop);
            }
          },
        ),
        title: Text(
          'Histórico',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: NinhoColors.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _Body(controller: ctrl),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.controller});
  final TransferHistoryController controller;

  @override
  Widget build(BuildContext context) {
    switch (controller.status) {
      case TransferHistoryStatus.idle:
      case TransferHistoryStatus.loading:
        return const Center(
          child: CircularProgressIndicator(color: NinhoColors.primary),
        );
      case TransferHistoryStatus.error:
        return _ErrorView(
          message: controller.error ?? 'Erro desconhecido',
          onRetry: controller.load,
        );
      case TransferHistoryStatus.ready:
        if (controller.entries.isEmpty) return const _EmptyView();
        return RefreshIndicator(
          onRefresh: controller.load,
          color: NinhoColors.primary,
          child: ListView.separated(
            padding: const EdgeInsets.all(NinhoSpacing.marginMobile),
            itemCount: controller.entries.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: NinhoSpacing.stackSm),
            itemBuilder: (_, i) => _HistoryCard(
              entry: controller.entries[i],
              currentUserId: controller.currentUserId,
            ),
          ),
        );
    }
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(NinhoSpacing.marginMobile),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              key: const Key('transfer_history_error'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: NinhoColors.error,
              ),
            ),
            const SizedBox(height: NinhoSpacing.stackMd),
            FilledButton.tonal(
              key: const Key('transfer_history_retry'),
              onPressed: onRetry,
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(NinhoSpacing.marginMobile),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.history,
              size: 48,
              color: NinhoColors.outlineVariant,
            ),
            const SizedBox(height: NinhoSpacing.stackSm),
            Text(
              'Nenhuma transferência ainda',
              key: const Key('transfer_history_empty'),
              style: theme.textTheme.titleMedium?.copyWith(
                color: NinhoColors.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Quando alguém transferir uma tarefa, aparece aqui.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: NinhoColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.entry, required this.currentUserId});
  final TransferHistoryEntry entry;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMine = entry.fromUserId == currentUserId;
    final fromLabel = isMine ? 'Você' : 'Morador #${_short(entry.fromUserId)}';
    final toLabel = entry.toUserId == currentUserId
        ? 'você'
        : 'morador #${_short(entry.toUserId)}';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: NinhoColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(NinhoRadii.xl),
        border: Border.all(color: NinhoColors.surfaceContainerHigh),
      ),
      child: Padding(
        padding: const EdgeInsets.all(NinhoSpacing.paddingCard),
        child: Row(
          children: [
            _Avatar(label: fromLabel),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(
                Icons.arrow_forward,
                size: 16,
                color: NinhoColors.onSurfaceVariant,
              ),
            ),
            _Avatar(label: toLabel),
            const SizedBox(width: NinhoSpacing.stackMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$fromLabel passou pra $toLabel',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: NinhoColors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(entry.createdAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: NinhoColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: NinhoColors.tertiaryFixed,
                borderRadius: BorderRadius.circular(NinhoRadii.full),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      size: 14,
                      color: NinhoColors.tertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${entry.costDust}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: NinhoColors.tertiary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final initial = label.characters.first.toUpperCase();
    return CircleAvatar(
      radius: 16,
      backgroundColor: NinhoColors.primaryFixed,
      child: Text(
        initial,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: NinhoColors.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _short(String userId) =>
    userId.length >= 6 ? userId.substring(0, 6) : userId;

String _formatDate(DateTime when) {
  const months = [
    'jan',
    'fev',
    'mar',
    'abr',
    'mai',
    'jun',
    'jul',
    'ago',
    'set',
    'out',
    'nov',
    'dez',
  ];
  final day = when.day.toString().padLeft(2, '0');
  final mon = months[when.month - 1];
  final hh = when.hour.toString().padLeft(2, '0');
  final mm = when.minute.toString().padLeft(2, '0');
  return '$day $mon · $hh:$mm';
}
