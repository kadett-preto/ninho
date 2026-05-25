import 'package:flutter_test/flutter_test.dart';

import 'package:ninho/data/repositories/invites_repository.dart';

void main() {
  group('Invite.linkFor', () {
    test('produz link com hash p/ rodar em hosting sem fallback SPA', () {
      final invite = Invite(
        id: 'inv-1',
        token: 'abc.def-xyz',
        expiresAt: DateTime.utc(2026, 6, 1),
      );
      expect(
        invite.linkFor('https://ninho.app'),
        'https://ninho.app/#/i/abc.def-xyz',
      );
    });

    test('aceita base com trailing slash sem duplicar', () {
      final invite = Invite(
        id: 'inv-2',
        token: 'tk',
        expiresAt: DateTime.utc(2026, 6, 1),
      );
      expect(
        invite.linkFor('https://kadett-preto.github.io/ninho/'),
        'https://kadett-preto.github.io/ninho/#/i/tk',
      );
    });
  });

  group('InvitesRepository.tokenFromLink', () {
    test('extrai token de link bem-formado', () {
      expect(
        InvitesRepository.tokenFromLink('https://ninho.app/i/abc123'),
        'abc123',
      );
    });

    test('extrai token mesmo com host arbitrário', () {
      expect(
        InvitesRepository.tokenFromLink('https://staging.ninho.test/i/tok-xyz'),
        'tok-xyz',
      );
    });

    test('ignora links sem segmento /i/', () {
      expect(InvitesRepository.tokenFromLink('https://ninho.app/home'), isNull);
    });

    test('ignora links com /i/ vazio', () {
      expect(InvitesRepository.tokenFromLink('https://ninho.app/i/'), isNull);
    });

    test('retorna null para link malformado', () {
      expect(InvitesRepository.tokenFromLink(':::not a url:::'), isNull);
    });

    test('extrai token da hash route (rota web do GoRouter)', () {
      expect(
        InvitesRepository.tokenFromLink(
          'https://kadett-preto.github.io/ninho/#/i/hash-tk',
        ),
        'hash-tk',
      );
    });

    test('roundtrip: linkFor + tokenFromLink', () {
      const token = 'k8sJ9YbV_aB-cD_eF-gH';
      final invite = Invite(
        id: 'x',
        token: token,
        expiresAt: DateTime.utc(2026, 6, 1),
      );
      final link = invite.linkFor('https://ninho.app');
      expect(InvitesRepository.tokenFromLink(link), token);
    });
  });
}
