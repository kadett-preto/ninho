import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ninho/data/repositories/environments_repository.dart';
import 'package:ninho/ui/core/theme.dart';
import 'package:ninho/ui/features/profile/transfer_ownership_screen.dart';

class _FakeEnvRepo extends EnvironmentsRepository {
  _FakeEnvRepo({
    this.envId = 'env-1',
    this.members = const [],
    this.transferError,
  });

  final String? envId;
  final List<EnvironmentMember> members;
  final Object? transferError;

  int transferCalls = 0;
  String? lastTarget;

  @override
  Future<String?> fetchCurrentEnvironmentId() async => envId;

  @override
  Future<List<EnvironmentMember>> listMembers(String environmentId) async =>
      members;

  @override
  Future<void> transferOwnership({
    required String environmentId,
    required String newOwnerId,
  }) async {
    transferCalls++;
    lastTarget = newOwnerId;
    if (transferError != null) throw transferError!;
  }
}

void _setMobile(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _wrap(TransferOwnershipScreen screen) {
  final router = GoRouter(
    initialLocation: '/profile/transfer-ownership',
    routes: [
      GoRoute(
        path: '/profile/transfer-ownership',
        builder: (_, _) => screen,
      ),
      GoRoute(
        path: '/profile',
        builder: (_, _) => const Scaffold(body: Text('PROFILE')),
      ),
    ],
  );
  return MaterialApp.router(theme: NinhoTheme.light(), routerConfig: router);
}

const _owner = 'owner-id';
final _members = [
  EnvironmentMember(
    userId: _owner,
    displayName: 'Owner',
    role: 'owner',
    joinedAt: DateTime(2026, 1, 1),
  ),
  EnvironmentMember(
    userId: 'ana-id',
    displayName: 'Ana',
    role: 'member',
    joinedAt: DateTime(2026, 1, 2),
  ),
  EnvironmentMember(
    userId: 'joao-id',
    displayName: 'João',
    role: 'member',
    joinedAt: DateTime(2026, 1, 3),
  ),
];

void main() {
  testWidgets('lista candidatos exclui o caller', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(TransferOwnershipScreen(
        environmentsRepository: _FakeEnvRepo(members: _members),
        currentUserId: _owner,
      )),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('João'), findsOneWidget);
    expect(find.byKey(const Key('transfer_member_$_owner')), findsNothing);
  });

  testWidgets('CTA desabilita até selecionar + ack', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(TransferOwnershipScreen(
        environmentsRepository: _FakeEnvRepo(members: _members),
        currentUserId: _owner,
      )),
    );
    await tester.pumpAndSettle();

    var btn = tester.widget<FilledButton>(find.byKey(const Key('transfer_submit')));
    expect(btn.onPressed, isNull);

    await tester.tap(find.byKey(const Key('transfer_member_ana-id')));
    await tester.pumpAndSettle();
    btn = tester.widget<FilledButton>(find.byKey(const Key('transfer_submit')));
    expect(btn.onPressed, isNull); // ainda falta o checkbox

    await tester.tap(find.byKey(const Key('transfer_ack_checkbox')));
    await tester.pumpAndSettle();
    btn = tester.widget<FilledButton>(find.byKey(const Key('transfer_submit')));
    expect(btn.onPressed, isNotNull);
  });

  testWidgets('submit chama RPC + redireciona pra /profile', (tester) async {
    _setMobile(tester);
    final repo = _FakeEnvRepo(members: _members);
    await tester.pumpWidget(
      _wrap(TransferOwnershipScreen(
        environmentsRepository: repo,
        currentUserId: _owner,
      )),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('transfer_member_joao-id')));
    await tester.tap(find.byKey(const Key('transfer_ack_checkbox')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('transfer_submit')));
    await tester.pumpAndSettle();

    expect(repo.transferCalls, 1);
    expect(repo.lastTarget, 'joao-id');
    expect(find.text('PROFILE'), findsOneWidget);
  });

  testWidgets('erro 42501 vira mensagem human', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(TransferOwnershipScreen(
        environmentsRepository: _FakeEnvRepo(
          members: _members,
          transferError: Exception('errcode 42501 — sem permissão'),
        ),
        currentUserId: _owner,
      )),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('transfer_member_ana-id')));
    await tester.tap(find.byKey(const Key('transfer_ack_checkbox')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('transfer_submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('transfer_error_text')), findsOneWidget);
    expect(find.textContaining('Apenas o owner'), findsOneWidget);
  });

  testWidgets('sem candidatos mostra mensagem de convidar', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(TransferOwnershipScreen(
        environmentsRepository: _FakeEnvRepo(
          members: [
            EnvironmentMember(
              userId: _owner,
              displayName: 'Solo',
              role: 'owner',
              joinedAt: DateTime(2026, 1, 1),
            ),
          ],
        ),
        currentUserId: _owner,
      )),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('transfer_empty')), findsOneWidget);
  });

  testWidgets('sem ninho mostra erro + retry', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(TransferOwnershipScreen(
        environmentsRepository: _FakeEnvRepo(envId: null),
        currentUserId: _owner,
      )),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('transfer_error')), findsOneWidget);
    expect(find.byKey(const Key('transfer_retry')), findsOneWidget);
  });

  testWidgets('back navega pra /profile', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(TransferOwnershipScreen(
        environmentsRepository: _FakeEnvRepo(members: _members),
        currentUserId: _owner,
      )),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('transfer_back')));
    await tester.pumpAndSettle();

    expect(find.text('PROFILE'), findsOneWidget);
  });
}
