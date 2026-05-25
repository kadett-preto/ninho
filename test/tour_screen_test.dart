import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ninho/ui/core/theme.dart';
import 'package:ninho/ui/features/invite/tour_screen.dart';

void _setMobile(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _wrap(TourScreen screen) {
  final router = GoRouter(
    initialLocation: '/tour',
    routes: [
      GoRoute(path: '/tour', builder: (_, _) => screen),
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('HOME')),
      ),
    ],
  );
  return MaterialApp.router(theme: NinhoTheme.light(), routerConfig: router);
}

void main() {
  testWidgets('primeiro card mostra nome do ninho + CTA "Próximo"', (
    tester,
  ) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(const TourScreen(environmentName: 'Nosso apê')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bem-vindo ao ninho Nosso apê'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Próximo'), findsOneWidget);
  });

  testWidgets('avança até último card e CTA vira "Bora cuidar juntos"', (
    tester,
  ) async {
    _setMobile(tester);
    await tester.pumpWidget(_wrap(const TourScreen(environmentName: 'X')));
    await tester.pumpAndSettle();

    // card 1 → 2
    await tester.tap(find.byKey(const Key('tour_primary_button')));
    await tester.pumpAndSettle();
    expect(find.text('Tarefas com peso justo'), findsOneWidget);

    // card 2 → 3
    await tester.tap(find.byKey(const Key('tour_primary_button')));
    await tester.pumpAndSettle();
    expect(find.text('Streak do ninho'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Bora cuidar juntos'),
      findsOneWidget,
    );
  });

  testWidgets('tap em "Pular" navega pra home', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(_wrap(const TourScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tour_skip_button')));
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('CTA do último card navega pra home', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(_wrap(const TourScreen()));
    await tester.pumpAndSettle();

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const Key('tour_primary_button')));
      await tester.pumpAndSettle();
    }
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('sem environmentName usa título neutro', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(_wrap(const TourScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Bem-vindo ao ninho'), findsOneWidget);
  });
}
