import 'package:flutter/foundation.dart';

import '../../../data/repositories/environments_repository.dart';
import '../../../data/repositories/suggestions_repository.dart'
    show TaskDifficulty;
import '../../../data/repositories/tasks_repository.dart';
import '../../../data/services/auth_service.dart';

enum TaskFormStatus { idle, loading, ready, submitting, error }

// Recorrências canônicas que a UI oferece. Mantemos o mesmo conjunto de
// intervalos aceitos pela RPC `accept_suggested_tasks` para consistência.
enum TaskRecurrence {
  none(null, 'Sem repetição', null),
  daily(1, 'Diária', 'RRULE:FREQ=DAILY;INTERVAL=1'),
  every3days(3, 'A cada 3 dias', 'RRULE:FREQ=DAILY;INTERVAL=3'),
  weekly(7, 'Semanal', 'RRULE:FREQ=DAILY;INTERVAL=7'),
  biweekly(14, 'Quinzenal', 'RRULE:FREQ=DAILY;INTERVAL=14'),
  monthly(30, 'Mensal', 'RRULE:FREQ=DAILY;INTERVAL=30');

  const TaskRecurrence(this.intervalDays, this.label, this.rrule);

  final int? intervalDays;
  final String label;
  final String? rrule;

  static TaskRecurrence fromRrule(String? rrule) {
    if (rrule == null || rrule.isEmpty) return TaskRecurrence.none;
    for (final r in values) {
      if (r.rrule == rrule) return r;
    }
    return TaskRecurrence.none;
  }
}

class TaskFormController extends ChangeNotifier {
  TaskFormController({
    this.taskId,
    EnvironmentsRepository? environmentsRepository,
    TasksRepository? tasksRepository,
    String? currentUserId,
  }) : _envRepo = environmentsRepository ?? EnvironmentsRepository(),
       _tasksRepo = tasksRepository ?? const TasksRepository(),
       _explicitUserId = currentUserId;

  final String? taskId;
  final EnvironmentsRepository _envRepo;
  final TasksRepository _tasksRepo;
  final String? _explicitUserId;

  bool get isEditing => taskId != null;

  TaskFormStatus _status = TaskFormStatus.idle;
  TaskFormStatus get status => _status;

  String? _error;
  String? get error => _error;

  String? _environmentId;
  String? get environmentId => _environmentId;

  List<RoomRow> _rooms = const [];
  List<RoomRow> get rooms => _rooms;

  // Form state
  String _title = '';
  String get title => _title;

  String _description = '';
  String get description => _description;

  String? _roomId;
  String? get roomId => _roomId;

  String? _assigneeId;
  String? get assigneeId => _assigneeId;

  TaskDifficulty _difficulty = TaskDifficulty.mamao;
  TaskDifficulty get difficulty => _difficulty;

  DateTime _startDate = DateTime.now();
  DateTime get startDate => _startDate;

  TaskRecurrence _recurrence = TaskRecurrence.none;
  TaskRecurrence get recurrence => _recurrence;

  String? get currentUserId => _explicitUserId ?? AuthService.currentUser?.id;

  Future<void> load() async {
    _status = TaskFormStatus.loading;
    _error = null;
    notifyListeners();
    try {
      final envId = await _envRepo.fetchCurrentEnvironmentId();
      if (envId == null) {
        throw StateError('Você precisa cadastrar um ninho primeiro.');
      }
      _environmentId = envId;
      _rooms = await _envRepo.fetchRooms(envId);
      // Por padrão atribui ao próprio usuário; UI pode trocar para "Sem
      // responsável" via toggle.
      _assigneeId = currentUserId;
      final loadId = taskId;
      if (loadId != null) {
        final task = await _tasksRepo.fetchTask(taskId: loadId);
        _title = task.title;
        _roomId = task.roomId;
        _assigneeId = task.assigneeId;
        _difficulty = task.difficulty;
        _recurrence = TaskRecurrence.fromRrule(task.recurrenceRule);
      } else if (_rooms.isNotEmpty) {
        _roomId = _rooms.first.id;
      }
      _status = TaskFormStatus.ready;
    } catch (e) {
      _status = TaskFormStatus.error;
      _error = _humanize(e);
    } finally {
      notifyListeners();
    }
  }

  void setTitle(String value) {
    _title = value;
    // Sem notify — TextField já é controlado externamente.
  }

  void setDescription(String value) {
    _description = value;
  }

  void setRoom(String? roomId) {
    if (_roomId == roomId) return;
    _roomId = roomId;
    notifyListeners();
  }

  void setAssigneeToSelf() {
    final me = currentUserId;
    if (_assigneeId == me) return;
    _assigneeId = me;
    notifyListeners();
  }

  void clearAssignee() {
    if (_assigneeId == null) return;
    _assigneeId = null;
    notifyListeners();
  }

  void toggleAssignee() {
    if (_assigneeId == null) {
      setAssigneeToSelf();
    } else {
      clearAssignee();
    }
  }

  void setDifficulty(TaskDifficulty value) {
    if (_difficulty == value) return;
    _difficulty = value;
    notifyListeners();
  }

  void setStartDate(DateTime value) {
    final next = DateTime(value.year, value.month, value.day);
    if (next == _startDate) return;
    _startDate = next;
    notifyListeners();
  }

  void setRecurrence(TaskRecurrence value) {
    if (_recurrence == value) return;
    _recurrence = value;
    notifyListeners();
  }

  String? validate() {
    if (_title.trim().isEmpty) return 'Informe um título.';
    if (_title.trim().length > 120) return 'Título muito longo.';
    if (_environmentId == null) return 'Sem ninho ativo.';
    return null;
  }

  Future<TaskSubmitResult?> submit() async {
    final err = validate();
    if (err != null) {
      _error = err;
      notifyListeners();
      return null;
    }
    final envId = _environmentId;
    if (envId == null) return null;
    _status = TaskFormStatus.submitting;
    _error = null;
    notifyListeners();
    try {
      final editingId = taskId;
      if (editingId != null) {
        await _tasksRepo.updateTask(
          taskId: editingId,
          title: _title,
          difficulty: _difficulty,
          startDate: _startDate,
          description: _description.isEmpty ? null : _description,
          clearDescription: _description.isEmpty,
          roomId: _roomId,
          clearRoom: _roomId == null,
          assigneeId: _assigneeId,
          clearAssignee: _assigneeId == null,
          recurrenceRule: _recurrence.rrule,
          clearRecurrence: _recurrence == TaskRecurrence.none,
        );
        _status = TaskFormStatus.ready;
        notifyListeners();
        return TaskSubmitResult(taskId: editingId, created: false);
      }
      final newId = await _tasksRepo.createTask(
        environmentId: envId,
        title: _title,
        difficulty: _difficulty,
        startDate: _startDate,
        description: _description.isEmpty ? null : _description,
        roomId: _roomId,
        assigneeId: _assigneeId,
        recurrenceRule: _recurrence.rrule,
      );
      _status = TaskFormStatus.ready;
      notifyListeners();
      return TaskSubmitResult(taskId: newId, created: true);
    } catch (e) {
      _status = TaskFormStatus.ready;
      _error = _humanize(e);
      notifyListeners();
      return null;
    }
  }

  Future<bool> archive() async {
    final id = taskId;
    if (id == null) return false;
    _status = TaskFormStatus.submitting;
    _error = null;
    notifyListeners();
    try {
      await _tasksRepo.archiveTask(taskId: id);
      _status = TaskFormStatus.ready;
      notifyListeners();
      return true;
    } catch (e) {
      _status = TaskFormStatus.ready;
      _error = _humanize(e);
      notifyListeners();
      return false;
    }
  }

  String _humanize(Object e) {
    if (e is StateError) return e.message;
    final msg = e.toString();
    if (msg.contains('42501')) {
      return 'Sem permissão para essa ação.';
    }
    if (msg.contains('23502')) {
      return 'Campo obrigatório em falta.';
    }
    if (msg.contains('Tarefa não encontrada')) {
      return 'Tarefa não encontrada.';
    }
    return 'Não conseguimos salvar agora. Tente outra vez.';
  }
}

class TaskSubmitResult {
  const TaskSubmitResult({required this.taskId, required this.created});
  final String taskId;
  final bool created;
}
