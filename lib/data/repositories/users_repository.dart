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

  // LGPD §5.10: lista ninhos onde o caller é owner ativo. Usada pela
  // tela de exclusão para mostrar o aviso de auto-promoção.
  Future<List<OwnedEnvironment>> listOwnedEnvironments() async {
    final rows = await SupabaseService.client.rpc('list_owned_environments');
    if (rows == null) return const [];
    if (rows is! List) return const [];
    return [
      for (final row in rows)
        if (row is Map<String, dynamic>)
          OwnedEnvironment(
            environmentId: row['environment_id'] as String,
            name: row['name'] as String,
            otherMembersCount:
                (row['other_members_count'] as num?)?.toInt() ?? 0,
          ),
    ];
  }

  // LGPD §5.10 + §5.5: soft-delete da conta. RPC trata auto-promoção
  // de owner sem transferir e arquivamento de envs solo.
  Future<AccountDeletionResult> requestAccountDeletion() async {
    final response = await SupabaseService.client.rpc(
      'request_account_deletion',
    );
    if (response is! Map) {
      throw StateError('Resposta inesperada do servidor.');
    }
    return AccountDeletionResult(
      alreadyDeleted: response['already_deleted'] as bool? ?? false,
      envsPromoted: (response['envs_promoted'] as num?)?.toInt() ?? 0,
      envsArchived: (response['envs_archived'] as num?)?.toInt() ?? 0,
    );
  }

  // LGPD §5.10: exporta dados pessoais via RPC SECURITY DEFINER.
  // RPC valida auth.uid() e filtra todas as queries pelo caller.
  // Retorna Map JSON-serializável; UI escreve em arquivo + share.
  Future<Map<String, dynamic>> exportUserData() async {
    final response = await SupabaseService.client.rpc('export_user_data');
    if (response is Map<String, dynamic>) return response;
    if (response is Map) return Map<String, dynamic>.from(response);
    throw StateError('Resposta inesperada do servidor.');
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

class OwnedEnvironment {
  const OwnedEnvironment({
    required this.environmentId,
    required this.name,
    required this.otherMembersCount,
  });

  final String environmentId;
  final String name;
  final int otherMembersCount;

  bool get isSolo => otherMembersCount == 0;
}

class AccountDeletionResult {
  const AccountDeletionResult({
    required this.alreadyDeleted,
    required this.envsPromoted,
    required this.envsArchived,
  });

  final bool alreadyDeleted;
  final int envsPromoted;
  final int envsArchived;
}
