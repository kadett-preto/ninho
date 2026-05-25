import '../services/supabase_client.dart';

// Convites do ninho (IDEA.md §5.3, §7.3).
//
// Edge Function `create-invite` gera token de 256 bits, calcula SHA-256 e
// chama o RPC `create_invite` que valida ownership via is_environment_owner().
// O token CLARO retornado aqui é entregue apenas UMA VEZ — depois disso o app
// só tem acesso ao hash via banco. Não persistir o token claro no cliente
// além do necessário para gerar QR/link.
class InvitesRepository {
  InvitesRepository();

  Future<Invite> createInvite({
    required String environmentId,
    int ttlDays = 7,
  }) async {
    final client = SupabaseService.client;
    final response = await client.functions.invoke(
      'create-invite',
      body: {'environmentId': environmentId, 'ttlDays': ttlDays},
    );
    final data = response.data as Map<String, dynamic>;
    return Invite(
      id: data['inviteId'] as String,
      token: data['token'] as String,
      expiresAt: DateTime.parse(data['expiresAt'] as String),
    );
  }

  // Preview de convite — leitura idempotente. Edge Function calcula sha-256
  // e chama RPC `preview_invite` (SECURITY DEFINER) que retorna metadados do
  // ninho sem consumir o token. Usado pela `AcceptInviteScreen` antes do tap
  // em "Entrar no ninho".
  //
  // Em estados inválidos (expirado/revogado/usado/não-encontrado) propaga a
  // exceção do Supabase com `details`/`message` em pt-BR — caller decide UI.
  Future<InvitePreview> previewInvite({required String token}) async {
    final client = SupabaseService.client;
    final response = await client.functions.invoke(
      'preview-invite',
      body: {'token': token},
    );
    final data = response.data as Map<String, dynamic>;
    return InvitePreview(
      environmentId: data['environmentId'] as String,
      environmentName: data['environmentName'] as String,
      environmentCreatedAt: DateTime.parse(
        data['environmentCreatedAt'] as String,
      ),
      memberCount: (data['memberCount'] as num).toInt(),
      memberNames: (data['memberNames'] as List<dynamic>)
          .cast<String>()
          .toList(),
      roomCount: (data['roomCount'] as num).toInt(),
      environmentStreak: (data['environmentStreak'] as num).toInt(),
      alreadyMember: (data['alreadyMember'] as bool?) ?? false,
    );
  }

  // Aceitação de convite por token claro. Edge Function calcula o sha-256 e
  // chama RPC `accept_invite` (SECURITY DEFINER). Cliente nunca passa hash —
  // garantia de que mesmo logs locais ficam só com o token.
  //
  // Idempotência: se o usuário já é membro do ninho, a função retorna o ninho
  // com `alreadyMember=true`, marcando o convite como usado.
  Future<AcceptedInvite> acceptInvite({required String token}) async {
    final client = SupabaseService.client;
    final response = await client.functions.invoke(
      'accept-invite',
      body: {'token': token},
    );
    final data = response.data as Map<String, dynamic>;
    return AcceptedInvite(
      environmentId: data['environmentId'] as String,
      environmentName: data['environmentName'] as String,
      alreadyMember: (data['alreadyMember'] as bool?) ?? false,
    );
  }

  // Extrai token de um link gerado por `Invite.linkFor`. Aceita tanto o
  // formato hash (`#/i/<token>` — usado pelo web em GitHub Pages) quanto o
  // path direto (`/i/<token>` — usado por QR de versões antigas). Retorna
  // null se o link não bate com nenhum formato esperado.
  static String? tokenFromLink(String link) {
    final uri = Uri.tryParse(link);
    if (uri == null) return null;
    final fragment = uri.fragment;
    if (fragment.isNotEmpty) {
      final segs = fragment
          .split('/')
          .where((s) => s.isNotEmpty)
          .toList(growable: false);
      final idx = segs.indexOf('i');
      if (idx >= 0 && idx + 1 < segs.length) {
        final tok = segs[idx + 1];
        if (tok.isNotEmpty) return tok;
      }
    }
    final segments = uri.pathSegments;
    final idx = segments.indexOf('i');
    if (idx < 0 || idx + 1 >= segments.length) return null;
    final token = segments[idx + 1];
    return token.isEmpty ? null : token;
  }
}

class AcceptedInvite {
  const AcceptedInvite({
    required this.environmentId,
    required this.environmentName,
    required this.alreadyMember,
  });

  final String environmentId;
  final String environmentName;
  final bool alreadyMember;
}

class InvitePreview {
  const InvitePreview({
    required this.environmentId,
    required this.environmentName,
    required this.environmentCreatedAt,
    required this.memberCount,
    required this.memberNames,
    required this.roomCount,
    required this.environmentStreak,
    required this.alreadyMember,
  });

  final String environmentId;
  final String environmentName;
  final DateTime environmentCreatedAt;
  final int memberCount;
  final List<String> memberNames;
  final int roomCount;
  final int environmentStreak;
  final bool alreadyMember;
}

class Invite {
  const Invite({
    required this.id,
    required this.token,
    required this.expiresAt,
  });

  final String id;
  final String token;
  final DateTime expiresAt;

  // Link compartilhável. Hash form (`#/i/<token>`) garante que o web rode em
  // hosting sem fallback SPA (ex.: GitHub Pages — sem o `#`, o servidor 404).
  // Token vai no path do fragment, não em query, p/ evitar logs intermediários
  // (§7.3). Mobile com universal link continua casando via tokenFromLink.
  String linkFor(String baseUrl) {
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return '$base/#/i/$token';
  }
}
