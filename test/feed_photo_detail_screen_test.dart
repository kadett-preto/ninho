import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ninho/data/repositories/feed_repository.dart';
import 'package:ninho/data/repositories/suggestions_repository.dart'
    show TaskDifficulty;
import 'package:ninho/ui/core/theme.dart';
import 'package:ninho/ui/features/feed/feed_photo_detail_screen.dart';

class _FakeFeedRepo extends FeedRepository {
  _FakeFeedRepo({this.detail, this.error});

  final FeedPhotoDetail? detail;
  final Object? error;
  int reportCalls = 0;
  final List<FeedModerationAction> moderationCalls = [];

  @override
  Future<FeedPhotoDetail> fetchPhotoDetail({required String eventId}) async {
    if (error != null) throw error!;
    return detail!;
  }

  @override
  Future<void> reportFeedEvent({
    required String eventId,
    String reason = 'inappropriate',
    String? details,
  }) async {
    reportCalls += 1;
  }

  @override
  Future<void> moderateFeedEvent({
    required String eventId,
    required FeedModerationAction action,
    String? reason,
  }) async {
    moderationCalls.add(action);
  }
}

FeedPhotoDetail _detail({
  bool canReport = true,
  bool canDeletePhoto = false,
  bool canModerate = false,
}) {
  return FeedPhotoDetail(
    eventId: 'event-1',
    taskId: 'task-1',
    completionId: 'completion-1',
    actorId: 'user-1',
    actorLabel: 'Marina',
    createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    photoUrl: null,
    caption: 'Cozinha brilhando!',
    taskTitle: 'Limpeza pesada',
    roomName: 'Cozinha',
    difficulty: TaskDifficulty.treta,
    heartCount: 12,
    celebrationCount: 5,
    canReport: canReport,
    canDeletePhoto: canDeletePhoto,
    canModerate: canModerate,
    comments: [
      FeedComment(
        authorLabel: 'Lucas',
        body: 'Ficou ótimo!',
        createdAt: DateTime.now().subtract(const Duration(minutes: 20)),
      ),
    ],
  );
}

void _setMobile(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _wrap(FeedRepository repo) {
  final router = GoRouter(
    initialLocation: '/feed/event-1',
    routes: [
      GoRoute(
        path: '/feed/:eventId',
        builder: (_, state) => FeedPhotoDetailScreen(
          eventId: state.pathParameters['eventId']!,
          repository: repo,
        ),
      ),
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('HOME')),
      ),
      GoRoute(
        path: '/feed',
        builder: (_, _) => const Scaffold(body: Text('FEED')),
      ),
    ],
  );
  return MaterialApp.router(theme: NinhoTheme.light(), routerConfig: router);
}

void main() {
  testWidgets('renderiza detalhe da foto do mural', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(_wrap(_FakeFeedRepo(detail: _detail())));
    await tester.pumpAndSettle();

    expect(find.text('mural'), findsOneWidget);
    expect(find.byKey(const Key('feed_photo_caption')), findsOneWidget);
    expect(find.text('Cozinha brilhando!'), findsOneWidget);
    expect(find.text('Marina'), findsOneWidget);
    expect(find.text('Limpeza pesada'), findsOneWidget);
    expect(find.text('Treta'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('Lucas'), findsOneWidget);
    expect(find.text('Ficou ótimo!'), findsOneWidget);
    expect(find.byKey(const Key('feed_comment_input')), findsOneWidget);
  });

  testWidgets('menu permite sinalizar denúncia', (tester) async {
    _setMobile(tester);
    final repo = _FakeFeedRepo(detail: _detail());
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('feed_photo_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Denunciar'));
    await tester.pumpAndSettle();

    expect(find.text('Sinal registrado.'), findsOneWidget);
    expect(repo.reportCalls, 1);
  });

  testWidgets('autor consegue remover a própria foto', (tester) async {
    _setMobile(tester);
    final repo = _FakeFeedRepo(detail: _detail(canDeletePhoto: true));
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('feed_photo_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remover minha foto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remover'));
    await tester.pumpAndSettle();

    expect(repo.moderationCalls, [FeedModerationAction.deletePhoto]);
    expect(find.text('FEED'), findsOneWidget);
  });

  testWidgets('owner consegue ocultar item do mural', (tester) async {
    _setMobile(tester);
    final repo = _FakeFeedRepo(detail: _detail(canModerate: true));
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('feed_photo_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ocultar do mural'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ocultar'));
    await tester.pumpAndSettle();

    expect(repo.moderationCalls, [FeedModerationAction.hide]);
    expect(find.text('FEED'), findsOneWidget);
  });

  testWidgets('erro de load mostra mensagem humana', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(_wrap(_FakeFeedRepo(error: Exception('boom'))));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('feed_photo_error')), findsOneWidget);
    expect(
      find.text('Não foi possível abrir esta foto do mural.'),
      findsOneWidget,
    );
  });
}
