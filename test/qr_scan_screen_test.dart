import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ninho/data/repositories/invites_repository.dart';

// Testa apenas o parser de token usado pela QrScanScreen.
// Renderização da câmera depende de plataforma e não roda em flutter_test.
//
// Cobertura aqui:
//   - Link válido /i/<token> retorna o token.
//   - Texto não-Ninho retorna null (a screen mostra hint, não roteia).
//   - Link sem token retorna null.
//   - Roteamento ao parsear token válido (sanity check do GoRouter).
void main() {
  group('InvitesRepository.tokenFromLink (entrada do scanner)', () {
    test('link válido extrai token', () {
      expect(
        InvitesRepository.tokenFromLink('https://ninho.app/i/abc-123'),
        'abc-123',
      );
    });

    test('link sem segmento /i/ → null', () {
      expect(
        InvitesRepository.tokenFromLink('https://example.com/welcome'),
        isNull,
      );
    });

    test('texto livre → null', () {
      expect(InvitesRepository.tokenFromLink('BEGIN:VCARD'), isNull);
    });

    test('link sem token após /i/ → null', () {
      expect(InvitesRepository.tokenFromLink('https://ninho.app/i/'), isNull);
    });
  });

  testWidgets('rota /i/:token recebe parâmetro do GoRouter', (tester) async {
    final router = GoRouter(
      initialLocation: '/i/abc-123',
      routes: [
        GoRoute(
          path: '/i/:token',
          builder: (_, state) =>
              Scaffold(body: Text('TOKEN ${state.pathParameters['token']}')),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('TOKEN abc-123'), findsOneWidget);
  });
}
