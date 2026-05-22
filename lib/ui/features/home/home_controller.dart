import 'package:flutter/foundation.dart';

import '../../../data/repositories/environments_repository.dart';
import '../../../data/repositories/shop_repository.dart';
import '../../../data/repositories/streaks_repository.dart';
import '../../../data/repositories/tasks_repository.dart';
import '../../../data/services/auth_service.dart';

enum HomeStatus { idle, loading, ready, error, noEnvironment }

// Home / "Hoje" (IDEA.md §4.4, Fase 6.2).
//
// Agrega: streak do usuário + streak do ninho + saldo de poeira + tasks
// esperadas hoje para o usuário (recorrência respeitada, sem as já
// concluídas). RLS no banco isola tudo por ninho.
class HomeController extends ChangeNotifier {
  HomeController({
    EnvironmentsRepository? environmentsRepository,
    TasksRepository? tasksRepository,
    StreaksRepository? streaksRepository,
    ShopRepository? shopRepository,
    String? currentUserId,
    DateTime Function()? now,
  })  : _envRepo = environmentsRepository ?? EnvironmentsRepository(),
        _tasksRepo = tasksRepository ?? const TasksRepository(),
        _streaksRepo = streaksRepository ?? const StreaksRepository(),
        _shopRepo = shopRepository ?? const ShopRepository(),
        _explicitUserId = currentUserId,
        _now = now ?? DateTime.now;

  final EnvironmentsRepository _envRepo;
  final TasksRepository _tasksRepo;
  final StreaksRepository _streaksRepo;
  final ShopRepository _shopRepo;
  final String? _explicitUserId;
  final DateTime Function() _now;

  HomeStatus _status = HomeStatus.idle;
  HomeStatus get status => _status;

  String? _error;
  String? get error => _error;

  String? _environmentId;
  String? get environmentId => _environmentId;

  int _userStreak = 0;
  int get userStreak => _userStreak;

  int _environmentStreak = 0;
  int get environmentStreak => _environmentStreak;

  int _dustBalance = 0;
  int get dustBalance => _dustBalance;

  List<TaskListItem> _todayTasks = const [];
  List<TaskListItem> get todayTasks => _todayTasks;

  String? get currentUserId =>
      _explicitUserId ?? AuthService.currentUser?.id;

  Future<void> load() async {
    _status = HomeStatus.loading;
    _error = null;
    notifyListeners();
    try {
      final envId = await _envRepo.fetchCurrentEnvironmentId();
      if (envId == null) {
        _status = HomeStatus.noEnvironment;
        notifyListeners();
        return;
      }
      _environmentId = envId;

      // Carrega em paralelo. Cada repo aborta isolado em falha.
      final results = await Future.wait<Object?>([
        _tasksRepo.fetchTaskList(environmentId: envId),
        _streaksRepo.fetchSummary(environmentId: envId),
        _shopRepo.fetchBalance(environmentId: envId),
      ]);
      final tasks = results[0] as List<TaskListItem>;
      final streak = results[1] as StreakSummary;
      final dust = results[2] as int;

      _todayTasks = _filterTodayForUser(tasks, _now());
      _userStreak = streak.userCount;
      _environmentStreak = streak.environmentCount;
      _dustBalance = dust;
      _status = HomeStatus.ready;
    } catch (e) {
      _status = HomeStatus.error;
      _error = _humanize(e);
    } finally {
      notifyListeners();
    }
  }

  // "Tarefas de hoje" do morador: assignee = eu, isExpectedOn(hoje), e
  // não concluída ainda hoje. Sem assignee → não aparece (decisão MVP em
  // linha com IDEA.md §5.7).
  List<TaskListItem> _filterTodayForUser(
    List<TaskListItem> all,
    DateTime now,
  ) {
    final me = currentUserId;
    return [
      for (final t in all)
        if (t.assigneeId == me && me != null
            && t.isExpectedOn(now)
            && !t.completedOn(now))
          t,
    ];
  }

  String _humanize(Object e) {
    if (e is StateError) return e.message;
    final msg = e.toString();
    if (msg.contains('42501')) return 'Sem permissão para ver o ninho.';
    return 'Não conseguimos carregar o ninho agora. Tente outra vez.';
  }
}
