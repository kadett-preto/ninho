import 'package:flutter/material.dart';

import 'theme.dart';

class NinhoApp extends StatelessWidget {
  const NinhoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ninho',
      theme: NinhoTheme.light(),
      home: const _Placeholder(),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ninho')),
      body: const Center(child: Text('Bem-vindo ao Ninho.')),
    );
  }
}
