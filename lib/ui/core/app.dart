import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import 'routes.dart';
import 'theme.dart';

class NinhoApp extends StatelessWidget {
  const NinhoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Ninho',
      theme: NinhoTheme.light(),
      routerConfig: ninhoRouter,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
    );
  }
}
