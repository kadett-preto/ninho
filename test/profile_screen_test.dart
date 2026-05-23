import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ninho/data/repositories/environments_repository.dart';
import 'package:ninho/data/repositories/shop_repository.dart';
import 'package:ninho/data/repositories/streaks_repository.dart';
import 'package:ninho/data/repositories/users_repository.dart';
import 'package:ninho/ui/core/theme.dart';
import 'package:ninho/ui/features/profile/profile_screen.dart';

class _FakeUsersRepo extends UsersRepository {
  _FakeUsersRepo({this.snapshot});
  final UserProfileSnapshot? snapshot;

  @override
  Future<UserProfileSnapshot?> fetchSelf() async => snapshot;
}

class _FakeEnvRepo extends EnvironmentsRepository {
  _FakeEnvRepo({
    this.envId = 'env-1',
    this.summary,
    this.leaveError,
  });
  final String? envId;
  final EnvironmentSummary? summary;
  final Object? leaveError;
  int leaveCalls = 0;

  @override
  Future<String?> fetchCurrentEnvironmentId() async => envId;

  @override
  Future<EnvironmentSummary?> fetchEnvironmentSummary({
    required String environmentId,
  }) async {
    return summary ??
        EnvironmentSummary(
          id: environmentId,
          name: 'Nosso apê',
          ownerId: 'owner-id',
          role: 'member',
          createdAt: DateTime(2026, 1, 1),
        );
  }

  @override
  Future<LeaveEnvironmentResult> leaveEnvironment(String environmentId) async {
    leaveCalls++;
    if (leaveError != null) throw leaveError!;
    return const LeaveEnvironmentResult(
      alreadyLeft: false,
      envArchived: false,
    );
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
          userBest: 0,
          environmentCount: 0,
          environmentBest: 0,
          freezesLeftMonth: 2,
        );
  }
}

class _FakeShopRepo extends ShopRepository {
  const _FakeShopRepo({this.balance = 0});
  final int balance;

  @override
  Future<int> fetchBalance({required String environmentId}) async => balance;
}

void _setMobile(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _wrap({
  required UsersRepository users,
  required EnvironmentsRepository env,
  StreaksRepository? streaks,
  ShopRepository? shop,
}) {
  final router = GoRouter(
    initialLocation: '/profile',
    routes: [
      GoRoute(
        path: '/profile',
        builder: (_, _) => ProfileScreen(
          usersRepository: users,
          environmentsRepository: env,
          streaksRepository: streaks,
          shopRepository: shop,
        ),
      ),
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('HOME')),
      ),
      GoRoute(
        path: '/setup/step1',
        builder: (_, _) => const Scaffold(body: Text('SETUP1')),
      ),
      GoRoute(
        path: '/settings/notifications',
        builder: (_, _) => const Scaffold(body: Text('NOTIF')),
      ),
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('SPLASH')),
      ),
    ],
  );
  return MaterialApp.router(theme: NinhoTheme.light(), routerConfig: router);
}

void main() {
  testWidgets('ready: mostra nome, chips e stats', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(
        users: _FakeUsersRepo(
          snapshot: const UserProfileSnapshot(
            id: 'u',
            displayName: 'Marina',
            email: 'marina@test.local',
          ),
        ),
        env: _FakeEnvRepo(
          summary: EnvironmentSummary(
            id: 'env-1',
            name: 'Lar Doce Lar',
            ownerId: 'u',
            role: 'owner',
            createdAt: DateTime(2026, 1, 1),
          ),
        ),
        streaks: const _FakeStreaksRepo(
          summary: StreakSummary(
            userCount: 12,
            userBest: 21,
            environmentCount: 8,
            environmentBest: 21,
            freezesLeftMonth: 2,
          ),
        ),
        shop: const _FakeShopRepo(balance: 145),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile_name')), findsOneWidget);
    expect(find.text('Marina'), findsOneWidget);
    expect(find.text('Lar Doce Lar'), findsOneWidget);
    expect(find.text('Owner'), findsOneWidget);
    expect(find.text('12'), findsOneWidget); // streak atual
    expect(find.text('21'), findsOneWidget); // best
    expect(find.text('145'), findsOneWidget); // poeira
    // Scroll até signout button (final do ListView).
    await tester.scrollUntilVisible(
      find.byKey(const Key('profile_signout_button')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Sair da conta'), findsOneWidget);
  });

  testWidgets('member não-owner mostra chip Morador', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(
        users: _FakeUsersRepo(
          snapshot: const UserProfileSnapshot(
            id: 'u',
            displayName: null,
            email: 'bob@test.local',
          ),
        ),
        env: _FakeEnvRepo(),
        streaks: const _FakeStreaksRepo(),
        shop: const _FakeShopRepo(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bob'), findsOneWidget); // fallback do email
    expect(find.text('Morador'), findsOneWidget);
  });

  testWidgets('sem ninho mostra CTA criar ninho', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(
        users: _FakeUsersRepo(
          snapshot: const UserProfileSnapshot(
            id: 'u',
            displayName: 'Marina',
            email: 'marina@test.local',
          ),
        ),
        env: _FakeEnvRepo(envId: null),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Criar meu ninho'), findsOneWidget);
    expect(find.text('Sair da conta'), findsOneWidget);
  });

  testWidgets('erro mostra retry', (tester) async {
    _setMobile(tester);
    // FakeUsersRepo OK mas env summary lança erro via override.
    final env = _ThrowingEnvRepo();
    await tester.pumpWidget(
      _wrap(
        users: _FakeUsersRepo(
          snapshot: const UserProfileSnapshot(
            id: 'u',
            displayName: 'Marina',
            email: 'marina@test.local',
          ),
        ),
        env: env,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile_error')), findsOneWidget);
    expect(find.byKey(const Key('profile_retry')), findsOneWidget);
  });

  testWidgets('menu de notificações navega pra /settings/notifications', (
    tester,
  ) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(
        users: _FakeUsersRepo(
          snapshot: const UserProfileSnapshot(
            id: 'u',
            displayName: 'Marina',
            email: 'marina@test.local',
          ),
        ),
        env: _FakeEnvRepo(),
        streaks: const _FakeStreaksRepo(),
        shop: const _FakeShopRepo(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('profile_menu_notifications')));
    await tester.pumpAndSettle();

    expect(find.text('NOTIF'), findsOneWidget);
  });

  testWidgets('sair do ninho confirma + chama RPC + vai pra splash', (
    tester,
  ) async {
    _setMobile(tester);
    final env = _FakeEnvRepo(
      summary: EnvironmentSummary(
        id: 'env-1',
        name: 'Nosso apê',
        ownerId: 'other',
        role: 'member',
        createdAt: DateTime(2026, 1, 1),
      ),
    );
    await tester.pumpWidget(
      _wrap(
        users: _FakeUsersRepo(
          snapshot: const UserProfileSnapshot(
            id: 'u',
            displayName: 'Marina',
            email: 'marina@test.local',
          ),
        ),
        env: env,
        streaks: const _FakeStreaksRepo(),
        shop: const _FakeShopRepo(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile_menu_leave_env')));
    await tester.pumpAndSettle();

    expect(find.text('Sair do ninho?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('leave_env_confirm')));
    await tester.pumpAndSettle();

    expect(env.leaveCalls, 1);
    expect(find.text('SPLASH'), findsOneWidget);
  });

  testWidgets('owner com membros vê snackbar de transferir', (tester) async {
    _setMobile(tester);
    final env = _FakeEnvRepo(
      summary: EnvironmentSummary(
        id: 'env-1',
        name: 'Nosso apê',
        ownerId: 'u',
        role: 'owner',
        createdAt: DateTime(2026, 1, 1),
      ),
      leaveError: Exception('errcode 22023 — transfira'),
    );
    await tester.pumpWidget(
      _wrap(
        users: _FakeUsersRepo(
          snapshot: const UserProfileSnapshot(
            id: 'u',
            displayName: 'Marina',
            email: 'marina@test.local',
          ),
        ),
        env: env,
        streaks: const _FakeStreaksRepo(),
        shop: const _FakeShopRepo(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile_menu_leave_env')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('leave_env_confirm')));
    await tester.pumpAndSettle();

    expect(env.leaveCalls, 1);
    expect(find.textContaining('Transfira a propriedade'), findsOneWidget);
  });

  testWidgets('menu coming-soon abre snackbar Em breve', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(
        users: _FakeUsersRepo(
          snapshot: const UserProfileSnapshot(
            id: 'u',
            displayName: 'Marina',
            email: 'marina@test.local',
          ),
        ),
        env: _FakeEnvRepo(),
        streaks: const _FakeStreaksRepo(),
        shop: const _FakeShopRepo(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('profile_menu_account')));
    await tester.pump();

    expect(find.text('Em breve.'), findsOneWidget);
  });
}

class _ThrowingEnvRepo extends EnvironmentsRepository {
  @override
  Future<String?> fetchCurrentEnvironmentId() async => 'env-1';

  @override
  Future<EnvironmentSummary?> fetchEnvironmentSummary({
    required String environmentId,
  }) async {
    throw Exception('boom');
  }
}
