import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ninho/data/repositories/environments_repository.dart';
import 'package:ninho/ui/core/theme.dart';
import 'package:ninho/ui/features/profile/environment_rooms_screen.dart';

class _FakeRepo extends EnvironmentsRepository {
  _FakeRepo({this.envId = 'env-1', this.rooms = const []});
  final String? envId;
  final List<RoomRow> rooms;

  @override
  Future<String?> fetchCurrentEnvironmentId() async => envId;

  @override
  Future<List<RoomRow>> fetchRooms(String environmentId) async => rooms;
}

void _setMobile(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _wrap(EnvironmentRoomsScreen screen) {
  final router = GoRouter(
    initialLocation: '/profile/environment/rooms',
    routes: [
      GoRoute(
        path: '/profile/environment/rooms',
        builder: (_, _) => screen,
      ),
      GoRoute(
        path: '/profile/environment',
        builder: (_, _) => const Scaffold(body: Text('SETTINGS')),
      ),
    ],
  );
  return MaterialApp.router(theme: NinhoTheme.light(), routerConfig: router);
}

void main() {
  testWidgets('ready: lista cômodos', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(EnvironmentRoomsScreen(
        environmentsRepository: _FakeRepo(rooms: const [
          RoomRow(id: 'r1', name: 'Cozinha', sizeCategory: 'M'),
          RoomRow(id: 'r2', name: 'Sala', sizeCategory: 'G'),
        ]),
      )),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cozinha'), findsOneWidget);
    expect(find.text('Sala'), findsOneWidget);
    expect(find.text('Médio'), findsOneWidget);
    expect(find.text('Grande'), findsOneWidget);
  });

  testWidgets('empty: mensagem', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(EnvironmentRoomsScreen(environmentsRepository: _FakeRepo())),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('rooms_empty')), findsOneWidget);
  });

  testWidgets('adicionar mostra Em breve', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(EnvironmentRoomsScreen(environmentsRepository: _FakeRepo())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('rooms_add')));
    await tester.pump();

    expect(find.textContaining('Em breve'), findsOneWidget);
  });

  testWidgets('sem ninho mostra retry', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(EnvironmentRoomsScreen(
        environmentsRepository: _FakeRepo(envId: null),
      )),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('rooms_error')), findsOneWidget);
    expect(find.byKey(const Key('rooms_retry')), findsOneWidget);
  });
}
