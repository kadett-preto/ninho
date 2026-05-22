import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ninho/data/repositories/environments_repository.dart';
import 'package:ninho/data/repositories/suggestions_repository.dart' show TaskDifficulty;
import 'package:ninho/data/repositories/tasks_repository.dart';
import 'package:ninho/ui/core/theme.dart';
import 'package:ninho/ui/features/tasks/tasks_screen.dart';

class _FakeEnvRepo extends EnvironmentsRepository {
  _FakeEnvRepo({this.envId = 'env-1', this.rooms = const []});
  final String? envId;
  final List<RoomRow> rooms;

  @override
  Future<String?> fetchCurrentEnvironmentId() async => envId;

  @override
  Future<List<RoomRow>> fetchRooms(String environmentId) async => rooms;
}

class _FakeTasksRepo extends TasksRepository {
  _FakeTasksRepo({this.tasks = const []});
  final List<TaskListItem> tasks;

  @override
  Future<List<TaskListItem>> fetchTaskList({required String environmentId}) async {
    return tasks;
  }
}

void _setMobile(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _wrap(TasksScreen screen) {
  final router = GoRouter(
    initialLocation: '/test',
    routes: [
      GoRoute(path: '/test', builder: (_, _) => screen),
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('HOME')),
      ),
      GoRoute(
        path: '/tasks/:taskId',
        builder: (_, state) => Scaffold(
          body: Text('DETAIL ${state.pathParameters['taskId']}'),
        ),
      ),
      GoRoute(
        path: '/tasks/:taskId/complete',
        builder: (_, state) => Scaffold(
          body: Text('COMPLETE ${state.pathParameters['taskId']}'),
        ),
      ),
      GoRoute(
        path: '/suggestions',
        builder: (_, _) => const Scaffold(body: Text('SUGG')),
      ),
    ],
  );
  return MaterialApp.router(theme: NinhoTheme.light(), routerConfig: router);
}

TaskListItem _mkTask({
  required String id,
  required String title,
  String? roomId,
  String? roomName,
  String? assigneeId,
  TaskDifficulty difficulty = TaskDifficulty.mamao,
  String? recurrenceRule = 'RRULE:FREQ=WEEKLY;INTERVAL=1',
  List<TaskCompletionRef> completions = const [],
}) {
  return TaskListItem(
    id: id,
    title: title,
    roomId: roomId,
    roomName: roomName,
    difficulty: difficulty,
    assigneeId: assigneeId,
    recurrenceRule: recurrenceRule,
    recentCompletions: completions,
  );
}

void main() {
  testWidgets('lista todas tasks com nome + cômodo + dificuldade', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(
        TasksScreen(
          environmentsRepository: _FakeEnvRepo(
            rooms: const [
              RoomRow(id: 'r-cozinha', name: 'Cozinha', sizeCategory: 'G'),
            ],
          ),
          tasksRepository: _FakeTasksRepo(
            tasks: [
              _mkTask(
                id: 't1',
                title: 'Lavar a louça',
                roomId: 'r-cozinha',
                roomName: 'Cozinha',
                difficulty: TaskDifficulty.mamao,
              ),
              _mkTask(
                id: 't2',
                title: 'Limpar o fogão',
                roomId: 'r-cozinha',
                roomName: 'Cozinha',
                difficulty: TaskDifficulty.treta,
              ),
            ],
          ),
          currentUserId: 'me',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // "Tarefas" aparece no header e no bottom nav.
    expect(find.text('Tarefas'), findsNWidgets(2));
    expect(find.text('Lavar a louça'), findsOneWidget);
    expect(find.text('Limpar o fogão'), findsOneWidget);
    expect(find.text('Cozinha'), findsNWidgets(2));
    expect(find.textContaining('Mamão'), findsOneWidget);
    expect(find.textContaining('Treta'), findsOneWidget);
  });

  testWidgets('filtro Minhas mantém só tasks com assignee=me', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(
        TasksScreen(
          environmentsRepository: _FakeEnvRepo(),
          tasksRepository: _FakeTasksRepo(
            tasks: [
              _mkTask(id: 't1', title: 'Minha', assigneeId: 'me'),
              _mkTask(id: 't2', title: 'Do outro', assigneeId: 'other'),
            ],
          ),
          currentUserId: 'me',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Minha'), findsOneWidget);
    expect(find.text('Do outro'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tasks_chip_mine')));
    await tester.pumpAndSettle();

    expect(find.text('Minha'), findsOneWidget);
    expect(find.text('Do outro'), findsNothing);
  });

  testWidgets('filtro Concluídas mostra tasks com completion hoje', (tester) async {
    _setMobile(tester);
    final now = DateTime.now();
    final todayCompletion = TaskCompletionRef(
      id: 'c1',
      completedAt: DateTime(now.year, now.month, now.day, 10),
      completedBy: 'me',
    );

    await tester.pumpWidget(
      _wrap(
        TasksScreen(
          environmentsRepository: _FakeEnvRepo(),
          tasksRepository: _FakeTasksRepo(
            tasks: [
              _mkTask(id: 't1', title: 'Pendente'),
              _mkTask(
                id: 't2',
                title: 'Já feita',
                completions: [todayCompletion],
              ),
            ],
          ),
          currentUserId: 'me',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.byKey(const Key('tasks_chip_completed')),
      find.byKey(const Key('tasks_chip_all')),
      const Offset(-200, 0),
    );
    await tester.tap(find.byKey(const Key('tasks_chip_completed')));
    await tester.pumpAndSettle();

    expect(find.text('Já feita'), findsOneWidget);
    expect(find.text('Pendente'), findsNothing);
  });

  testWidgets('empty state aparece quando filtro deixa lista vazia', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(
        TasksScreen(
          environmentsRepository: _FakeEnvRepo(),
          tasksRepository: _FakeTasksRepo(
            tasks: [
              _mkTask(id: 't1', title: 'Do outro', assigneeId: 'other'),
            ],
          ),
          currentUserId: 'me',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tasks_chip_mine')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tasks_empty_title')), findsOneWidget);
  });

  testWidgets('sem ninho mostra mensagem', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(
        TasksScreen(
          environmentsRepository: _FakeEnvRepo(envId: null),
          tasksRepository: _FakeTasksRepo(),
          currentUserId: 'me',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Você precisa cadastrar um ninho'),
      findsOneWidget,
    );
  });

  testWidgets('tap no card abre detalhe da task', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(
        TasksScreen(
          environmentsRepository: _FakeEnvRepo(),
          tasksRepository: _FakeTasksRepo(
            tasks: [_mkTask(id: 'abc', title: 'Click me')],
          ),
          currentUserId: 'me',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('task_card_abc')));
    await tester.pumpAndSettle();

    expect(find.text('DETAIL abc'), findsOneWidget);
  });

  testWidgets('filtro Por cômodo mantém só do cômodo escolhido', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(
        TasksScreen(
          environmentsRepository: _FakeEnvRepo(
            rooms: const [
              RoomRow(id: 'r-cozinha', name: 'Cozinha', sizeCategory: 'G'),
              RoomRow(id: 'r-sala', name: 'Sala', sizeCategory: 'M'),
            ],
          ),
          tasksRepository: _FakeTasksRepo(
            tasks: [
              _mkTask(
                id: 't1',
                title: 'Cozinha task',
                roomId: 'r-cozinha',
                roomName: 'Cozinha',
              ),
              _mkTask(
                id: 't2',
                title: 'Sala task',
                roomId: 'r-sala',
                roomName: 'Sala',
              ),
            ],
          ),
          currentUserId: 'me',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tasks_chip_room')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tasks_room_picker_r-cozinha')));
    await tester.pumpAndSettle();

    expect(find.text('Cozinha task'), findsOneWidget);
    expect(find.text('Sala task'), findsNothing);
  });

  testWidgets('CTA Sugestões na empty leva para /suggestions', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(
        TasksScreen(
          environmentsRepository: _FakeEnvRepo(),
          tasksRepository: _FakeTasksRepo(),
          currentUserId: 'me',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tasks_empty_suggestions_cta')));
    await tester.pumpAndSettle();

    expect(find.text('SUGG'), findsOneWidget);
  });
}
