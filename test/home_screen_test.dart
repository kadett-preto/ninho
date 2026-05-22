import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ninho/data/repositories/environments_repository.dart';
import 'package:ninho/data/repositories/shop_repository.dart';
import 'package:ninho/data/repositories/streaks_repository.dart';
import 'package:ninho/data/repositories/suggestions_repository.dart'
    show TaskDifficulty;
import 'package:ninho/data/repositories/tasks_repository.dart';
import 'package:ninho/ui/core/theme.dart';
import 'package:ninho/ui/features/home/home_screen.dart';

class _FakeEnvRepo extends EnvironmentsRepository {
  _FakeEnvRepo({this.envId = 'env-1', this.delay});
  final String? envId;
  final Duration? delay;

  @override
  Future<String?> fetchCurrentEnvironmentId() async {
    if (delay != null) await Future<void>.delayed(delay!);
    return envId;
  }
}

class _FakeTasksRepo extends TasksRepository {
  _FakeTasksRepo({this.items = const [], this.error});
  final List<TaskListItem> items;
  final Object? error;

  @override
  Future<List<TaskListItem>> fetchTaskList({
    required String environmentId,
  }) async {
    if (error != null) throw error!;
    return items;
  }
}

class _FakeStreaksRepo extends StreaksRepository {
  const _FakeStreaksRepo({this.summary});
  final StreakSummary? summary;

  @override
  Future<StreakSummary> fetchSummary({required String environmentId}) async {
    return summary ??
        const StreakSummary(
          userCount: 0,
          environmentCount: 0,
          freezesLeftMonth: 2,
        );
  }
}

class _FakeShopRepo extends ShopRepository {
  const _FakeShopRepo({this.balance = 0});
  final int balance;

  @override
  Future<int> fetchBalance({required String environmentId}) async {
    return balance;
  }
}

TaskListItem _task({
  required String id,
  required String title,
  String? room,
  TaskDifficulty difficulty = TaskDifficulty.mamao,
  String assigneeId = 'me',
  DateTime? startDate,
  String? recurrenceRule,
}) {
  return TaskListItem(
    id: id,
    title: title,
    roomId: 'room-$id',
    roomName: room,
    difficulty: difficulty,
    assigneeId: assigneeId,
    recurrenceRule: recurrenceRule,
    startDate: startDate ?? DateTime.now(),
    recentCompletions: const [],
  );
}

void _setMobile(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _wrap({
  required EnvironmentsRepository env,
  required TasksRepository tasks,
  StreaksRepository? streaks,
  ShopRepository? shop,
  String? currentUserId = 'me',
}) {
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (_, _) => HomeScreen(
          environmentsRepository: env,
          tasksRepository: tasks,
          streaksRepository: streaks,
          shopRepository: shop,
          currentUserId: currentUserId,
        ),
      ),
      GoRoute(
        path: '/tasks/:taskId',
        builder: (_, state) =>
            Scaffold(body: Text('DETAIL ${state.pathParameters['taskId']}')),
      ),
      GoRoute(
        path: '/tasks/:taskId/complete',
        builder: (_, state) =>
            Scaffold(body: Text('COMPLETE ${state.pathParameters['taskId']}')),
      ),
      GoRoute(
        path: '/setup/step1',
        builder: (_, _) => const Scaffold(body: Text('SETUP1')),
      ),
    ],
  );
  return MaterialApp.router(theme: NinhoTheme.light(), routerConfig: router);
}

void main() {
  testWidgets('loading state shows spinner antes do load completar', (
    tester,
  ) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(
        env: _FakeEnvRepo(delay: const Duration(milliseconds: 200)),
        tasks: _FakeTasksRepo(),
        streaks: const _FakeStreaksRepo(),
        shop: const _FakeShopRepo(),
      ),
    );
    await tester.pump(); // primeira frame, ainda carregando
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('sem ninho mostra CTA Criar meu ninho', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(
        env: _FakeEnvRepo(envId: null),
        tasks: _FakeTasksRepo(),
        streaks: const _FakeStreaksRepo(),
        shop: const _FakeShopRepo(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home_no_env')), findsOneWidget);
    expect(find.text('Criar meu ninho'), findsOneWidget);
  });

  testWidgets('estado ready com 3 tarefas mostra cards + stats', (
    tester,
  ) async {
    _setMobile(tester);
    final tasksList = [
      _task(id: 'a', title: 'Lavar a louça', room: 'Cozinha'),
      _task(
        id: 'b',
        title: 'Varrer a sala',
        room: 'Sala',
        difficulty: TaskDifficulty.embacada,
      ),
      _task(
        id: 'c',
        title: 'Limpar o banheiro',
        room: 'Banheiro',
        difficulty: TaskDifficulty.treta,
      ),
    ];
    await tester.pumpWidget(
      _wrap(
        env: _FakeEnvRepo(),
        tasks: _FakeTasksRepo(items: tasksList),
        streaks: const _FakeStreaksRepo(
          summary: StreakSummary(
            userCount: 7,
            environmentCount: 12,
            freezesLeftMonth: 2,
          ),
        ),
        shop: const _FakeShopRepo(balance: 145),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tarefas de hoje'), findsOneWidget);
    expect(find.text('Lavar a louça'), findsOneWidget);
    expect(find.text('Varrer a sala'), findsOneWidget);
    expect(find.text('Limpar o banheiro'), findsOneWidget);
    expect(find.byKey(const Key('home_stat_env_streak')), findsOneWidget);
    expect(find.byKey(const Key('home_stat_user_streak')), findsOneWidget);
    expect(find.text('12 dias'), findsOneWidget);
    expect(find.text('7 dias'), findsOneWidget);
    expect(find.text('145'), findsOneWidget);
  });

  testWidgets('ninho sem tarefas pra hoje mostra empty acolhedor', (
    tester,
  ) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(
        env: _FakeEnvRepo(),
        tasks: _FakeTasksRepo(),
        streaks: const _FakeStreaksRepo(),
        shop: const _FakeShopRepo(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home_tasks_empty')), findsOneWidget);
    expect(find.textContaining('descanso'), findsOneWidget);
  });

  testWidgets('tap em task card navega pra detail', (tester) async {
    _setMobile(tester);
    final t = _task(id: 'xyz', title: 'Aspirar', room: 'Sala');
    await tester.pumpWidget(
      _wrap(
        env: _FakeEnvRepo(),
        tasks: _FakeTasksRepo(items: [t]),
        streaks: const _FakeStreaksRepo(),
        shop: const _FakeShopRepo(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home_task_card_xyz')));
    await tester.pumpAndSettle();

    expect(find.text('DETAIL xyz'), findsOneWidget);
  });

  testWidgets('check button navega pra completion', (tester) async {
    _setMobile(tester);
    final t = _task(id: 'xyz', title: 'Aspirar');
    await tester.pumpWidget(
      _wrap(
        env: _FakeEnvRepo(),
        tasks: _FakeTasksRepo(items: [t]),
        streaks: const _FakeStreaksRepo(),
        shop: const _FakeShopRepo(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home_task_check_xyz')));
    await tester.pumpAndSettle();

    expect(find.text('COMPLETE xyz'), findsOneWidget);
  });

  testWidgets('erro mostra mensagem + retry', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(
        env: _FakeEnvRepo(),
        tasks: _FakeTasksRepo(error: Exception('boom')),
        streaks: const _FakeStreaksRepo(),
        shop: const _FakeShopRepo(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home_error')), findsOneWidget);
    expect(find.byKey(const Key('home_retry')), findsOneWidget);
  });

  testWidgets(
    'filtro hoje exclui task de outro morador',
    (tester) async {
      _setMobile(tester);
      final tasksList = [
        _task(id: 'mine', title: 'Tirar o lixo', assigneeId: 'me'),
        _task(id: 'theirs', title: 'Passar pano', assigneeId: 'other'),
      ];
      await tester.pumpWidget(
        _wrap(
          env: _FakeEnvRepo(),
          tasks: _FakeTasksRepo(items: tasksList),
          streaks: const _FakeStreaksRepo(),
          shop: const _FakeShopRepo(),
        ),
      );
      await tester.pumpAndSettle();

      // currentUserId='me' (default do _wrap). Só tarefa da pessoa aparece.
      expect(find.text('Tirar o lixo'), findsOneWidget);
      expect(find.text('Passar pano'), findsNothing);
    },
  );
}
