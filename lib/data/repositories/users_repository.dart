import '../services/supabase_client.dart';

// Acesso à tabela public.users (IDEA.md §5.10).
//
// RLS já restringe SELECT/UPDATE ao próprio id (`auth.uid()`). Auditoria de
// LGPD é gravada por trigger no banco (ver migration
// 20260520120000_lgpd_consent.sql).
class UsersRepository {
  UsersRepository({this.tableName = 'users'});

  final String tableName;

  Future<void> updateLgpdConsent({
    required bool notifications,
    required bool analytics,
  }) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Sem sessão Supabase ativa');
    }
    await SupabaseService.client
        .from(tableName)
        .update({
          'lgpd_consent_at': DateTime.now().toUtc().toIso8601String(),
          'notifications_consent': notifications,
          'analytics_consent': analytics,
        })
        .eq('id', userId);
  }

  // Retorna true se o usuário corrente já aceitou os termos da LGPD.
  // Usado pelo SplashScreen para decidir entre /consent e /home.
  Future<bool> hasLgpdConsent() async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return false;
    final row = await SupabaseService.client
        .from(tableName)
        .select('lgpd_consent_at')
        .eq('id', userId)
        .maybeSingle();
    return row != null && row['lgpd_consent_at'] != null;
  }

  // Lê perfil do user logado: display_name + email (Supabase auth).
  // RLS: users_select_self → só o próprio id.
  Future<UserProfileSnapshot?> fetchSelf() async {
    final client = SupabaseService.client;
    final user = client.auth.currentUser;
    if (user == null) return null;
    final row = await client
        .from(tableName)
        .select('id, display_name')
        .eq('id', user.id)
        .maybeSingle();
    return UserProfileSnapshot(
      id: user.id,
      displayName: row?['display_name'] as String?,
      email: user.email,
    );
  }
}

class UserProfileSnapshot {
  const UserProfileSnapshot({
    required this.id,
    required this.displayName,
    required this.email,
  });

  final String id;
  final String? displayName;
  final String? email;
}
