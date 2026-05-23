import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import 'package:ninho/data/repositories/environments_repository.dart';
import 'package:ninho/data/repositories/shop_repository.dart';
import 'package:ninho/data/repositories/suggestions_repository.dart'
    show TaskDifficulty;
import 'package:ninho/data/repositories/tasks_repository.dart';
import 'package:ninho/data/services/room_photo_service.dart';
import 'package:ninho/domain/models/room_photo_draft.dart';
import 'package:ninho/ui/core/theme.dart';
import 'package:ninho/ui/features/shop/shop_screen.dart';
import 'package:ninho/ui/features/tasks/task_completion_screen.dart';

const _taskId = 'aaaaaaaa-0000-0000-0000-000000000001';

class _CompletionTasksRepository extends TasksRepository {
  int uploadCalls = 0;
  int completeCalls = 0;
  String? completedPhotoPath;
  RoomPhotoDraft? uploadedDraft;

  static const uploadPath =
      'eeeeeeee-0000-0000-0000-000000000001/task-completions/$_taskId/user.jpg';

  @override
  Future<String> uploadCompletionPhoto({
    required String taskId,
    required RoomPhotoDraft draft,
  }) async {
    uploadCalls += 1;
    uploadedDraft = draft;
    return uploadPath;
  }

  @override
  Future<CompleteTaskResult> completeTask({
    required String taskId,
    String? photoPath,
  }) async {
    completeCalls += 1;
    completedPhotoPath = photoPath;
    return const CompleteTaskResult(
      completionId: 'cccccccc-0000-0000-0000-000000000001',
      alreadyCompleted: false,
      rewardDelta: 15,
      notificationSuppressedCount: 1,
      feedEventId: 'dddddddd-0000-0000-0000-000000000001',
    );
  }
}

class _FakePhotoService implements RoomPhotoService {
  const _FakePhotoService(this.draft);

  final RoomPhotoDraft draft;

  @override
  Future<RoomPhotoDraft?> pickAndPrepare(RoomPhotoSource source) async => draft;
}

class _ShopEnvRepository extends EnvironmentsRepository {
  @override
  Future<String?> fetchCurrentEnvironmentId() async => 'env-release-test';
}

class _ShopTasksRepository extends TasksRepository {
  @override
  Future<List<TaskListItem>> fetchTaskList({
    required String environmentId,
  }) async {
    return [
      TaskListItem(
        id: 'task-transfer-1',
        title: 'Limpar banheiro',
        roomId: null,
        roomName: null,
        difficulty: TaskDifficulty.embacada,
        assigneeId: 'current-user',
        recurrenceRule: 'RRULE:FREQ=DAILY;INTERVAL=7',
        recentCompletions: const [],
      ),
    ];
  }
}

class _ShopRepository extends ShopRepository {
  int balance = 65;
  String? transferredTaskId;
  String? transferredToUserId;

  @override
  Future<int> fetchBalance({required String environmentId}) async => balance;

  @override
  Future<List<ShopMember>> fetchOtherMembers({
    required String environmentId,
  }) async {
    return const [ShopMember(userId: 'other-user-123456', role: 'member')];
  }

  @override
  Future<TransferResult> transferTask({
    required String taskId,
    required String toUserId,
  }) async {
    transferredTaskId = taskId;
    transferredToUserId = toUserId;
    balance -= 30;
    return TransferResult(
      transferId: 'transfer-release-test',
      taskId: taskId,
      toUserId: toUserId,
      cost: 30,
      newBalance: balance,
    );
  }
}

void _setMobile(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _wrapCompletion({
  required TasksRepository tasksRepository,
  required RoomPhotoService photoService,
}) {
  final router = GoRouter(
    initialLocation: '/tasks/$_taskId/complete',
    routes: [
      GoRoute(
        path: '/tasks/:taskId/complete',
        builder: (_, state) => TaskCompletionScreen(
          taskId: state.pathParameters['taskId']!,
          tasksRepository: tasksRepository,
          photoService: photoService,
        ),
      ),
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('HOME_READY')),
      ),
    ],
  );
  return MaterialApp.router(theme: NinhoTheme.light(), routerConfig: router);
}

Widget _wrapShop({
  required EnvironmentsRepository environmentsRepository,
  required ShopRepository shopRepository,
  required TasksRepository tasksRepository,
}) {
  final router = GoRouter(
    initialLocation: '/shop',
    routes: [
      GoRoute(
        path: '/shop',
        builder: (_, _) => ShopScreen(
          environmentsRepository: environmentsRepository,
          shopRepository: shopRepository,
          tasksRepository: tasksRepository,
          currentUserId: 'current-user',
        ),
      ),
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('HOME_READY')),
      ),
      GoRoute(
        path: '/shop/history',
        builder: (_, _) => const Scaffold(body: Text('HISTORY_READY')),
      ),
    ],
  );
  return MaterialApp.router(theme: NinhoTheme.light(), routerConfig: router);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('critical flow: task completion uploads photo then completes', (
    tester,
  ) async {
    _setMobile(tester);
    final repository = _CompletionTasksRepository();
    final draft = RoomPhotoDraft(
      bytes: Uint8List.fromList([1, 2, 3, 4]),
      contentType: 'image/jpeg',
      extension: 'jpg',
    );

    await tester.pumpWidget(
      _wrapCompletion(
        tasksRepository: repository,
        photoService: _FakePhotoService(draft),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('task_completion_photo_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Escolher da galeria'));
    await tester.pumpAndSettle();

    expect(find.text('Foto pronta para enviar'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('task_completion_finish_button')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -220));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('task_completion_finish_button')));
    await tester.pumpAndSettle();

    expect(repository.uploadCalls, 1);
    expect(repository.uploadedDraft, same(draft));
    expect(repository.completeCalls, 1);
    expect(
      repository.completedPhotoPath,
      _CompletionTasksRepository.uploadPath,
    );
    expect(find.text('HOME_READY'), findsOneWidget);
  });

  testWidgets('critical flow: shop transfers one assigned task', (
    tester,
  ) async {
    _setMobile(tester);
    final shopRepository = _ShopRepository();

    await tester.pumpWidget(
      _wrapShop(
        environmentsRepository: _ShopEnvRepository(),
        shopRepository: shopRepository,
        tasksRepository: _ShopTasksRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Loja da Poeira'), findsOneWidget);
    expect(find.text('65'), findsOneWidget);
    expect(find.text('Comprar'), findsOneWidget);

    await tester.tap(find.byKey(const Key('shop_transfer_cta')));
    await tester.pumpAndSettle();

    expect(find.text('Transferir tarefa'), findsOneWidget);
    expect(find.text('Limpar banheiro'), findsOneWidget);
    expect(find.text('Morador #other-'), findsOneWidget);

    await tester.tap(find.byKey(const Key('transfer_confirm')));
    await tester.pumpAndSettle();

    expect(shopRepository.transferredTaskId, 'task-transfer-1');
    expect(shopRepository.transferredToUserId, 'other-user-123456');
    expect(find.text('Tarefa transferida. Saldo: 35 poeiras.'), findsOneWidget);
    final balance = tester.widget<Text>(find.byKey(const Key('shop_balance')));
    expect(balance.data, '35');
  });
}
