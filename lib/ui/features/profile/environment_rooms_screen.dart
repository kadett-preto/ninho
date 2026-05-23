import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/environments_repository.dart';
import '../../core/colors.dart';
import '../../core/routes.dart';
import '../../core/spacing.dart';

// Stitch — "Gerenciar Cômodos - Harmonia Lar" (85eaccfb).
// Fase 11.8: lista cômodos do ninho corrente. CRUD completo (add/edit/
// delete) fica para sub-task; por ora a tela é read-only mas funcional.
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

  List<RoomRow> _rooms = const [];
  List<RoomRow> get rooms => _rooms;

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
      _rooms = await _repo.fetchRooms(_envId!);
      _status = RoomsStatus.ready;
    } catch (e) {
      _status = RoomsStatus.error;
      _error = 'Não conseguimos carregar os cômodos.';
    } finally {
      notifyListeners();
    }
  }
}

class EnvironmentRoomsScreen extends StatelessWidget {
  const EnvironmentRoomsScreen({super.key, this.environmentsRepository});

  final EnvironmentsRepository? environmentsRepository;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<EnvironmentRoomsController>(
      create: (_) => EnvironmentRoomsController(
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
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: NinhoColors.error,
              ),
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

class _ReadyView extends StatelessWidget {
  const _ReadyView({required this.controller});
  final EnvironmentRoomsController controller;

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

  @override
  Widget build(BuildContext context) {
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
                ),
              ),
          const SizedBox(height: NinhoSpacing.stackMd),
          OutlinedButton.icon(
            key: const Key('rooms_add'),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Em breve — adicionar cômodo.'),
              ),
            ),
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
  const _RoomTile({required this.room, required this.icon});
  final RoomRow room;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: NinhoColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(NinhoRadii.lg),
      child: InkWell(
        key: Key('room_${room.id}'),
        borderRadius: BorderRadius.circular(NinhoRadii.lg),
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Em breve — detalhe do cômodo.')),
        ),
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
              const Icon(Icons.chevron_right, color: NinhoColors.outline),
            ],
          ),
        ),
      ),
    );
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
}
