import 'package:flutter/foundation.dart';

import '../../../data/repositories/environments_repository.dart';
import '../../../data/repositories/shop_repository.dart';
import '../../../data/repositories/tasks_repository.dart';
import '../../../data/services/auth_service.dart';

enum ShopStatus { idle, loading, ready, transferring, error }

class ShopController extends ChangeNotifier {
  ShopController({
    EnvironmentsRepository? environmentsRepository,
    ShopRepository? shopRepository,
    TasksRepository? tasksRepository,
    String? currentUserId,
  }) : _envRepo = environmentsRepository ?? EnvironmentsRepository(),
       _shopRepo = shopRepository ?? const ShopRepository(),
       _tasksRepo = tasksRepository ?? const TasksRepository(),
       _explicitUserId = currentUserId;

  final EnvironmentsRepository _envRepo;
  final ShopRepository _shopRepo;
  final TasksRepository _tasksRepo;
  final String? _explicitUserId;

  ShopStatus _status = ShopStatus.idle;
  ShopStatus get status => _status;

  String? _error;
  String? get error => _error;

  String? _environmentId;
  String? get environmentId => _environmentId;

  int _balance = 0;
  int get balance => _balance;

  List<ShopMember> _members = const [];
  List<ShopMember> get otherMembers => _members;

  List<TaskListItem> _myTasks = const [];
  List<TaskListItem> get myTasks => _myTasks;

  static const transferCost = 30;
  bool get canAffordTransfer => _balance >= transferCost;

  String? get currentUserId => _explicitUserId ?? AuthService.currentUser?.id;

  Future<void> load() async {
    _status = ShopStatus.loading;
    _error = null;
    notifyListeners();
    try {
      final envId = await _envRepo.fetchCurrentEnvironmentId();
      if (envId == null) {
        throw StateError('Você precisa cadastrar um ninho primeiro.');
      }
      _environmentId = envId;
      _balance = await _shopRepo.fetchBalance(environmentId: envId);
      _members = await _shopRepo.fetchOtherMembers(environmentId: envId);
      // Pega só tasks ativas atribuídas ao caller para a sheet de
      // transferência. RLS filtra; depois aplicamos `assignee == me`.
      final all = await _tasksRepo.fetchTaskList(environmentId: envId);
      final me = currentUserId;
      _myTasks = me == null
          ? const []
          : [
              for (final t in all)
                if (t.assigneeId == me) t,
            ];
      _status = ShopStatus.ready;
    } catch (e) {
      _status = ShopStatus.error;
      _error = _humanize(e);
    } finally {
      notifyListeners();
    }
  }

  Future<TransferResult?> transfer({
    required String taskId,
    required String toUserId,
  }) async {
    _status = ShopStatus.transferring;
    _error = null;
    notifyListeners();
    try {
      final result = await _shopRepo.transferTask(
        taskId: taskId,
        toUserId: toUserId,
      );
      _balance = result.newBalance;
      // Remove a task da lista local — já foi reassignada.
      _myTasks = [
        for (final t in _myTasks)
          if (t.id != taskId) t,
      ];
      _status = ShopStatus.ready;
      notifyListeners();
      return result;
    } catch (e) {
      _status = ShopStatus.ready;
      _error = _humanize(e);
      notifyListeners();
      return null;
    }
  }

  String _humanize(Object e) {
    if (e is StateError) return e.message;
    final msg = e.toString();
    if (msg.contains('Saldo insuficiente')) {
      return 'Saldo insuficiente — junte mais poeira concluindo tarefas.';
    }
    if (msg.contains('já usou sua transferência')) {
      return 'Você já usou sua transferência desta semana.';
    }
    if (msg.contains('desativada')) {
      return 'O owner desativou as transferências neste ninho.';
    }
    if (msg.contains('mesmo destinatário')) {
      return 'Tente outro destinatário — não pode ser o mesmo duas semanas seguidas.';
    }
    if (msg.contains('Cooldown extra')) {
      return 'Cooldown extra (2-pessoas): aguarde mais uma semana.';
    }
    if (msg.contains('42501')) return 'Sem permissão para esta ação.';
    if (msg.contains('Destinatário')) {
      return 'Destinatário inválido.';
    }
    if (msg.contains('arquivada')) return 'Tarefa arquivada.';
    return 'Não foi possível transferir agora.';
  }
}
