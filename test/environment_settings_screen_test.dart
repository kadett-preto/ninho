import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ninho/data/repositories/environments_repository.dart';
import 'package:ninho/data/repositories/shop_repository.dart';
import 'package:ninho/ui/core/theme.dart';
import 'package:ninho/ui/features/profile/environment_settings_screen.dart';

class _FakeEnvRepo extends EnvironmentsRepository {
  _FakeEnvRepo({
    this.envId = 'env-1',
    this.role = 'owner',
    this.flags = const EnvironmentFlags(
      transferItemEnabled: true,
      vacationMode: false,
    ),
    this.rooms = const [],
    this.members = const [],
    this.renameError,
    this.vacationError,
  });

  final String? envId;
  final String role;
  EnvironmentFlags flags;
  final List<RoomRow> rooms;
  final List<EnvironmentMember> members;
  final Object? renameError;
  final Object? vacationError;

  String? lastName;
  bool? lastVacation;

  @override
  Future<String?> fetchCurrentEnvironmentId() async => envId;

  @override
  Future<EnvironmentSummary?> fetchEnvironmentSummary({
    required String environmentId,
  }) async {
    return EnvironmentSummary(
      id: environmentId,
      name: 'Lar Atual',
      ownerId: role == 'owner' ? 'self' : 'other',
      role: role,
      createdAt: DateTime(2026, 1, 1),
    );
  }

  @override
  Future<EnvironmentFlags> fetchFlags(String environmentId) async => flags;

  @override
  Future<List<RoomRow>> fetchRooms(String environmentId) async => rooms;

  @override
  Future<List<EnvironmentMember>> listMembers(String environmentId) async =>
      members;

  @override
  Future<void> updateName({
    required String environmentId,
    required String name,
  }) async {
    if (renameError != null) throw renameError!;
    lastName = name;
  }

  @override
  Future<void> startVacation(String environmentId) async {
    if (vacationError != null) throw vacationError!;
    lastVacation = true;
  }

  @override
  Future<void> endVacation(String environmentId) async {
    if (vacationError != null) throw vacationError!;
    lastVacation = false;
  }
}

class _FakeShopRepo extends ShopRepository {
  const _FakeShopRepo({this.toggleResult = true});
  final bool toggleResult;

  @override
  Future<bool> setTransferItemEnabled({
    required String environmentId,
    required bool enabled,
  }) async {
    return toggleResult;
  }
}

void _setMobile(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 1100);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _wrap(EnvironmentSettingsScreen screen) {
  final router = GoRouter(
    initialLocation: '/profile/environment',
    routes: [
      GoRoute(path: '/profile/environment', builder: (_, _) => screen),
      GoRoute(
        path: '/profile',
        builder: (_, _) => const Scaffold(body: Text('PROFILE')),
      ),
      GoRoute(
        path: '/profile/environment/members',
        builder: (_, _) => const Scaffold(body: Text('MEMBERS')),
      ),
      GoRoute(
        path: '/profile/environment/rooms',
        builder: (_, _) => const Scaffold(body: Text('ROOMS')),
      ),
      GoRoute(
        path: '/profile/transfer-ownership',
        builder: (_, _) => const Scaffold(body: Text('TRANSFER')),
      ),
      GoRoute(
        path: '/settings/notifications',
        builder: (_, _) => const Scaffold(body: Text('NOTIF')),
      ),
    ],
  );
  return MaterialApp.router(theme: NinhoTheme.light(), routerConfig: router);
}

const _rooms = [
  RoomRow(id: 'r1', name: 'Cozinha', sizeCategory: 'M'),
  RoomRow(id: 'r2', name: 'Sala', sizeCategory: 'G'),
];

void main() {
  testWidgets('ready: mostra nome, sub-telas, toggles', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(EnvironmentSettingsScreen(
        environmentsRepository: _FakeEnvRepo(
          rooms: _rooms,
          members: [
            EnvironmentMember(
              userId: 'u1',
              displayName: 'Marina',
              role: 'owner',
              joinedAt: DateTime(2026, 1, 1),
            ),
          ],
        ),
        shopRepository: const _FakeShopRepo(),
      )),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lar Atual'), findsOneWidget);
    expect(find.byKey(const Key('env_row_rooms')), findsOneWidget);
    expect(find.textContaining('Gerenciar 2 cômodos'), findsOneWidget);
    expect(find.textContaining('1 moradores'), findsOneWidget);
    expect(find.byKey(const Key('env_toggle_transfer')), findsOneWidget);
    expect(find.byKey(const Key('env_toggle_vacation')), findsOneWidget);
  });

  testWidgets('member não-owner: toggles desabilitados, sem botão renomear', (
    tester,
  ) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(EnvironmentSettingsScreen(
        environmentsRepository: _FakeEnvRepo(role: 'member', rooms: _rooms),
        shopRepository: const _FakeShopRepo(),
      )),
    );
    await tester.pumpAndSettle();

    final transferSwitch = tester.widget<Switch>(
      find.byKey(const Key('env_toggle_transfer')),
    );
    expect(transferSwitch.onChanged, isNull);

    // Não deve ter row Transferir Propriedade (só pra owner).
    expect(find.byKey(const Key('env_row_transfer_owner')), findsNothing);
  });

  testWidgets('toggle modo viagem chama startVacation', (tester) async {
    _setMobile(tester);
    final env = _FakeEnvRepo(rooms: _rooms);
    await tester.pumpWidget(
      _wrap(EnvironmentSettingsScreen(
        environmentsRepository: env,
        shopRepository: const _FakeShopRepo(),
      )),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('env_toggle_vacation')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('env_toggle_vacation')));
    await tester.pumpAndSettle();

    expect(env.lastVacation, isTrue);
  });

  testWidgets('renomear chama updateName', (tester) async {
    _setMobile(tester);
    final env = _FakeEnvRepo(rooms: _rooms);
    await tester.pumpWidget(
      _wrap(EnvironmentSettingsScreen(
        environmentsRepository: env,
        shopRepository: const _FakeShopRepo(),
      )),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('env_row_name')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('env_rename_input')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('env_rename_input')),
      'Apê Novo',
    );
    await tester.tap(find.byKey(const Key('env_rename_save')));
    await tester.pumpAndSettle();

    expect(env.lastName, 'Apê Novo');
  });

  testWidgets('link rooms navega pra /environment/rooms', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(EnvironmentSettingsScreen(
        environmentsRepository: _FakeEnvRepo(rooms: _rooms),
        shopRepository: const _FakeShopRepo(),
      )),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('env_row_rooms')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('env_row_rooms')));
    await tester.pumpAndSettle();

    expect(find.text('ROOMS'), findsOneWidget);
  });

  testWidgets('sem ninho mostra retry', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(EnvironmentSettingsScreen(
        environmentsRepository: _FakeEnvRepo(envId: null),
        shopRepository: const _FakeShopRepo(),
      )),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('env_settings_error')), findsOneWidget);
    expect(find.byKey(const Key('env_settings_retry')), findsOneWidget);
  });
}
