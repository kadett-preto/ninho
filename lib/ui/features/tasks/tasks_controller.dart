import 'package:flutter/foundation.dart';

import '../../../data/repositories/environments_repository.dart';
import '../../../data/repositories/tasks_repository.dart';
import '../../../data/services/auth_service.dart';

enum TasksScreenStatus { idle, loading, ready, error }

enum TaskFilter { all, mine, pending, completed }

enum TaskPeriod { today, week }

class TasksController extends ChangeNotifier {
  TasksController({
    EnvironmentsRepository? environmentsRepository,
    TasksRepository? tasksRepository,
    String? currentUserId,
    DateTime Function()? now,
  }) : _envRepo = environmentsRepository ?? EnvironmentsRepository(),
       _tasksRepo = tasksRepository ?? const TasksRepository(),
       _explicitUserId = currentUserId,
       _now = now ?? DateTime.now;

  final EnvironmentsRepository _envRepo;
  final TasksRepository _tasksRepo;
  final String? _explicitUserId;
  final DateTime Function() _now;

  TasksScreenStatus _status = TasksScreenStatus.idle;
  TasksScreenStatus get status => _status;

  String? _error;
  String? get error => _error;

  String? _environmentId;
  String? get environmentId => _environmentId;

  List<TaskListItem> _items = const [];
  List<TaskListItem> get items => _items;

  Map<String, RoomRow> _rooms = const {};
  Map<String, RoomRow> get rooms => _rooms;

  TaskFilter _filter = TaskFilter.all;
  TaskFilter get filter => _filter;

  TaskPeriod _period = TaskPeriod.today;
  TaskPeriod get period => _period;

  // Filtro opcional por cômodo. Quando setado, a UI também aciona o chip
  // "Por cômodo" como ativo.
  String? _roomFilter;
  String? get roomFilter => _roomFilter;

  String? get currentUserId => _explicitUserId ?? AuthService.currentUser?.id;

  Future<void> load() async {
    _status = TasksScreenStatus.loading;
    _error = null;
    notifyListeners();
    try {
      final envId = await _envRepo.fetchCurrentEnvironmentId();
      if (envId == null) {
        throw StateError('Você precisa cadastrar um ninho primeiro.');
      }
      final roomsList = await _envRepo.fetchRooms(envId);
      final items = await _tasksRepo.fetchTaskList(environmentId: envId);
      _environmentId = envId;
      _rooms = {for (final r in roomsList) r.id: r};
      _items = items;
      _status = TasksScreenStatus.ready;
    } catch (e) {
      _status = TasksScreenStatus.error;
      _error = _humanize(e);
    } finally {
      notifyListeners();
    }
  }

  void setFilter(TaskFilter value) {
    if (_filter == value) return;
    _filter = value;
    notifyListeners();
  }

  void setPeriod(TaskPeriod value) {
    if (_period == value) return;
    _period = value;
    notifyListeners();
  }

  void setRoomFilter(String? roomId) {
    if (_roomFilter == roomId) return;
    _roomFilter = roomId;
    notifyListeners();
  }

  void clearRoomFilter() => setRoomFilter(null);

  // Retorna a lista filtrada considerando filter + period + roomFilter.
  // hasCompletionInPeriod usa o início do dia local ou início da semana ISO
  // (segunda) como cutoff.
  List<TaskListItem> filteredItems() {
    final cutoff = _periodStart();
    final userId = currentUserId;
    return [
      for (final task in _items)
        if (_matchesRoom(task) && _matchesFilter(task, userId, cutoff)) task,
    ];
  }

  bool _matchesRoom(TaskListItem task) {
    if (_roomFilter == null) return true;
    return task.roomId == _roomFilter;
  }

  bool _matchesFilter(TaskListItem task, String? userId, DateTime cutoff) {
    final completed = _completedInPeriod(task, cutoff);
    switch (_filter) {
      case TaskFilter.all:
        return true;
      case TaskFilter.mine:
        return userId != null && task.assigneeId == userId;
      case TaskFilter.pending:
        return !completed;
      case TaskFilter.completed:
        return completed;
    }
  }

  bool completedInCurrentPeriod(TaskListItem task) {
    return _completedInPeriod(task, _periodStart());
  }

  bool _completedInPeriod(TaskListItem task, DateTime cutoff) {
    for (final c in task.recentCompletions) {
      if (!c.completedAt.isBefore(cutoff)) return true;
    }
    return false;
  }

  DateTime _periodStart() {
    final now = _now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    if (_period == TaskPeriod.today) return startOfDay;
    final weekdayOffset = now.weekday - DateTime.monday;
    return startOfDay.subtract(Duration(days: weekdayOffset));
  }

  // Mapeia erros conhecidos a mensagens humanas. Resto vira mensagem
  // genérica para não vazar detalhes técnicos.
  String _humanize(Object e) {
    if (e is StateError) return e.message;
    final msg = e.toString();
    if (msg.contains('42501')) {
      return 'Sem permissão para ver as tarefas.';
    }
    return 'Não conseguimos carregar as tarefas agora. Tente outra vez.';
  }
}
