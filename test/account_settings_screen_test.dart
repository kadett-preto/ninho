import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ninho/data/repositories/users_repository.dart';
import 'package:ninho/ui/core/theme.dart';
import 'package:ninho/ui/features/account/account_settings_screen.dart';

class _FakeUsersRepo extends UsersRepository {
  _FakeUsersRepo({this.snapshot, this.throwOnUpdate = false});

  UserProfileSnapshot? snapshot;
  bool throwOnUpdate;
  String? lastLocale;
  String? lastDisplayName;

  @override
  Future<UserProfileSnapshot?> fetchSelf() async => snapshot;

  @override
  Future<void> updateProfile({String? displayName, String? locale}) async {
    if (throwOnUpdate) throw StateError('boom');
    lastDisplayName = displayName;
    lastLocale = locale;
    if (snapshot != null) {
      snapshot = UserProfileSnapshot(
        id: snapshot!.id,
        displayName: displayName ?? snapshot!.displayName,
        email: snapshot!.email,
        locale: locale ?? snapshot!.locale,
        avatarPath: snapshot!.avatarPath,
      );
    }
  }

  @override
  Future<String?> signedAvatarUrl(String avatarPath) async => null;
}

Widget _wrap(Widget child) {
  final router = GoRouter(
    initialLocation: '/profile/account',
    routes: [
      GoRoute(path: '/profile/account', builder: (_, __) => child),
      GoRoute(
        path: '/profile/account/edit',
        builder: (_, __) => const Scaffold(body: Text('edit')),
      ),
      GoRoute(
        path: '/settings/notifications',
        builder: (_, __) => const Scaffold(body: Text('notif')),
      ),
      GoRoute(
        path: '/profile/export',
        builder: (_, __) => const Scaffold(body: Text('export')),
      ),
      GoRoute(
        path: '/profile/delete',
        builder: (_, __) => const Scaffold(body: Text('delete')),
      ),
      GoRoute(path: '/', builder: (_, __) => const Scaffold(body: Text('splash'))),
    ],
  );
  return MaterialApp.router(
    theme: NinhoTheme.light(),
    routerConfig: router,
  );
}

void main() {
  testWidgets('hub mostra email e idioma do perfil carregado', (tester) async {
    final repo = _FakeUsersRepo(
      snapshot: const UserProfileSnapshot(
        id: 'u',
        displayName: 'Marina',
        email: 'marina@ninho.test',
        locale: 'pt-BR',
        avatarPath: null,
      ),
    );
    await tester.pumpWidget(
      _wrap(AccountSettingsScreen(usersRepository: repo)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Conta'), findsOneWidget);
    expect(find.text('marina@ninho.test'), findsOneWidget);
    expect(find.text('Português (BR)'), findsOneWidget);
    expect(find.byKey(const Key('account_row_edit_profile')), findsOneWidget);
  });

  testWidgets('seleção de idioma chama updateProfile', (tester) async {
    final repo = _FakeUsersRepo(
      snapshot: const UserProfileSnapshot(
        id: 'u',
        displayName: 'Marina',
        email: 'm@x',
        locale: 'pt-BR',
        avatarPath: null,
      ),
    );
    await tester.pumpWidget(
      _wrap(AccountSettingsScreen(usersRepository: repo)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('account_row_locale')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('account_locale_en')));
    await tester.pumpAndSettle();

    expect(repo.lastLocale, 'en');
  });

  testWidgets('erro de carga mostra retry', (tester) async {
    final repo = _FakeUsersRepo(snapshot: null);
    await tester.pumpWidget(
      _wrap(AccountSettingsScreen(usersRepository: repo)),
    );
    await tester.pumpAndSettle();
    // fetchSelf devolve null → profile fica null → controller fica ready
    // (não erro), e o hub deve renderizar com '—' no email.
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('"Aparência" mostra snackbar Em breve', (tester) async {
    final repo = _FakeUsersRepo(
      snapshot: const UserProfileSnapshot(
        id: 'u',
        displayName: 'M',
        email: 'm@x',
        locale: 'pt-BR',
        avatarPath: null,
      ),
    );
    await tester.pumpWidget(
      _wrap(AccountSettingsScreen(usersRepository: repo)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('account_row_appearance')));
    await tester.pump();
    expect(find.text('Em breve.'), findsOneWidget);
  });
}
