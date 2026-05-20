import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ninho/ui/core/colors.dart';
import 'package:ninho/ui/core/theme.dart';
import 'package:ninho/ui/features/auth/lgpd_consent_screen.dart';
import 'package:ninho/ui/features/auth/login_screen.dart';
import 'package:ninho/ui/features/home/home_placeholder_screen.dart';
import 'package:ninho/ui/features/onboarding/splash_screen.dart';
import 'package:ninho/ui/features/onboarding/welcome_card.dart';

Widget _wrap(Widget child) {
  return MaterialApp(theme: NinhoTheme.light(), home: child);
}

void _setMobile(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532); // iPhone 13 px
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('splash renders ninho wordmark', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(_wrap(const SplashScreen()));
    expect(find.text('ninho'), findsOneWidget);
  });

  testWidgets('welcome card shows headline and CTAs', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(WelcomeCard(onPrimary: () {}, onSecondary: () {})),
    );
    expect(
      find.text('A divisão de tarefas justa e leve da casa.'),
      findsOneWidget,
    );
    expect(find.text('Começar'), findsOneWidget);
    expect(find.text('Já tenho conta · Entrar'), findsOneWidget);
  });

  testWidgets('login shows Google + Apple buttons', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(_wrap(const LoginScreen()));
    expect(find.text('Equilíbrio Afetivo'), findsOneWidget);
    expect(find.text('Continuar com Google'), findsOneWidget);
    expect(find.text('Continuar com Apple'), findsOneWidget);
  });

  testWidgets('LGPD: 3 toggles — 1 obrigatório (disabled) + 2 opcionais', (
    tester,
  ) async {
    _setMobile(tester);
    await tester.pumpWidget(_wrap(const LgpdConsentScreen()));
    expect(find.text('Sua privacidade vem primeiro.'), findsOneWidget);
    expect(find.text('Obrigatório'), findsOneWidget);

    final switches = find.byType(Switch);
    expect(switches, findsNWidgets(3));

    // O 1º Switch (obrigatório) tem onChanged null = disabled.
    final required = tester.widget<Switch>(switches.first);
    expect(required.onChanged, isNull);
    expect(required.value, isTrue);

    // Os 2 opcionais começam desligados mas habilitados.
    final notifs = tester.widget<Switch>(switches.at(1));
    expect(notifs.onChanged, isNotNull);
    expect(notifs.value, isFalse);

    final metrics = tester.widget<Switch>(switches.at(2));
    expect(metrics.onChanged, isNotNull);
    expect(metrics.value, isFalse);
  });

  testWidgets('home placeholder shows logout button', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(_wrap(const HomePlaceholderScreen()));
    expect(find.text('Bem-vindo ao Ninho.'), findsOneWidget);
    expect(find.text('Sair do ninho'), findsOneWidget);
    expect(find.byIcon(Icons.logout), findsOneWidget);
  });

  testWidgets('theme uses primary terracotta', (tester) async {
    final theme = NinhoTheme.light();
    expect(theme.colorScheme.primary, NinhoColors.primary);
    expect(theme.colorScheme.secondary, NinhoColors.secondary);
  });
}
