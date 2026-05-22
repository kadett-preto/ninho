import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ninho/data/repositories/environments_repository.dart';
import 'package:ninho/data/repositories/shop_repository.dart';
import 'package:ninho/data/repositories/suggestions_repository.dart'
    show TaskDifficulty;
import 'package:ninho/data/repositories/tasks_repository.dart';
import 'package:ninho/ui/core/theme.dart';
import 'package:ninho/ui/features/shop/shop_screen.dart';

class _FakeEnvRepo extends EnvironmentsRepository {
  _FakeEnvRepo({this.envId = 'env-1'});
  final String? envId;

  @override
  Future<String?> fetchCurrentEnvironmentId() async => envId;
}

class _FakeShopRepo extends ShopRepository {
  _FakeShopRepo({
    this.balance = 0,
    this.members = const [],
    this.transferError,
  });
  int balance;
  List<ShopMember> members;
  Object? transferError;
  Map<String, dynamic>? lastTransfer;

  @override
  Future<int> fetchBalance({required String environmentId}) async => balance;

  @override
  Future<List<ShopMember>> fetchOtherMembers({
    required String environmentId,
  }) async => members;

  @override
  Future<TransferResult> transferTask({
    required String taskId,
    required String toUserId,
  }) async {
    if (transferError != null) throw transferError!;
    lastTransfer = {'task_id': taskId, 'to_user_id': toUserId};
    balance -= 30;
    return TransferResult(
      transferId: 'tr-1',
      taskId: taskId,
      toUserId: toUserId,
      cost: 30,
      newBalance: balance,
    );
  }
}

class _FakeTasksRepo extends TasksRepository {
  _FakeTasksRepo({this.items = const []});
  final List<TaskListItem> items;

  @override
  Future<List<TaskListItem>> fetchTaskList({
    required String environmentId,
  }) async => items;
}

TaskListItem _mkTask({
  required String id,
  required String title,
  String? assignee,
}) {
  return TaskListItem(
    id: id,
    title: title,
    roomId: null,
    roomName: null,
    difficulty: TaskDifficulty.mamao,
    assigneeId: assignee,
    recurrenceRule: null,
    recentCompletions: const [],
  );
}

void _setMobile(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _wrap(ShopScreen screen) {
  final router = GoRouter(
    initialLocation: '/test',
    routes: [
      GoRoute(path: '/test', builder: (_, _) => screen),
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('HOME')),
      ),
      GoRoute(
        path: '/shop/history',
        builder: (_, _) => const Scaffold(body: Text('HISTORY')),
      ),
    ],
  );
  return MaterialApp.router(theme: NinhoTheme.light(), routerConfig: router);
}

void main() {
  testWidgets('mostra saldo + item Transferência', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(
        ShopScreen(
          environmentsRepository: _FakeEnvRepo(),
          shopRepository: _FakeShopRepo(
            balance: 45,
            members: const [
              ShopMember(userId: 'bob-uuid-12345678', role: 'member'),
            ],
          ),
          tasksRepository: _FakeTasksRepo(
            items: [_mkTask(id: 't1', title: 'Limpar fogão', assignee: 'me')],
          ),
          currentUserId: 'me',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Loja da Poeira'), findsOneWidget);
    expect(find.byKey(const Key('shop_balance')), findsOneWidget);
    expect(find.text('45'), findsOneWidget);
    expect(find.text('Transferência de Tarefa'), findsOneWidget);
    expect(find.text('Comprar'), findsOneWidget);
    expect(find.byKey(const Key('shop_history_button')), findsOneWidget);
  });

  testWidgets('CTA Ver histórico navega pra /shop/history', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(
        ShopScreen(
          environmentsRepository: _FakeEnvRepo(),
          shopRepository: _FakeShopRepo(balance: 10),
          tasksRepository: _FakeTasksRepo(),
          currentUserId: 'me',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('shop_history_button')));
    await tester.pumpAndSettle();

    expect(find.text('HISTORY'), findsOneWidget);
  });

  testWidgets('saldo curto desabilita CTA', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(
        ShopScreen(
          environmentsRepository: _FakeEnvRepo(),
          shopRepository: _FakeShopRepo(
            balance: 10,
            members: const [ShopMember(userId: 'bob-12', role: 'member')],
          ),
          tasksRepository: _FakeTasksRepo(
            items: [_mkTask(id: 't1', title: 'X', assignee: 'me')],
          ),
          currentUserId: 'me',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(
      find.byKey(const Key('shop_transfer_cta')),
    );
    expect(button.onPressed, isNull);
    expect(find.text('Saldo curto'), findsOneWidget);
  });

  testWidgets('sem outros membros desabilita CTA', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(
        ShopScreen(
          environmentsRepository: _FakeEnvRepo(),
          shopRepository: _FakeShopRepo(balance: 100),
          tasksRepository: _FakeTasksRepo(
            items: [_mkTask(id: 't1', title: 'X', assignee: 'me')],
          ),
          currentUserId: 'me',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(
      find.byKey(const Key('shop_transfer_cta')),
    );
    expect(button.onPressed, isNull);
    expect(find.text('Sem outros'), findsOneWidget);
  });

  testWidgets('happy path: abre sheet + confirma transferência', (
    tester,
  ) async {
    _setMobile(tester);
    final repo = _FakeShopRepo(
      balance: 60,
      members: const [ShopMember(userId: 'bob-abcdef-12', role: 'member')],
    );
    await tester.pumpWidget(
      _wrap(
        ShopScreen(
          environmentsRepository: _FakeEnvRepo(),
          shopRepository: repo,
          tasksRepository: _FakeTasksRepo(
            items: [_mkTask(id: 't1', title: 'Faxina', assignee: 'me')],
          ),
          currentUserId: 'me',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('shop_transfer_cta')));
    await tester.pumpAndSettle();

    expect(find.text('Transferir tarefa'), findsOneWidget);
    expect(find.byKey(const Key('transfer_confirm')), findsOneWidget);

    await tester.tap(find.byKey(const Key('transfer_confirm')));
    await tester.pumpAndSettle();

    expect(repo.lastTransfer?['task_id'], 't1');
    expect(repo.lastTransfer?['to_user_id'], 'bob-abcdef-12');
    // Saldo atualizado (custo do item também aparece como "30" no badge).
    final balance = tester.widget<Text>(find.byKey(const Key('shop_balance')));
    expect(balance.data, '30');
  });

  testWidgets('erro do servidor vira mensagem humana', (tester) async {
    _setMobile(tester);
    final repo = _FakeShopRepo(
      balance: 60,
      members: const [ShopMember(userId: 'bob-2', role: 'member')],
      transferError: Exception('Você já usou sua transferência desta semana'),
    );
    await tester.pumpWidget(
      _wrap(
        ShopScreen(
          environmentsRepository: _FakeEnvRepo(),
          shopRepository: repo,
          tasksRepository: _FakeTasksRepo(
            items: [_mkTask(id: 't1', title: 'X', assignee: 'me')],
          ),
          currentUserId: 'me',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('shop_transfer_cta')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('transfer_confirm')));
    await tester.pumpAndSettle();

    expect(find.textContaining('já usou sua transferência'), findsAtLeast(1));
  });

  testWidgets('sem ninho mostra erro', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(
        ShopScreen(
          environmentsRepository: _FakeEnvRepo(envId: null),
          shopRepository: _FakeShopRepo(),
          tasksRepository: _FakeTasksRepo(),
          currentUserId: 'me',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('shop_error')), findsOneWidget);
  });
}
