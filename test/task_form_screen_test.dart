import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ninho/data/repositories/environments_repository.dart';
import 'package:ninho/data/repositories/suggestions_repository.dart'
    show TaskDifficulty;
import 'package:ninho/data/repositories/tasks_repository.dart';
import 'package:ninho/ui/core/theme.dart';
import 'package:ninho/ui/features/tasks/task_form_screen.dart';

class _FakeEnvRepo extends EnvironmentsRepository {
  _FakeEnvRepo({this.rooms = const []});
  final List<RoomRow> rooms;

  @override
  Future<String?> fetchCurrentEnvironmentId() async => 'env-1';

  @override
  Future<List<RoomRow>> fetchRooms(String environmentId) async => rooms;
}

class _FakeTasksRepo extends TasksRepository {
  _FakeTasksRepo({this.existingTask});
  final TaskListItem? existingTask;

  Map<String, dynamic>? lastCreate;
  Map<String, dynamic>? lastUpdate;
  String? archivedId;

  @override
  Future<TaskListItem> fetchTask({required String taskId}) async {
    final t = existingTask;
    if (t == null) throw StateError('Tarefa não encontrada');
    return t;
  }

  @override
  Future<String> createTask({
    required String environmentId,
    required String title,
    required TaskDifficulty difficulty,
    required DateTime startDate,
    String? description,
    String? roomId,
    String? assigneeId,
    String? recurrenceRule,
  }) async {
    lastCreate = {
      'environment_id': environmentId,
      'title': title,
      'difficulty': difficulty.wire,
      'start_date': startDate.toIso8601String(),
      'description': description,
      'room_id': roomId,
      'assignee_id': assigneeId,
      'recurrence_rule': recurrenceRule,
    };
    return 'new-task-id';
  }

  @override
  Future<void> updateTask({
    required String taskId,
    String? title,
    TaskDifficulty? difficulty,
    DateTime? startDate,
    String? description,
    String? roomId,
    String? assigneeId,
    String? recurrenceRule,
    bool clearAssignee = false,
    bool clearRoom = false,
    bool clearRecurrence = false,
    bool clearDescription = false,
  }) async {
    lastUpdate = {
      'task_id': taskId,
      'title': title,
      'difficulty': difficulty?.wire,
      'room_id': roomId,
      'assignee_id': assigneeId,
      'recurrence_rule': recurrenceRule,
      'clear_assignee': clearAssignee,
      'clear_room': clearRoom,
    };
  }

  @override
  Future<void> archiveTask({required String taskId}) async {
    archivedId = taskId;
  }
}

void _setMobile(WidgetTester tester) {
  // Viewport alto + DPR=1 para garantir que o ListView renderize todos
  // os campos do formulário (lazy build esconde itens fora da tela).
  tester.view.physicalSize = const Size(400, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _wrap(TaskFormScreen screen) {
  final router = GoRouter(
    initialLocation: '/test',
    routes: [
      GoRoute(path: '/test', builder: (_, _) => screen),
      GoRoute(
        path: '/tasks',
        builder: (_, _) => const Scaffold(body: Text('TASKS_LIST')),
      ),
      GoRoute(
        path: '/suggestions',
        builder: (_, _) => const Scaffold(body: Text('SUGG')),
      ),
    ],
  );
  return MaterialApp.router(theme: NinhoTheme.light(), routerConfig: router);
}

TaskListItem _existing() => TaskListItem(
  id: 'task-1',
  title: 'Lavar a louça',
  roomId: 'r-cozinha',
  roomName: 'Cozinha',
  difficulty: TaskDifficulty.embacada,
  assigneeId: 'me',
  recurrenceRule: 'RRULE:FREQ=DAILY;INTERVAL=7',
  recentCompletions: const [],
);

void main() {
  testWidgets('create: renderiza Nova tarefa + form vazio', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(
        TaskFormScreen(
          environmentsRepository: _FakeEnvRepo(
            rooms: const [
              RoomRow(id: 'r-cozinha', name: 'Cozinha', sizeCategory: 'G'),
            ],
          ),
          tasksRepository: _FakeTasksRepo(),
          currentUserId: 'me',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nova tarefa'), findsOneWidget);
    expect(find.byKey(const Key('task_form_title')), findsOneWidget);
    expect(find.text('Salvar tarefa'), findsOneWidget);
    expect(find.text('Criar manualmente'), findsOneWidget);
    expect(find.byKey(const Key('task_form_archive')), findsNothing);
  });

  testWidgets('create: submit envia para repo + navega', (tester) async {
    _setMobile(tester);
    final repo = _FakeTasksRepo();
    await tester.pumpWidget(
      _wrap(
        TaskFormScreen(
          environmentsRepository: _FakeEnvRepo(
            rooms: const [
              RoomRow(id: 'r-cozinha', name: 'Cozinha', sizeCategory: 'G'),
            ],
          ),
          tasksRepository: repo,
          currentUserId: 'me',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('task_form_title')),
      'Limpar fogão',
    );
    await tester.tap(find.byKey(const Key('task_form_difficulty_treta')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('task_form_recurrence_weekly')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('task_form_submit')));
    await tester.pumpAndSettle();

    expect(repo.lastCreate, isNotNull);
    expect(repo.lastCreate!['title'], 'Limpar fogão');
    expect(repo.lastCreate!['difficulty'], 'treta');
    expect(repo.lastCreate!['room_id'], 'r-cozinha');
    expect(repo.lastCreate!['assignee_id'], 'me');
    expect(repo.lastCreate!['recurrence_rule'], 'RRULE:FREQ=DAILY;INTERVAL=7');
    expect(find.text('TASKS_LIST'), findsOneWidget);
  });

  testWidgets('create: título vazio bloqueia submit', (tester) async {
    _setMobile(tester);
    final repo = _FakeTasksRepo();
    await tester.pumpWidget(
      _wrap(
        TaskFormScreen(
          environmentsRepository: _FakeEnvRepo(),
          tasksRepository: repo,
          currentUserId: 'me',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('task_form_submit')));
    await tester.pumpAndSettle();

    expect(repo.lastCreate, isNull);
    expect(find.textContaining('Informe um título'), findsWidgets);
  });

  testWidgets('edit: carrega dados existentes', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(
        TaskFormScreen(
          taskId: 'task-1',
          environmentsRepository: _FakeEnvRepo(
            rooms: const [
              RoomRow(id: 'r-cozinha', name: 'Cozinha', sizeCategory: 'G'),
            ],
          ),
          tasksRepository: _FakeTasksRepo(existingTask: _existing()),
          currentUserId: 'me',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Editar tarefa'), findsOneWidget);
    expect(find.text('Salvar alterações'), findsOneWidget);
    expect(find.byKey(const Key('task_form_archive')), findsOneWidget);
    expect(find.text('Criar manualmente'), findsNothing);
    // Title precarregado
    final field = tester.widget<TextField>(
      find.byKey(const Key('task_form_title')),
    );
    expect(field.controller?.text, 'Lavar a louça');
  });

  testWidgets('edit: muda dificuldade + salva chama updateTask', (
    tester,
  ) async {
    _setMobile(tester);
    final repo = _FakeTasksRepo(existingTask: _existing());
    await tester.pumpWidget(
      _wrap(
        TaskFormScreen(
          taskId: 'task-1',
          environmentsRepository: _FakeEnvRepo(
            rooms: const [
              RoomRow(id: 'r-cozinha', name: 'Cozinha', sizeCategory: 'G'),
            ],
          ),
          tasksRepository: repo,
          currentUserId: 'me',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('task_form_difficulty_mamao')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('task_form_submit')));
    await tester.pumpAndSettle();

    expect(repo.lastUpdate, isNotNull);
    expect(repo.lastUpdate!['task_id'], 'task-1');
    expect(repo.lastUpdate!['difficulty'], 'mamao');
    expect(find.text('TASKS_LIST'), findsOneWidget);
  });

  testWidgets('edit: archive flow chama archiveTask + navega', (tester) async {
    _setMobile(tester);
    final repo = _FakeTasksRepo(existingTask: _existing());
    await tester.pumpWidget(
      _wrap(
        TaskFormScreen(
          taskId: 'task-1',
          environmentsRepository: _FakeEnvRepo(),
          tasksRepository: repo,
          currentUserId: 'me',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('task_form_archive')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('task_form_archive')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('task_form_archive_confirm')));
    await tester.pumpAndSettle();

    expect(repo.archivedId, 'task-1');
    expect(find.text('TASKS_LIST'), findsOneWidget);
  });

  testWidgets('toggle responsável remove e re-adiciona', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(
        TaskFormScreen(
          environmentsRepository: _FakeEnvRepo(),
          tasksRepository: _FakeTasksRepo(),
          currentUserId: 'me',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Eu'), findsOneWidget);
    await tester.tap(find.byKey(const Key('task_form_toggle_assignee')));
    await tester.pumpAndSettle();
    expect(find.text('Sem responsável'), findsOneWidget);
    await tester.tap(find.byKey(const Key('task_form_toggle_assignee')));
    await tester.pumpAndSettle();
    expect(find.text('Eu'), findsOneWidget);
  });

  testWidgets('card "Gerar com IA" leva pra /suggestions', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(
        TaskFormScreen(
          environmentsRepository: _FakeEnvRepo(),
          tasksRepository: _FakeTasksRepo(),
          currentUserId: 'me',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('task_form_use_ia')));
    await tester.pumpAndSettle();

    expect(find.text('SUGG'), findsOneWidget);
  });
}
