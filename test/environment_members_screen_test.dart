import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ninho/data/repositories/environments_repository.dart';
import 'package:ninho/ui/core/theme.dart';
import 'package:ninho/ui/features/profile/environment_members_screen.dart';

class _FakeRepo extends EnvironmentsRepository {
  _FakeRepo({
    this.envId = 'env-1',
    this.role = 'owner',
    this.members = const [],
  });

  final String? envId;
  final String role;
  final List<EnvironmentMember> members;
  String? lastRemovedId;
  int removeCalls = 0;

  @override
  Future<String?> fetchCurrentEnvironmentId() async => envId;

  @override
  Future<EnvironmentSummary?> fetchEnvironmentSummary({
    required String environmentId,
  }) async =>
      EnvironmentSummary(
        id: environmentId,
        name: 'Lar Doce Lar',
        ownerId: role == 'owner' ? 'me' : 'other',
        role: role,
        createdAt: DateTime(2026, 1, 1),
      );

  @override
  Future<List<EnvironmentMember>> listMembers(String environmentId) async =>
      members;

  @override
  Future<void> removeMember({
    required String environmentId,
    required String userId,
  }) async {
    removeCalls++;
    lastRemovedId = userId;
  }
}

void _setMobile(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _wrap(EnvironmentMembersScreen screen) {
  final router = GoRouter(
    initialLocation: '/profile/environment/members',
    routes: [
      GoRoute(
        path: '/profile/environment/members',
        builder: (_, _) => screen,
      ),
      GoRoute(
        path: '/profile/environment',
        builder: (_, _) => const Scaffold(body: Text('SETTINGS')),
      ),
      GoRoute(
        path: '/invite',
        builder: (_, _) => const Scaffold(body: Text('INVITE')),
      ),
    ],
  );
  return MaterialApp.router(theme: NinhoTheme.light(), routerConfig: router);
}

final _members = [
  EnvironmentMember(
    userId: 'owner-id',
    displayName: 'Marina',
    role: 'owner',
    joinedAt: DateTime(2026, 1, 1),
  ),
  EnvironmentMember(
    userId: 'member-id',
    displayName: 'João',
    role: 'member',
    joinedAt: DateTime(2026, 1, 2),
  ),
];

void main() {
  testWidgets('ready: lista membros + label', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(EnvironmentMembersScreen(
        environmentsRepository: _FakeRepo(members: _members),
      )),
    );
    await tester.pumpAndSettle();

    expect(find.text('Marina'), findsOneWidget);
    expect(find.text('João'), findsOneWidget);
    expect(find.text('Owner'), findsOneWidget);
    expect(find.text('Morador'), findsOneWidget);
  });

  testWidgets('owner vê more_vert só pra members regulares', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(EnvironmentMembersScreen(
        environmentsRepository: _FakeRepo(members: _members),
      )),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('member_more_owner-id')), findsNothing);
    expect(find.byKey(const Key('member_more_member-id')), findsOneWidget);
  });

  testWidgets('member regular não vê more_vert', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(EnvironmentMembersScreen(
        environmentsRepository: _FakeRepo(
          role: 'member',
          members: _members,
        ),
      )),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('member_more_owner-id')), findsNothing);
    expect(find.byKey(const Key('member_more_member-id')), findsNothing);
  });

  testWidgets('remove member: dialog confirm + RPC', (tester) async {
    _setMobile(tester);
    final repo = _FakeRepo(members: _members);
    await tester.pumpWidget(
      _wrap(EnvironmentMembersScreen(environmentsRepository: repo)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('member_more_member-id')));
    await tester.pumpAndSettle();

    expect(find.text('Remover morador?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('member_remove_confirm')));
    await tester.pumpAndSettle();

    expect(repo.removeCalls, 1);
    expect(repo.lastRemovedId, 'member-id');
    expect(find.text('João'), findsNothing);
  });

  testWidgets('convidar membro navega pra /invite', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(EnvironmentMembersScreen(
        environmentsRepository: _FakeRepo(members: _members),
      )),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('members_invite')));
    await tester.pumpAndSettle();

    expect(find.text('INVITE'), findsOneWidget);
  });

  testWidgets('sem ninho mostra retry', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(EnvironmentMembersScreen(
        environmentsRepository: _FakeRepo(envId: null),
      )),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('members_error')), findsOneWidget);
    expect(find.byKey(const Key('members_retry')), findsOneWidget);
  });
}
