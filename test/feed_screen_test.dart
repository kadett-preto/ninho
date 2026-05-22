import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ninho/data/repositories/environments_repository.dart';
import 'package:ninho/data/repositories/feed_repository.dart';
import 'package:ninho/data/repositories/suggestions_repository.dart'
    show TaskDifficulty;
import 'package:ninho/ui/core/theme.dart';
import 'package:ninho/ui/features/feed/feed_screen.dart';

class _FakeEnvRepo extends EnvironmentsRepository {
  _FakeEnvRepo({this.envId = 'env-1'});
  final String? envId;

  @override
  Future<String?> fetchCurrentEnvironmentId() async => envId;
}

class _FakeFeedRepo extends FeedRepository {
  _FakeFeedRepo({
    this.environmentName = 'Ninho da Marina',
    this.items = const [],
    this.error,
  });

  final String environmentName;
  final List<FeedTimelineItem> items;
  final Object? error;

  @override
  Future<String> fetchEnvironmentName({required String environmentId}) async {
    if (error != null) throw error!;
    return environmentName;
  }

  @override
  Future<List<FeedTimelineItem>> fetchTimeline({
    required String environmentId,
    int limit = 30,
  }) async {
    if (error != null) throw error!;
    return items;
  }
}

FeedTimelineItem _item({
  required String id,
  required String eventType,
  String? title,
  String? photoUrl,
  TaskDifficulty? difficulty,
  String? summary,
  String? memberName,
  int? streakCount,
}) {
  return FeedTimelineItem(
    id: id,
    eventType: eventType,
    actorId: 'user-1',
    actorLabel: 'Marina',
    createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    title: title,
    caption: 'Cozinha brilhando!',
    difficulty: difficulty,
    photoUrl: photoUrl,
    heartCount: 2,
    celebrationCount: 1,
    summary: summary,
    memberName: memberName,
    streakCount: streakCount,
  );
}

void _setMobile(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _wrap({
  required EnvironmentsRepository envRepo,
  required FeedRepository feedRepo,
}) {
  final router = GoRouter(
    initialLocation: '/feed',
    routes: [
      GoRoute(
        path: '/feed',
        builder: (_, _) =>
            FeedScreen(environmentsRepository: envRepo, repository: feedRepo),
      ),
      GoRoute(
        path: '/feed/:eventId',
        builder: (_, state) =>
            Scaffold(body: Text('DETAIL ${state.pathParameters['eventId']}')),
      ),
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('HOME')),
      ),
      GoRoute(
        path: '/tasks',
        builder: (_, _) => const Scaffold(body: Text('TASKS')),
      ),
      GoRoute(
        path: '/shop',
        builder: (_, _) => const Scaffold(body: Text('SHOP')),
      ),
    ],
  );
  return MaterialApp.router(theme: NinhoTheme.light(), routerConfig: router);
}

void main() {
  testWidgets('renderiza timeline do mural', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(
        envRepo: _FakeEnvRepo(envId: 'env-1'),
        feedRepo: _FakeFeedRepo(
          environmentName: 'Ninho da Marina',
          items: [
            _item(
              id: 'done-1',
              eventType: 'task.completed',
              title: 'Aspirar a sala',
              difficulty: TaskDifficulty.embacada,
            ),
            _item(
              id: 'summary-1',
              eventType: 'weekly.summary',
              summary: 'Vocês concluíram 85% das tarefas planejadas.',
            ),
            _item(
              id: 'member-1',
              eventType: 'member.joined',
              memberName: 'João',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('mural'), findsOneWidget);
    expect(find.text('Ninho da Marina'), findsOneWidget);
    expect(find.textContaining('Aspirar a sala'), findsOneWidget);
    expect(find.text('Embaçada'), findsOneWidget);
    expect(find.text('Resumo da semana'), findsOneWidget);
    expect(find.textContaining('85%'), findsOneWidget);
    expect(find.textContaining('João entrou no ninho'), findsOneWidget);
  });

  testWidgets('tap em card com foto abre detalhe', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(
        envRepo: _FakeEnvRepo(),
        feedRepo: _FakeFeedRepo(
          items: [
            _item(
              id: 'photo-1',
              eventType: 'task.completed',
              photoUrl: 'https://example.invalid/photo.jpg',
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('feed_photo_card_photo-1')));
    await tester.pumpAndSettle();

    expect(find.text('DETAIL photo-1'), findsOneWidget);
  });

  testWidgets('mural vazio mostra empty state', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(envRepo: _FakeEnvRepo(), feedRepo: _FakeFeedRepo()),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('feed_empty')), findsOneWidget);
  });

  testWidgets('erro de load mostra mensagem', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(
        envRepo: _FakeEnvRepo(),
        feedRepo: _FakeFeedRepo(error: Exception('boom')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('feed_error')), findsOneWidget);
    expect(
      find.text('Não foi possível carregar o mural agora.'),
      findsOneWidget,
    );
  });
}
