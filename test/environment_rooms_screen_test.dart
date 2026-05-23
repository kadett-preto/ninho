import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ninho/data/repositories/environments_repository.dart';
import 'package:ninho/ui/core/theme.dart';
import 'package:ninho/ui/features/profile/environment_rooms_screen.dart';

class _FakeRepo extends EnvironmentsRepository {
  _FakeRepo({
    this.envId = 'env-1',
    this.role = 'owner',
    this.rooms = const [],
  });
  final String? envId;
  final String role;
  final List<RoomRow> rooms;

  RoomRow? lastCreated;
  String? lastUpdatedId;
  String? lastDeletedId;
  int createCalls = 0;
  int updateCalls = 0;
  int deleteCalls = 0;

  @override
  Future<String?> fetchCurrentEnvironmentId() async => envId;

  @override
  Future<EnvironmentSummary?> fetchEnvironmentSummary({
    required String environmentId,
  }) async =>
      EnvironmentSummary(
        id: environmentId,
        name: 'Lar',
        ownerId: role == 'owner' ? 'me' : 'other',
        role: role,
        createdAt: DateTime(2026, 1, 1),
      );

  @override
  Future<List<RoomRow>> fetchRooms(String environmentId) async => rooms;

  @override
  Future<RoomRow> createRoom({
    required String environmentId,
    required String name,
    required String sizeCategory,
  }) async {
    createCalls++;
    lastCreated = RoomRow(
      id: 'r-$createCalls',
      name: name.trim(),
      sizeCategory: sizeCategory.toUpperCase(),
    );
    return lastCreated!;
  }

  @override
  Future<void> updateRoom({
    required String roomId,
    String? name,
    String? sizeCategory,
  }) async {
    updateCalls++;
    lastUpdatedId = roomId;
  }

  @override
  Future<void> deleteRoom(String roomId) async {
    deleteCalls++;
    lastDeletedId = roomId;
  }
}

void _setMobile(WidgetTester tester) {
  tester.view.physicalSize = const Size(420, 1100);
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

  testWidgets('member regular não vê CTA adicionar', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(EnvironmentRoomsScreen(
        environmentsRepository: _FakeRepo(role: 'member'),
      )),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('rooms_add')), findsNothing);
  });

  testWidgets('owner adiciona cômodo via sheet', (tester) async {
    _setMobile(tester);
    final repo = _FakeRepo();
    await tester.pumpWidget(
      _wrap(EnvironmentRoomsScreen(environmentsRepository: repo)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('rooms_add')));
    await tester.pumpAndSettle();

    expect(find.text('Novo cômodo'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('room_form_name')),
      'Lavanderia',
    );
    await tester.tap(find.byKey(const Key('room_size_G')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('room_form_save')));
    await tester.pumpAndSettle();

    expect(repo.createCalls, 1);
    expect(repo.lastCreated?.name, 'Lavanderia');
    expect(repo.lastCreated?.sizeCategory, 'G');
    expect(find.text('Lavanderia'), findsOneWidget);
  });

  testWidgets('owner edita cômodo (tap row → sheet edit)', (tester) async {
    _setMobile(tester);
    final repo = _FakeRepo(rooms: const [
      RoomRow(id: 'r1', name: 'Cozinha', sizeCategory: 'M'),
    ]);
    await tester.pumpWidget(
      _wrap(EnvironmentRoomsScreen(environmentsRepository: repo)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('room_r1')));
    await tester.pumpAndSettle();

    expect(find.text('Editar cômodo'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('room_form_name')),
      'Cozinha Nova',
    );
    await tester.tap(find.byKey(const Key('room_form_save')));
    await tester.pumpAndSettle();

    expect(repo.updateCalls, 1);
    expect(repo.lastUpdatedId, 'r1');
    expect(find.text('Cozinha Nova'), findsOneWidget);
  });

  testWidgets('owner deleta cômodo via sheet + confirm', (tester) async {
    _setMobile(tester);
    final repo = _FakeRepo(rooms: const [
      RoomRow(id: 'r1', name: 'Cozinha', sizeCategory: 'M'),
    ]);
    await tester.pumpWidget(
      _wrap(EnvironmentRoomsScreen(environmentsRepository: repo)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('room_r1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('room_form_delete')));
    await tester.pumpAndSettle();

    expect(find.text('Excluir cômodo?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('room_delete_confirm')));
    await tester.pumpAndSettle();

    expect(repo.deleteCalls, 1);
    expect(repo.lastDeletedId, 'r1');
    expect(find.text('Cozinha'), findsNothing);
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
