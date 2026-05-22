import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ninho/data/repositories/invites_repository.dart';
import 'package:ninho/ui/core/theme.dart';
import 'package:ninho/ui/features/invite/accept_invite_screen.dart';

class _FakeInvitesRepo extends InvitesRepository {
  _FakeInvitesRepo({this.preview, this.previewError, this.acceptError});

  final InvitePreview? preview;
  final Object? previewError;
  final Object? acceptError;
  int acceptCalls = 0;

  @override
  Future<InvitePreview> previewInvite({required String token}) async {
    if (previewError != null) throw previewError!;
    return preview!;
  }

  @override
  Future<AcceptedInvite> acceptInvite({required String token}) async {
    acceptCalls += 1;
    if (acceptError != null) throw acceptError!;
    return AcceptedInvite(
      environmentId: preview?.environmentId ?? 'env-x',
      environmentName: preview?.environmentName ?? 'Ninho',
      alreadyMember: preview?.alreadyMember ?? false,
    );
  }
}

void _setMobile(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _wrap(AcceptInviteScreen screen) {
  final router = GoRouter(
    initialLocation: '/test',
    routes: [
      GoRoute(path: '/test', builder: (_, _) => screen),
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('HOME')),
      ),
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('SPLASH')),
      ),
    ],
  );
  return MaterialApp.router(theme: NinhoTheme.light(), routerConfig: router);
}

InvitePreview _preview({
  String name = 'Nosso apê',
  List<String> members = const ['Ana', 'Bruno'],
  int memberCount = 2,
  int roomCount = 12,
  int streak = 8,
  bool alreadyMember = false,
  DateTime? createdAt,
}) {
  return InvitePreview(
    environmentId: 'env-1',
    environmentName: name,
    environmentCreatedAt:
        createdAt ?? DateTime.now().subtract(const Duration(days: 65)),
    memberCount: memberCount,
    memberNames: members,
    roomCount: roomCount,
    environmentStreak: streak,
    alreadyMember: alreadyMember,
  );
}

void main() {
  testWidgets('preview state mostra nome do ninho + cards + CTAs', (
    tester,
  ) async {
    _setMobile(tester);
    final repo = _FakeInvitesRepo(preview: _preview());
    await tester.pumpWidget(
      _wrap(AcceptInviteScreen(token: 'abc', invitesRepository: repo)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Você foi convidado pro'), findsOneWidget);
    expect(find.text('Nosso apê'), findsOneWidget);
    expect(find.text('Ana · Bruno'), findsOneWidget);
    expect(find.text('12 cômodos'), findsOneWidget);
    expect(find.text('8 dias'), findsOneWidget);
    expect(find.text('há 2 meses'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Entrar no ninho'),
      findsOneWidget,
    );
    expect(find.text('Não, obrigada'), findsOneWidget);
  });

  testWidgets('tap em "Entrar no ninho" chama acceptInvite e navega pra home', (
    tester,
  ) async {
    _setMobile(tester);
    final repo = _FakeInvitesRepo(preview: _preview());
    await tester.pumpWidget(
      _wrap(AcceptInviteScreen(token: 'tok-1', invitesRepository: repo)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('accept_invite_primary_button')));
    await tester.pumpAndSettle();

    expect(repo.acceptCalls, 1);
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('erro genérico no aceite mantém preview e mostra mensagem', (
    tester,
  ) async {
    _setMobile(tester);
    final repo = _FakeInvitesRepo(
      preview: _preview(),
      acceptError: Exception('network failed'),
    );
    await tester.pumpWidget(
      _wrap(AcceptInviteScreen(token: 'tok-error', invitesRepository: repo)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('accept_invite_primary_button')));
    await tester.pumpAndSettle();

    expect(repo.acceptCalls, 1);
    expect(find.text('Nosso apê'), findsOneWidget);
    expect(
      find.text('Algo deu errado. Tente outra vez em instantes.'),
      findsOneWidget,
    );
  });

  testWidgets('preview expirado mostra tela de "Convite Expirado"', (
    tester,
  ) async {
    _setMobile(tester);
    final repo = _FakeInvitesRepo(
      previewError: Exception('Convite expirado (errcode 22023)'),
    );
    await tester.pumpWidget(
      _wrap(const AcceptInviteScreen(token: 'tok-2').copyWithRepo(repo)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Opa, esse convite expirou'), findsOneWidget);
    expect(
      find.text(
        'Esse convite não está mais valendo. Peça um novo pra quem te chamou.',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Voltar'), findsOneWidget);
  });

  testWidgets('errcode 42704 (não encontrado) também vai pra tela expirada', (
    tester,
  ) async {
    _setMobile(tester);
    final repo = _FakeInvitesRepo(
      previewError: Exception('Convite não encontrado (errcode 42704)'),
    );
    await tester.pumpWidget(
      _wrap(const AcceptInviteScreen(token: 'tok-x').copyWithRepo(repo)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Opa, esse convite expirou'), findsOneWidget);
  });

  testWidgets('erro genérico (sem código conhecido) vira estado de erro', (
    tester,
  ) async {
    _setMobile(tester);
    final repo = _FakeInvitesRepo(previewError: Exception('connection failed'));
    await tester.pumpWidget(
      _wrap(const AcceptInviteScreen(token: 'tok-y').copyWithRepo(repo)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Algo deu errado. Tente outra vez em instantes.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Tentar de novo'), findsOneWidget);
  });

  testWidgets('alreadyMember muda copy do convite', (tester) async {
    _setMobile(tester);
    final repo = _FakeInvitesRepo(preview: _preview(alreadyMember: true));
    await tester.pumpWidget(
      _wrap(AcceptInviteScreen(token: 'tok-3', invitesRepository: repo)),
    );
    await tester.pumpAndSettle();

    // Body text fica abaixo dos cards no ListView; precisa scroll para entrar
    // no viewport antes do find.
    await tester.scrollUntilVisible(
      find.textContaining('Você já mora aqui'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Você já mora aqui'), findsOneWidget);
  });

  testWidgets('membros parcialmente listados mostram "+N"', (tester) async {
    _setMobile(tester);
    final repo = _FakeInvitesRepo(
      preview: _preview(
        members: const ['Ana', 'Bruno', 'Carla'],
        memberCount: 5,
      ),
    );
    await tester.pumpWidget(
      _wrap(AcceptInviteScreen(token: 'tok-4', invitesRepository: repo)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ana · Bruno · Carla +2'), findsOneWidget);
  });
}

// Helper para passar repo num const constructor (test-only).
extension on AcceptInviteScreen {
  AcceptInviteScreen copyWithRepo(InvitesRepository repo) =>
      AcceptInviteScreen(token: token, invitesRepository: repo);
}
