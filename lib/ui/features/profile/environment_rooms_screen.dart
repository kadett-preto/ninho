import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/environments_repository.dart';
import '../../core/colors.dart';
import '../../core/routes.dart';
import '../../core/spacing.dart';

// Stitch — "Gerenciar Cômodos - Harmonia Lar" (85eaccfb).
// Fase 11.8 (CRUD sub-task): lista cômodos + add/edit/delete. RLS já
// restringe insert a member e update/delete a owner; UI mostra ação só
// pra owner.
enum RoomsStatus { idle, loading, ready, error }

class EnvironmentRoomsController extends ChangeNotifier {
  EnvironmentRoomsController({EnvironmentsRepository? repository})
    : _repo = repository ?? EnvironmentsRepository();

  final EnvironmentsRepository _repo;

  RoomsStatus _status = RoomsStatus.idle;
  RoomsStatus get status => _status;

  String? _error;
  String? get error => _error;

  String? _envId;
  String? get environmentId => _envId;

  EnvironmentSummary? _summary;
  EnvironmentSummary? get summary => _summary;

  List<RoomRow> _rooms = const [];
  List<RoomRow> get rooms => _rooms;

  bool get isOwner => _summary?.isOwner == true;

  Future<void> load() async {
    _status = RoomsStatus.loading;
    _error = null;
    notifyListeners();
    try {
      _envId = await _repo.fetchCurrentEnvironmentId();
      if (_envId == null) {
        _status = RoomsStatus.error;
        _error = 'Você ainda não tem ninho.';
        notifyListeners();
        return;
      }
      final results = await Future.wait<Object?>([
        _repo.fetchEnvironmentSummary(environmentId: _envId!),
        _repo.fetchRooms(_envId!),
      ]);
      _summary = results[0] as EnvironmentSummary?;
      _rooms = results[1] as List<RoomRow>;
      _status = RoomsStatus.ready;
    } catch (e) {
      _status = RoomsStatus.error;
      _error = 'Não conseguimos carregar os cômodos.';
    } finally {
      notifyListeners();
    }
  }

  Future<bool> createRoom({
    required String name,
    required String sizeCategory,
  }) async {
    final id = _envId;
    if (id == null) return false;
    try {
      final created = await _repo.createRoom(
        environmentId: id,
        name: name,
        sizeCategory: sizeCategory,
      );
      _rooms = [..._rooms, created];
      notifyListeners();
      return true;
    } catch (e) {
      _error = _humanize(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateRoom({
    required String roomId,
    required String name,
    required String sizeCategory,
  }) async {
    try {
      await _repo.updateRoom(
        roomId: roomId,
        name: name,
        sizeCategory: sizeCategory,
      );
      _rooms = [
        for (final r in _rooms)
          if (r.id == roomId)
            RoomRow(
              id: r.id,
              name: name.trim(),
              sizeCategory: sizeCategory.toUpperCase(),
            )
          else
            r,
      ];
      notifyListeners();
      return true;
    } catch (e) {
      _error = _humanize(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteRoom(String roomId) async {
    try {
      await _repo.deleteRoom(roomId);
      _rooms = [
        for (final r in _rooms)
          if (r.id != roomId) r,
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
    if (e is StateError) return e.message;
    final msg = e.toString();
    if (msg.contains('42501')) return 'Apenas o owner pode mudar cômodos.';
    return 'Não conseguimos completar agora. Tente outra vez.';
  }
}

class EnvironmentRoomsScreen extends StatelessWidget {
  const EnvironmentRoomsScreen({super.key, this.environmentsRepository});

  final EnvironmentsRepository? environmentsRepository;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<EnvironmentRoomsController>(
      create: (_) =>
          EnvironmentRoomsController(repository: environmentsRepository)
            ..load(),
      child: const _View(),
    );
  }
}

class _View extends StatelessWidget {
  const _View();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<EnvironmentRoomsController>();
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: NinhoColors.background,
      appBar: AppBar(
        backgroundColor: NinhoColors.background,
        elevation: 0,
        leading: IconButton(
          key: const Key('rooms_back'),
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
          'Cômodos',
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
  final EnvironmentRoomsController controller;

  @override
  Widget build(BuildContext context) {
    switch (controller.status) {
      case RoomsStatus.idle:
      case RoomsStatus.loading:
        return const Center(
          child: CircularProgressIndicator(color: NinhoColors.primary),
        );
      case RoomsStatus.error:
        return _RoomsError(
          message: controller.error ?? 'Erro desconhecido',
          onRetry: controller.load,
        );
      case RoomsStatus.ready:
        return _ReadyView(controller: controller);
    }
  }
}

class _RoomsError extends StatelessWidget {
  const _RoomsError({required this.message, required this.onRetry});
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
              key: const Key('rooms_error'),
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: NinhoColors.error),
            ),
            const SizedBox(height: NinhoSpacing.stackMd),
            FilledButton.tonal(
              key: const Key('rooms_retry'),
              onPressed: onRetry,
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadyView extends StatefulWidget {
  const _ReadyView({required this.controller});
  final EnvironmentRoomsController controller;

  @override
  State<_ReadyView> createState() => _ReadyViewState();
}

class _ReadyViewState extends State<_ReadyView> {
  static const Map<String, IconData> _icons = {
    'cozinha': Icons.kitchen_outlined,
    'sala': Icons.living_outlined,
    'quarto': Icons.bed_outlined,
    'banheiro': Icons.shower_outlined,
    'lavanderia': Icons.local_laundry_service_outlined,
    'área de serviço': Icons.local_laundry_service_outlined,
    'escritório': Icons.work_outline,
    'sacada': Icons.deck_outlined,
    'varanda': Icons.deck_outlined,
  };

  IconData _iconFor(String name) {
    final key = name.trim().toLowerCase();
    return _icons[key] ?? Icons.dashboard_outlined;
  }

  Future<void> _openSheet({RoomRow? existing}) async {
    final ctrl = widget.controller;
    final result = await showModalBottomSheet<_SheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: NinhoColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: _RoomFormSheet(existing: existing),
      ),
    );
    if (result == null) return;
    if (result.delete && existing != null) {
      final confirmed = await _confirmDelete(existing);
      if (confirmed != true) return;
      final ok = await ctrl.deleteRoom(existing.id);
      if (!mounted) return;
      if (!ok) _snack(ctrl.error ?? 'Erro ao excluir.');
      return;
    }
    final ok = existing == null
        ? await ctrl.createRoom(
            name: result.name,
            sizeCategory: result.sizeCategory,
          )
        : await ctrl.updateRoom(
            roomId: existing.id,
            name: result.name,
            sizeCategory: result.sizeCategory,
          );
    if (!mounted) return;
    if (!ok) _snack(ctrl.error ?? 'Erro ao salvar.');
  }

  Future<bool?> _confirmDelete(RoomRow room) async {
    return showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Excluir cômodo?'),
        content: Text(
          'Tarefas associadas a "${room.name}" continuarão existindo, '
          'mas sem cômodo. Quer mesmo excluir?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('room_delete_confirm'),
            style: FilledButton.styleFrom(backgroundColor: NinhoColors.error),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
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
          if (controller.rooms.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: NinhoSpacing.stackLg,
              ),
              child: Text(
                'Nenhum cômodo cadastrado ainda.',
                key: const Key('rooms_empty'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: NinhoColors.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final room in controller.rooms)
              Padding(
                padding: const EdgeInsets.only(bottom: NinhoSpacing.unit),
                child: _RoomTile(
                  room: room,
                  icon: _iconFor(room.name),
                  onTap: controller.isOwner
                      ? () => _openSheet(existing: room)
                      : null,
                ),
              ),
          const SizedBox(height: NinhoSpacing.stackMd),
          if (controller.isOwner)
            OutlinedButton.icon(
              key: const Key('rooms_add'),
              onPressed: () => _openSheet(),
              icon: const Icon(Icons.add),
              label: const Text('Adicionar cômodo'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: NinhoColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(NinhoRadii.lg),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  const _RoomTile({required this.room, required this.icon, this.onTap});
  final RoomRow room;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: NinhoColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(NinhoRadii.lg),
      child: InkWell(
        key: Key('room_${room.id}'),
        borderRadius: BorderRadius.circular(NinhoRadii.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(NinhoSpacing.stackMd),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: NinhoColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(NinhoRadii.lg),
                ),
                child: Icon(icon, color: NinhoColors.primary, size: 22),
              ),
              const SizedBox(width: NinhoSpacing.stackMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: NinhoColors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _sizeLabel(room.sizeCategory),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: NinhoColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(Icons.chevron_right, color: NinhoColors.outline),
            ],
          ),
        ),
      ),
    );
  }
}

String _sizeLabel(String size) {
  switch (size.toUpperCase()) {
    case 'P':
      return 'Pequeno';
    case 'M':
      return 'Médio';
    case 'G':
      return 'Grande';
    default:
      return size;
  }
}

class _SheetResult {
  const _SheetResult({
    required this.name,
    required this.sizeCategory,
    this.delete = false,
  });
  final String name;
  final String sizeCategory;
  final bool delete;
}

class _RoomFormSheet extends StatefulWidget {
  const _RoomFormSheet({this.existing});
  final RoomRow? existing;

  @override
  State<_RoomFormSheet> createState() => _RoomFormSheetState();
}

class _RoomFormSheetState extends State<_RoomFormSheet> {
  late final TextEditingController _name;
  late String _size;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _size = (widget.existing?.sizeCategory ?? 'M').toUpperCase();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _valid => _name.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.existing != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        NinhoSpacing.marginMobile,
        NinhoSpacing.stackLg,
        NinhoSpacing.marginMobile,
        NinhoSpacing.stackLg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEdit ? 'Editar cômodo' : 'Novo cômodo',
            style: theme.textTheme.titleMedium?.copyWith(
              color: NinhoColors.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: NinhoSpacing.stackMd),
          TextField(
            key: const Key('room_form_name'),
            controller: _name,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nome',
              hintText: 'Ex: Cozinha',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: NinhoSpacing.stackMd),
          Text(
            'Tamanho',
            style: theme.textTheme.labelLarge?.copyWith(
              color: NinhoColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: NinhoSpacing.stackSm),
          Wrap(
            spacing: 8,
            children: [
              for (final size in const ['P', 'M', 'G'])
                ChoiceChip(
                  key: Key('room_size_$size'),
                  label: Text(_sizeLabel(size)),
                  selected: _size == size,
                  onSelected: (_) => setState(() => _size = size),
                ),
            ],
          ),
          const SizedBox(height: NinhoSpacing.stackLg),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (isEdit)
                TextButton.icon(
                  key: const Key('room_form_delete'),
                  onPressed: () => Navigator.of(context).pop(
                    _SheetResult(
                      name: _name.text,
                      sizeCategory: _size,
                      delete: true,
                    ),
                  ),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: NinhoColors.error,
                  ),
                  label: const Text(
                    'Excluir',
                    style: TextStyle(color: NinhoColors.error),
                  ),
                ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                key: const Key('room_form_save'),
                onPressed: _valid
                    ? () => Navigator.of(
                        context,
                      ).pop(_SheetResult(name: _name.text, sizeCategory: _size))
                    : null,
                child: Text(isEdit ? 'Salvar' : 'Adicionar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
