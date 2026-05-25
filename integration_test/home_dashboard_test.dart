import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:ninho/ui/core/routes.dart';
import 'package:ninho/ui/core/theme.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('home dashboard renders on device', (tester) async {
    await tester.pumpWidget(
      MaterialApp.router(
        theme: NinhoTheme.light(),
        debugShowCheckedModeBanner: false,
        routerConfig: createNinhoRouter(initialLocation: NinhoRoutes.home),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Sem sessão Supabase, HomeController cai em noEnvironment ou erro.
    // Validamos que a tela montou com bottom nav + perfil reachable.
    expect(find.text('Início'), findsOneWidget);
    expect(find.text('Perfil'), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav_profile')));
    await tester.pumpAndSettle();

    // ProfileScreen sem sessão pode cair em error (auth ausente) ou
    // noEnvironment. Aceitamos qualquer estado pós-navegação.
    final reached =
        find.byKey(const Key('profile_error')).evaluate().isNotEmpty ||
        find.byKey(const Key('profile_name')).evaluate().isNotEmpty ||
        find.byKey(const Key('profile_signout_button')).evaluate().isNotEmpty;
    expect(
      reached,
      isTrue,
      reason: 'ProfileScreen não renderizou nenhum estado conhecido',
    );
  });

  testWidgets('task detail renders demo content on device', (tester) async {
    // Detail/Completion ainda têm fallback de demo data por taskId não-UUID.
    // Navegação direta pra rota com taskId 'dishes' usa esse fallback.
    await tester.pumpWidget(
      MaterialApp.router(
        theme: NinhoTheme.light(),
        debugShowCheckedModeBanner: false,
        routerConfig: createNinhoRouter(initialLocation: '/tasks/dishes'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Detalhes da Tarefa'), findsOneWidget);
    expect(find.text('Lavar a louça'), findsOneWidget);
    expect(find.text('Marcar como feita'), findsOneWidget);

    await tester.tap(find.byKey(const Key('task_detail_complete_button')));
    await tester.pumpAndSettle();

    expect(find.text('Mandou bem!'), findsOneWidget);
    expect(find.text('+15 poeiras'), findsOneWidget);
    expect(find.text('Concluir tarefa'), findsOneWidget);

    await tester.tap(find.byKey(const Key('task_completion_photo_button')));
    await tester.pumpAndSettle();

    expect(find.text('Tirar foto'), findsOneWidget);
    expect(find.text('Escolher da galeria'), findsOneWidget);
  });

  testWidgets('tasks tab opens TasksScreen on device', (tester) async {
    await tester.pumpWidget(
      MaterialApp.router(
        theme: NinhoTheme.light(),
        debugShowCheckedModeBanner: false,
        routerConfig: createNinhoRouter(initialLocation: NinhoRoutes.home),
      ),
    );
    await tester.pumpAndSettle();

    // Bottom nav: Tarefas é o segundo item. Tem 2 ocorrências do texto
    // "Tarefas" só após navegar; a partir da Home só existe 1 (no nav).
    final navTarefas = find.text('Tarefas').first;
    await tester.tap(navTarefas);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // TasksScreen sem sessão Supabase cai no fluxo de erro humano —
    // valida que a tela montou e exibiu mensagem amigável.
    expect(find.byKey(const Key('tasks_error')), findsOneWidget);
  });

  testWidgets('task form (new) renders on device', (tester) async {
    await tester.pumpWidget(
      MaterialApp.router(
        theme: NinhoTheme.light(),
        debugShowCheckedModeBanner: false,
        routerConfig: createNinhoRouter(initialLocation: '/tasks/new'),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Sem sessão, controller cai no estado de erro humanizado.
    expect(find.byKey(const Key('task_form_error')), findsOneWidget);
  });
}
