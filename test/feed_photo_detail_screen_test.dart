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

  @override
  Future<FeedPhotoDetail> fetchPhotoDetail({required String eventId}) async {
    if (error != null) throw error!;
    return detail!;
  }
}

FeedPhotoDetail _detail() {
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
    await tester.pumpWidget(_wrap(_FakeFeedRepo(detail: _detail())));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('feed_photo_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Denunciar'));
    await tester.pumpAndSettle();

    expect(find.text('Sinal registrado.'), findsOneWidget);
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
