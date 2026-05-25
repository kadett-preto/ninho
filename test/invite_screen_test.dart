import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ninho/data/repositories/environments_repository.dart';
import 'package:ninho/data/repositories/invites_repository.dart';
import 'package:ninho/ui/core/theme.dart';
import 'package:ninho/ui/features/invite/invite_screen.dart';

class _FakeEnvRepo extends EnvironmentsRepository {
  _FakeEnvRepo(this._id);
  final String? _id;
  @override
  Future<String?> fetchCurrentEnvironmentId() async => _id;
}

class _FakeInvitesRepo extends InvitesRepository {
  _FakeInvitesRepo({this.invite, this.error});
  final Invite? invite;
  final Object? error;

  @override
  Future<Invite> createInvite({
    required String environmentId,
    int ttlDays = 7,
  }) async {
    if (error != null) throw error!;
    return invite!;
  }
}

void _setMobile(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _wrap(InviteScreen screen) {
  // GoRouter shell para que context.go funcione no teste.
  final router = GoRouter(
    initialLocation: '/test',
    routes: [
      GoRoute(path: '/test', builder: (_, _) => screen),
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('HOME')),
      ),
    ],
  );
  return MaterialApp.router(theme: NinhoTheme.light(), routerConfig: router);
}

void main() {
  testWidgets('invite screen exibe headline + copy + QR após carregar', (
    tester,
  ) async {
    _setMobile(tester);
    final invite = Invite(
      id: 'inv-1',
      token: 'tok-abc',
      expiresAt: DateTime.utc(2026, 6, 1),
    );
    await tester.pumpWidget(
      _wrap(
        InviteScreen(
          fromSetup: true,
          environmentsRepository: _FakeEnvRepo('env-1'),
          invitesRepository: _FakeInvitesRepo(invite: invite),
          inviteBaseUrl: 'https://ninho.test',
        ),
      ),
    );

    // Pump inicial mostra spinner; resolve future + rebuild.
    await tester.pumpAndSettle();

    expect(find.text('Convide quem mora com você'), findsOneWidget);
    expect(
      find.text('No plano gratuito o ninho é pra 2 pessoas.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('invite_qr')), findsOneWidget);
    expect(
      find.textContaining('https://ninho.test/#/i/tok-abc'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('invite_copy_button')), findsOneWidget);
    // fromSetup=true → mostra "Pular" + "Concluir configuração".
    expect(find.byKey(const Key('invite_skip_button')), findsOneWidget);
    expect(find.text('Concluir configuração'), findsOneWidget);
  });

  testWidgets('invite screen mostra erro quando geração falha', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(
        InviteScreen(
          environmentsRepository: _FakeEnvRepo('env-1'),
          invitesRepository: _FakeInvitesRepo(error: Exception('boom')),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.textContaining('Não conseguimos gerar o convite'),
      findsOneWidget,
    );
    // Sem fromSetup → CTA é "Pronto" e não tem skip.
    expect(find.byKey(const Key('invite_skip_button')), findsNothing);
    expect(find.text('Pronto'), findsOneWidget);
  });

  testWidgets('invite screen mostra erro quando não há ninho', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(
        InviteScreen(
          environmentsRepository: _FakeEnvRepo(null),
          invitesRepository: _FakeInvitesRepo(invite: null),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.textContaining('Não conseguimos gerar o convite'),
      findsOneWidget,
    );
  });
}
