import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import 'package:ninho/data/repositories/users_repository.dart';
import 'package:ninho/ui/core/theme.dart';
import 'package:ninho/ui/features/profile/export_data_screen.dart';

class _FakeUsersRepo extends UsersRepository {
  _FakeUsersRepo({this.payload, this.error});
  final Map<String, dynamic>? payload;
  final Object? error;

  @override
  Future<Map<String, dynamic>> exportUserData() async {
    if (error != null) throw error!;
    return payload ??
        {
          'user': {'id': 'u'},
          'memberships': [],
          'dust_ledger': [],
        };
  }
}

class _ShareSpy {
  XFile? lastFile;
  String? lastSubject;
  int calls = 0;

  Future<void> call(XFile file, {required String subject}) async {
    calls++;
    lastFile = file;
    lastSubject = subject;
  }
}

void _setMobile(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _wrap(ExportDataScreen screen) {
  final router = GoRouter(
    initialLocation: '/profile/export',
    routes: [
      GoRoute(path: '/profile/export', builder: (_, _) => screen),
      GoRoute(
        path: '/profile',
        builder: (_, _) => const Scaffold(body: Text('PROFILE')),
      ),
    ],
  );
  return MaterialApp.router(theme: NinhoTheme.light(), routerConfig: router);
}

void main() {
  testWidgets('estado inicial mostra CTA "Gerar arquivo"', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(ExportDataScreen(usersRepository: _FakeUsersRepo())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Exportar meus dados'), findsOneWidget);
    expect(find.text('Gerar arquivo'), findsOneWidget);
    expect(find.text('Perfil'), findsOneWidget);
    expect(find.text('Tarefas'), findsOneWidget);
  });

  testWidgets('tap em "Gerar arquivo" chama exportUserData + share', (
    tester,
  ) async {
    _setMobile(tester);
    final spy = _ShareSpy();
    await tester.pumpWidget(
      _wrap(
        ExportDataScreen(
          usersRepository: _FakeUsersRepo(
            payload: const {
              'user': {'id': 'u', 'email': 'a@b.com'},
              'memberships': [],
            },
          ),
          shareFn: spy.call,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('export_generate_button')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('export_generate_button')));
    await tester.pumpAndSettle();

    expect(spy.calls, 1);
    expect(spy.lastSubject, contains('Meus dados'));
    expect(spy.lastFile, isNotNull);
    expect(find.byKey(const Key('export_success')), findsOneWidget);
    expect(find.text('Gerar novamente'), findsOneWidget);
  });

  testWidgets('rate-limit 54000 vira mensagem humana', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(
        ExportDataScreen(
          usersRepository: _FakeUsersRepo(
            error: Exception('errcode 54000 — Limite'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('export_generate_button')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('export_generate_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('export_error')), findsOneWidget);
    expect(find.textContaining('limite de exportações'), findsOneWidget);
  });

  testWidgets('back navega pra /profile', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(ExportDataScreen(usersRepository: _FakeUsersRepo())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('export_back')));
    await tester.pumpAndSettle();

    expect(find.text('PROFILE'), findsOneWidget);
  });

  testWidgets('erro genérico mostra mensagem padrão', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(
        ExportDataScreen(
          usersRepository: _FakeUsersRepo(error: Exception('boom')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('export_generate_button')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('export_generate_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('export_error')), findsOneWidget);
    expect(find.textContaining('Não conseguimos'), findsOneWidget);
  });
}
