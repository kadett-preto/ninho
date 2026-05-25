import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Base URL público pra montar links de convite (§7.3).
//
// Ordem de resolução:
//   1. INVITE_BASE_URL no .env (override explícito em qualquer ambiente).
//   2. Web: deriva de Uri.base (origin + base path do <base href>).
//   3. Fallback: 'https://ninho.app' (placeholder — mobile fora do .env).
//
// Links usam hash (`#/i/<token>`) porque o web hosteado em GitHub Pages
// não tem fallback SPA — sem o `#`, o servidor 404 antes do Flutter rodar.
class InviteLinks {
  InviteLinks._();

  static String resolveBaseUrl() {
    final env = _envOrNull('INVITE_BASE_URL');
    if (env != null && env.isNotEmpty) return _stripTrailingSlash(env);
    if (kIsWeb) {
      final origin = Uri.base.origin;
      final path = _stripTrailingSlash(Uri.base.path);
      return '$origin$path';
    }
    return 'https://ninho.app';
  }

  static String shareableLink(String token) => '${resolveBaseUrl()}/#/i/$token';

  static String? _envOrNull(String key) {
    if (!dotenv.isInitialized) return null;
    final v = dotenv.env[key]?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  static String _stripTrailingSlash(String s) =>
      s.endsWith('/') ? s.substring(0, s.length - 1) : s;
}
