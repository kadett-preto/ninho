import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';

// Wrapper sobre Supabase Auth (IDEA.md §5.1, §7.2). Centraliza:
//   - login Google (e futuro Apple, task 2.5)
//   - logout (task 2.8) com invalidação de sessão local
//   - stream de mudanças de auth (usado pelo GoRouter para gates)
//
// Para clientes mobile (iOS/Android), o redirect usa o scheme custom
// `io.supabase.ninho://login-callback`. No web, redireciona p/ localhost.
class AuthService {
  AuthService._();

  static SupabaseClient get _client => SupabaseService.client;

  static Stream<AuthState> get onAuthStateChange =>
      _client.auth.onAuthStateChange;

  // Os getters abaixo são tolerantes a Supabase não-inicializado (útil em
  // widget tests). Em runtime real, SupabaseService.init garante que
  // `Supabase.instance` esteja disponível.
  static Session? get currentSession {
    try {
      return _client.auth.currentSession;
    } catch (_) {
      return null;
    }
  }

  static User? get currentUser {
    try {
      return _client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  static String _redirectTo() {
    if (kIsWeb) {
      // Em dev usamos localhost:5454; em prod o Site URL configurado no
      // Supabase já assume a URL correta. Passando null deixa o SDK usar
      // a URL atual da página, que é exatamente o que queremos.
      return Uri.base.origin;
    }
    return 'io.supabase.ninho://login-callback/';
  }

  static Future<bool> signInWithGoogle() async {
    final redirect = _redirectTo();
    debugPrint('[auth] signInWithGoogle redirectTo=$redirect');
    return _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirect,
    );
  }

  static Future<bool> signInWithApple() async {
    // TODO(task 2.5): em iOS usar signInWithApple nativo via sign_in_with_apple.
    return _client.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: _redirectTo(),
    );
  }

  static Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
