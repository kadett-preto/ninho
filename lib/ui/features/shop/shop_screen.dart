import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/environments_repository.dart';
import '../../../data/repositories/shop_repository.dart';
import '../../../data/repositories/tasks_repository.dart';
import '../../core/colors.dart';
import '../../core/routes.dart';
import '../../core/spacing.dart';
import 'shop_controller.dart';

// Stitch — "Loja da Poeira" (7bdc5123d9a84cdd93f313024fccd516).
class ShopScreen extends StatelessWidget {
  const ShopScreen({
    super.key,
    this.environmentsRepository,
    this.shopRepository,
    this.tasksRepository,
    this.currentUserId,
  });

  final EnvironmentsRepository? environmentsRepository;
  final ShopRepository? shopRepository;
  final TasksRepository? tasksRepository;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ShopController>(
      create: (_) => ShopController(
        environmentsRepository: environmentsRepository,
        shopRepository: shopRepository,
        tasksRepository: tasksRepository,
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
    final ctrl = context.watch<ShopController>();
    return Scaffold(
      backgroundColor: NinhoColors.background,
      appBar: AppBar(
        backgroundColor: NinhoColors.background,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          key: const Key('shop_back'),
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
          'Loja da Poeira',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
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
  final ShopController controller;

  @override
  Widget build(BuildContext context) {
    switch (controller.status) {
      case ShopStatus.idle:
      case ShopStatus.loading:
        return const Center(
          child: CircularProgressIndicator(color: NinhoColors.primary),
        );
      case ShopStatus.error:
        return _ErrorView(message: controller.error ?? 'Erro desconhecido');
      case ShopStatus.ready:
      case ShopStatus.transferring:
        return _Layout(controller: controller);
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
          key: const Key('shop_error'),
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: NinhoColors.error),
        ),
      ),
    );
  }
}

class _Layout extends StatelessWidget {
  const _Layout({required this.controller});
  final ShopController controller;

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
              NinhoSpacing.stackLg,
              NinhoSpacing.marginMobile,
              120,
            ),
            children: [
              _BalanceCard(balance: controller.balance),
              const SizedBox(height: NinhoSpacing.stackLg),
              _SectionTitle('Itens'),
              const SizedBox(height: NinhoSpacing.stackMd),
              _TransferCard(controller: controller),
              const SizedBox(height: NinhoSpacing.stackLg),
              _SectionTitle('Em breve'),
              const SizedBox(height: NinhoSpacing.stackMd),
              const _ComingSoonRow(icon: Icons.ac_unit, label: 'Freeze extra'),
              const SizedBox(height: NinhoSpacing.stackSm),
              const _ComingSoonRow(
                icon: Icons.skip_next_outlined,
                label: 'Skip de tarefa',
              ),
              if (controller.error != null &&
                  controller.status == ShopStatus.ready) ...[
                const SizedBox(height: NinhoSpacing.stackLg),
                Text(
                  controller.error!,
                  key: const Key('shop_inline_error'),
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: NinhoColors.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance});
  final int balance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: NinhoColors.tertiaryFixed,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.auto_awesome, color: NinhoColors.tertiary),
        ),
        const SizedBox(height: NinhoSpacing.stackSm),
        Text(
          '$balance',
          key: const Key('shop_balance'),
          style: theme.textTheme.displayLarge?.copyWith(
            color: NinhoColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          balance > 0
              ? 'poeiras disponíveis'
              : 'Conclua tarefas pra ganhar mais.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: NinhoColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: NinhoColors.onBackground,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _TransferCard extends StatelessWidget {
  const _TransferCard({required this.controller});
  final ShopController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canBuy =
        controller.canAffordTransfer &&
        controller.otherMembers.isNotEmpty &&
        controller.myTasks.isNotEmpty;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: NinhoColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(NinhoRadii.xl),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14944931),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(NinhoSpacing.paddingCard),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: NinhoColors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.swap_horiz,
                    color: NinhoColors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: NinhoSpacing.stackMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transferência de Tarefa',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: NinhoColors.onBackground,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Passe 1 tarefa pra outra pessoa.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: NinhoColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: NinhoSpacing.stackMd),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: NinhoColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(NinhoRadii.full),
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
                        '${ShopController.transferCost}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: NinhoColors.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                FilledButton(
                  key: const Key('shop_transfer_cta'),
                  onPressed: canBuy ? () => _openSheet(context) : null,
                  child: Text(canBuy ? 'Comprar' : _disabledReason(controller)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: NinhoColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _TransferSheet(controller: controller),
    );
  }

  String _disabledReason(ShopController c) {
    if (!c.canAffordTransfer) return 'Saldo curto';
    if (c.otherMembers.isEmpty) return 'Sem outros';
    if (c.myTasks.isEmpty) return 'Sem tasks';
    return 'Indisponível';
  }
}

class _TransferSheet extends StatefulWidget {
  const _TransferSheet({required this.controller});
  final ShopController controller;

  @override
  State<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends State<_TransferSheet> {
  String? _selectedTaskId;
  String? _selectedToUserId;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller.myTasks.length == 1) {
      _selectedTaskId = widget.controller.myTasks.first.id;
    }
    if (widget.controller.otherMembers.length == 1) {
      _selectedToUserId = widget.controller.otherMembers.first.userId;
    }
  }

  bool get _canConfirm =>
      !_submitting && _selectedTaskId != null && _selectedToUserId != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = widget.controller;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          NinhoSpacing.marginMobile,
          NinhoSpacing.stackMd,
          NinhoSpacing.marginMobile,
          NinhoSpacing.stackMd + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Transferir tarefa',
              style: theme.textTheme.titleMedium?.copyWith(
                color: NinhoColors.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Custo: ${ShopController.transferCost} poeiras. Limite: 1 por semana.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: NinhoColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: NinhoSpacing.stackLg),
            _Label('Tarefa'),
            const SizedBox(height: NinhoSpacing.stackSm),
            DropdownButtonFormField<String>(
              key: const Key('transfer_task_picker'),
              initialValue: _selectedTaskId,
              isExpanded: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: [
                for (final t in c.myTasks)
                  DropdownMenuItem(
                    value: t.id,
                    child: Text(t.title, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() => _selectedTaskId = v),
            ),
            const SizedBox(height: NinhoSpacing.stackMd),
            _Label('Destinatário'),
            const SizedBox(height: NinhoSpacing.stackSm),
            DropdownButtonFormField<String>(
              key: const Key('transfer_to_picker'),
              initialValue: _selectedToUserId,
              isExpanded: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: [
                for (final m in c.otherMembers)
                  DropdownMenuItem(
                    value: m.userId,
                    child: Text('Morador #${m.shortId}'),
                  ),
              ],
              onChanged: (v) => setState(() => _selectedToUserId = v),
            ),
            const SizedBox(height: NinhoSpacing.stackLg),
            FilledButton(
              key: const Key('transfer_confirm'),
              onPressed: _canConfirm ? _confirm : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Confirmar transferência'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirm() async {
    setState(() => _submitting = true);
    final result = await widget.controller.transfer(
      taskId: _selectedTaskId!,
      toUserId: _selectedToUserId!,
    );
    if (!mounted) return;
    if (result == null) {
      setState(() => _submitting = false);
      final msg = widget.controller.error;
      if (msg != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
      return;
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Tarefa transferida. Saldo: ${result.newBalance} poeiras.',
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: NinhoColors.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      ),
    );
  }
}

class _ComingSoonRow extends StatelessWidget {
  const _ComingSoonRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(NinhoSpacing.paddingCard),
      decoration: BoxDecoration(
        color: NinhoColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(NinhoRadii.lg),
        border: Border.all(color: NinhoColors.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, color: NinhoColors.outline),
          const SizedBox(width: NinhoSpacing.stackMd),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: NinhoColors.onBackground,
              ),
            ),
          ),
          const Icon(Icons.lock_outline, color: NinhoColors.outline),
        ],
      ),
    );
  }
}
