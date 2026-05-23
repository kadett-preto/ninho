import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ninho/l10n/generated/app_localizations.dart';
import 'package:ninho/ui/core/widgets/ninho_bottom_nav.dart';

Widget _wrap(Locale locale, Widget child) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('pt: bottom nav usa rótulos pt-BR', (tester) async {
    await tester.pumpWidget(
      _wrap(const Locale('pt'),
          NinhoBottomNav(active: NinhoTab.home, onTap: (_) {})),
    );
    await tester.pumpAndSettle();
    expect(find.text('Início'), findsOneWidget);
    expect(find.text('Tarefas'), findsOneWidget);
    expect(find.text('Mural'), findsOneWidget);
    expect(find.text('Loja'), findsOneWidget);
    expect(find.text('Perfil'), findsOneWidget);
  });

  testWidgets('en: bottom nav usa rótulos en', (tester) async {
    await tester.pumpWidget(
      _wrap(const Locale('en'),
          NinhoBottomNav(active: NinhoTab.home, onTap: (_) {})),
    );
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Tasks'), findsOneWidget);
    expect(find.text('Wall'), findsOneWidget);
    expect(find.text('Shop'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('es: bottom nav usa rótulos es', (tester) async {
    await tester.pumpWidget(
      _wrap(const Locale('es'),
          NinhoBottomNav(active: NinhoTab.home, onTap: (_) {})),
    );
    await tester.pumpAndSettle();
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Tareas'), findsOneWidget);
    expect(find.text('Tienda'), findsOneWidget);
  });

  testWidgets('fr: bottom nav usa rótulos fr', (tester) async {
    await tester.pumpWidget(
      _wrap(const Locale('fr'),
          NinhoBottomNav(active: NinhoTab.home, onTap: (_) {})),
    );
    await tester.pumpAndSettle();
    expect(find.text('Accueil'), findsOneWidget);
    expect(find.text('Tâches'), findsOneWidget);
    expect(find.text('Boutique'), findsOneWidget);
  });

  test('AppL10n declara 4 locales (pt/en/es/fr)', () {
    final codes = AppL10n.supportedLocales.map((l) => l.languageCode).toSet();
    expect(codes, containsAll(<String>{'pt', 'en', 'es', 'fr'}));
  });
}
