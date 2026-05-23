import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ninho/data/repositories/users_repository.dart';
import 'package:ninho/ui/core/theme.dart';
import 'package:ninho/ui/features/profile/delete_account_screen.dart';

class _FakeUsersRepo extends UsersRepository {
  _FakeUsersRepo({
    this.owned = const [],
    this.deletionError,
  });

  final List<OwnedEnvironment> owned;
  final Object? deletionError;

  int deleteCalls = 0;

  @override
  Future<List<OwnedEnvironment>> listOwnedEnvironments() async => owned;

  @override
  Future<AccountDeletionResult> requestAccountDeletion() async {
    deleteCalls++;
    if (deletionError != null) throw deletionError!;
    return const AccountDeletionResult(
      alreadyDeleted: false,
      envsPromoted: 0,
      envsArchived: 0,
    );
  }
}

void _setMobile(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _wrap(DeleteAccountScreen screen) {
  final router = GoRouter(
    initialLocation: '/profile/delete',
    routes: [
      GoRoute(path: '/profile/delete', builder: (_, _) => screen),
      GoRoute(
        path: '/profile',
        builder: (_, _) => const Scaffold(body: Text('PROFILE')),
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
  testWidgets('estado inicial mostra header + CTAs', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(DeleteAccountScreen(
        usersRepository: _FakeUsersRepo(),
        signOutFn: () async {},
      )),
    );
    await tester.pumpAndSettle();

    expect(find.text('Excluir sua conta'), findsOneWidget);
    expect(find.byKey(const Key('delete_confirm_input')), findsOneWidget);
    expect(find.byKey(const Key('delete_confirm_button')), findsOneWidget);
    expect(find.byKey(const Key('delete_cancel_button')), findsOneWidget);
  });

  testWidgets('CTA confirma só quando input bate "EXCLUIR"', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(DeleteAccountScreen(
        usersRepository: _FakeUsersRepo(),
        signOutFn: () async {},
      )),
    );
    await tester.pumpAndSettle();

    final btn = tester.widget<FilledButton>(
      find.byKey(const Key('delete_confirm_button')),
    );
    expect(btn.onPressed, isNull);

    await tester.enterText(
      find.byKey(const Key('delete_confirm_input')),
      'excluir',
    );
    await tester.pumpAndSettle();

    final btn2 = tester.widget<FilledButton>(
      find.byKey(const Key('delete_confirm_button')),
    );
    expect(btn2.onPressed, isNotNull);
  });

  testWidgets('owner com membros mostra aviso de auto-promoção', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(DeleteAccountScreen(
        usersRepository: _FakeUsersRepo(owned: const [
          OwnedEnvironment(
            environmentId: 'e1',
            name: 'Casa',
            otherMembersCount: 2,
          ),
        ]),
        signOutFn: () async {},
      )),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('delete_owner_warning')), findsOneWidget);
    expect(find.textContaining('membro mais antigo'), findsOneWidget);
  });

  testWidgets('owner solo mostra aviso de arquivamento', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(DeleteAccountScreen(
        usersRepository: _FakeUsersRepo(owned: const [
          OwnedEnvironment(
            environmentId: 'e1',
            name: 'Casa',
            otherMembersCount: 0,
          ),
        ]),
        signOutFn: () async {},
      )),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('delete_owner_warning')), findsOneWidget);
    expect(find.textContaining('arquivados'), findsOneWidget);
  });

  testWidgets('confirmar chama RPC + signOut + vai pra splash', (tester) async {
    _setMobile(tester);
    final repo = _FakeUsersRepo();
    var signOutCalls = 0;
    await tester.pumpWidget(
      _wrap(DeleteAccountScreen(
        usersRepository: repo,
        signOutFn: () async {
          signOutCalls++;
        },
      )),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('delete_confirm_input')),
      'EXCLUIR',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('delete_confirm_button')));
    await tester.pumpAndSettle();

    expect(repo.deleteCalls, 1);
    expect(signOutCalls, 1);
    expect(find.text('SPLASH'), findsOneWidget);
  });

  testWidgets('erro 28000 vira mensagem de sessão', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(DeleteAccountScreen(
        usersRepository: _FakeUsersRepo(
          deletionError: Exception('errcode 28000 — sem sessão'),
        ),
        signOutFn: () async {},
      )),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('delete_confirm_input')),
      'EXCLUIR',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete_confirm_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('delete_error')), findsOneWidget);
    expect(find.textContaining('Sessão expirada'), findsOneWidget);
  });

  testWidgets('back navega pra /profile', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(DeleteAccountScreen(
        usersRepository: _FakeUsersRepo(),
        signOutFn: () async {},
      )),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('delete_back')));
    await tester.pumpAndSettle();

    expect(find.text('PROFILE'), findsOneWidget);
  });

  testWidgets('cancelar navega pra /profile', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(DeleteAccountScreen(
        usersRepository: _FakeUsersRepo(),
        signOutFn: () async {},
      )),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('delete_cancel_button')));
    await tester.pumpAndSettle();

    expect(find.text('PROFILE'), findsOneWidget);
  });
}
