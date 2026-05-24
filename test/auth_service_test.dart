import 'package:flutter_test/flutter_test.dart';
import 'package:ninho/data/services/auth_service.dart';

void main() {
  group('AuthService.webRedirectToFor', () {
    test('preserves GitHub Pages base path', () {
      final redirect = AuthService.webRedirectToFor(
        Uri.parse('https://kadett-preto.github.io/ninho/#/login'),
      );

      expect(redirect, 'https://kadett-preto.github.io/ninho/');
    });

    test('keeps localhost root for local OAuth', () {
      final redirect = AuthService.webRedirectToFor(
        Uri.parse('http://localhost:5454/#/login'),
      );

      expect(redirect, 'http://localhost:5454/');
    });
  });
}
