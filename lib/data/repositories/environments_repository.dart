import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/room.dart';
import '../../domain/models/room_size.dart';
import '../services/supabase_client.dart';

const _roomPhotosBucket = 'room-photos';

// Cadastro de ninho (IDEA.md §5.2). Insert atômico: o trigger
// `handle_new_environment` (migration 20260519230100) já cria o membership
// owner. Environment + rooms são criados pela Edge Function
// `create-environment`, que chama o RPC transacional
// `create_environment_with_rooms`.
class EnvironmentsRepository {
  EnvironmentsRepository();

  Future<String> createEnvironment({
    required String name,
    required String timezone,
    required List<Room> rooms,
  }) async {
    final client = SupabaseService.client;
    var session = client.auth.currentSession;
    if (session == null || session.isExpired) {
      // O token JWT é o que PostgREST usa para resolver auth.uid() nas
      // policies de RLS (§7.1).
      await client.auth.refreshSession();
      session = client.auth.currentSession;
    }
    final userId = session?.user.id;
    if (userId == null) throw StateError('Sem sessão Supabase ativa');

    final response = await client.functions.invoke(
      'create-environment',
      body: {
        'name': name,
        'timezone': timezone,
        'rooms': [
          for (final room in rooms)
            {'name': room.name, 'sizeCategory': room.size.label},
        ],
      },
    );
    final data = response.data as Map<String, dynamic>;
    final environmentId = data['environmentId'] as String;
    final createdRooms = _CreatedRoom.fromResponse(data['rooms']);

    for (var i = 0; i < rooms.length; i++) {
      final room = rooms[i];
      final draft = room.photoDraft;
      final createdRoom = createdRooms[room.name];
      if (draft == null || createdRoom == null) continue;

      try {
        final path =
            '$environmentId/rooms/${_slug(room.name)}-${DateTime.now().microsecondsSinceEpoch}-$i.${draft.extension}';
        final signedUrl = await client.storage
            .from(_roomPhotosBucket)
            .createSignedUploadUrl(path);
        await client.storage
            .from(_roomPhotosBucket)
            .uploadBinaryToSignedUrl(
              signedUrl.path,
              signedUrl.token,
              draft.bytes,
              FileOptions(
                contentType: draft.contentType,
                cacheControl: '31536000',
              ),
            );

        await client
            .from('rooms')
            .update({'photo_path': path})
            .eq('id', createdRoom.id);
      } catch (_) {
        // Foto de cômodo é opcional; ninho + cômodos já foram criados de
        // forma transacional, então uma falha de upload não deve prender o
        // usuário no cadastro.
      }
    }

    return environmentId;
  }

  // Verifica se o usuário corrente tem ao menos 1 environment_members ativo.
  // Usado pelo SplashScreen para redirecionar para o setup quando aplicável.
  Future<bool> hasActiveEnvironment() async {
    final client = SupabaseService.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return false;
    final rows = await client
        .from('environment_members')
        .select('environment_id')
        .eq('user_id', userId)
        .filter('left_at', 'is', null)
        .limit(1);
    return rows.isNotEmpty;
  }

  // Fase 11.8 (sub-task) — CRUD direto via PostgREST. RLS:
  //   * insert: membro do env.
  //   * update/delete: owner.
  Future<RoomRow> createRoom({
    required String environmentId,
    required String name,
    required String sizeCategory,
  }) async {
    final clean = name.trim();
    if (clean.isEmpty) {
      throw StateError('Nome do cômodo obrigatório.');
    }
    final row = await SupabaseService.client
        .from('rooms')
        .insert({
          'environment_id': environmentId,
          'name': clean,
          'size_category': sizeCategory.toUpperCase(),
        })
        .select('id, name, size_category')
        .single();
    return RoomRow(
      id: row['id'] as String,
      name: row['name'] as String,
      sizeCategory: row['size_category'] as String,
    );
  }

  Future<void> updateRoom({
    required String roomId,
    String? name,
    String? sizeCategory,
  }) async {
    final patch = <String, dynamic>{};
    if (name != null) {
      final clean = name.trim();
      if (clean.isEmpty) {
        throw StateError('Nome do cômodo obrigatório.');
      }
      patch['name'] = clean;
    }
    if (sizeCategory != null) {
      patch['size_category'] = sizeCategory.toUpperCase();
    }
    if (patch.isEmpty) return;
    await SupabaseService.client.from('rooms').update(patch).eq('id', roomId);
  }

  Future<void> deleteRoom(String roomId) async {
    await SupabaseService.client.from('rooms').delete().eq('id', roomId);
  }

  // Lista cômodos de um ninho. RLS filtra automaticamente — usuário não-membro
  // recebe array vazio em vez de erro (vide policy `rooms_select_member`).
  Future<List<RoomRow>> fetchRooms(String environmentId) async {
    final client = SupabaseService.client;
    final rows = await client
        .from('rooms')
        .select('id, name, size_category')
        .eq('environment_id', environmentId)
        .order('created_at');
    return [
      for (final row in rows)
        RoomRow(
          id: row['id'] as String,
          name: row['name'] as String,
          sizeCategory: row['size_category'] as String,
        ),
    ];
  }

  // Retorna o environment_id do ninho ativo do usuário. MVP: cada usuário
  // está em no máximo 1 ninho — quando a feature de múltiplos ninhos chegar,
  // este método precisa de critério explícito de "ninho corrente".
  Future<String?> fetchCurrentEnvironmentId() async {
    final client = SupabaseService.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return null;
    final rows = await client
        .from('environment_members')
        .select('environment_id')
        .eq('user_id', userId)
        .filter('left_at', 'is', null)
        .limit(1);
    if (rows.isEmpty) return null;
    return rows.first['environment_id'] as String;
  }

  // Fase 11.8: renomeia o ninho (owner only, RPC SECURITY DEFINER).
  Future<void> updateName({
    required String environmentId,
    required String name,
  }) async {
    await SupabaseService.client.rpc(
      'update_environment_name',
      params: {'p_environment_id': environmentId, 'p_name': name},
    );
  }

  // Fase 11.8: remove um membro (owner only, RPC SECURITY DEFINER).
  // Rejeita auto-remoção (caller deve usar leaveEnvironment) e outro
  // owner ativo (precisa transferir primeiro).
  Future<void> removeMember({
    required String environmentId,
    required String userId,
  }) async {
    await SupabaseService.client.rpc(
      'remove_member',
      params: {'p_environment_id': environmentId, 'p_user_id': userId},
    );
  }

  // Fase 11.8: liga modo viagem (owner only, RPC SECURITY DEFINER).
  Future<void> startVacation(String environmentId) async {
    await SupabaseService.client.rpc(
      'start_vacation',
      params: {'p_environment_id': environmentId},
    );
  }

  // Fase 11.8: desliga modo viagem (owner only, RPC SECURITY DEFINER).
  Future<void> endVacation(String environmentId) async {
    await SupabaseService.client.rpc(
      'end_vacation',
      params: {'p_environment_id': environmentId},
    );
  }

  // Lê flags `transfer_item_enabled` e `vacation_mode` (RLS: membro do env).
  Future<EnvironmentFlags> fetchFlags(String environmentId) async {
    final row = await SupabaseService.client
        .from('environments')
        .select('transfer_item_enabled, vacation_mode')
        .eq('id', environmentId)
        .maybeSingle();
    return EnvironmentFlags(
      transferItemEnabled: row?['transfer_item_enabled'] as bool? ?? true,
      vacationMode: row?['vacation_mode'] as bool? ?? false,
    );
  }

  // Fase 11.6: lista membros ativos do ninho via RPC SECURITY DEFINER
  // (caller precisa ser membro). Inclui display_name + role + joined_at.
  Future<List<EnvironmentMember>> listMembers(String environmentId) async {
    final rows = await SupabaseService.client.rpc(
      'list_environment_members',
      params: {'p_environment_id': environmentId},
    );
    if (rows == null) return const [];
    if (rows is! List) return const [];
    return [
      for (final row in rows)
        if (row is Map<String, dynamic>)
          EnvironmentMember(
            userId: row['user_id'] as String,
            displayName: row['display_name'] as String?,
            role: row['role'] as String? ?? 'member',
            joinedAt:
                DateTime.tryParse(row['joined_at'] as String? ?? '') ??
                DateTime.now(),
          ),
    ];
  }

  // Fase 11.6 / IDEA.md §5.5: transferência manual de ownership.
  // RPC SECURITY DEFINER owner-only. Caller passa a member; alvo
  // (member ativo, ≠ caller) vira owner. Audit gravado.
  Future<void> transferOwnership({
    required String environmentId,
    required String newOwnerId,
  }) async {
    await SupabaseService.client.rpc(
      'transfer_ownership',
      params: {'p_environment_id': environmentId, 'p_new_owner_id': newOwnerId},
    );
  }

  // IDEA.md §5.5 / Fase 11.7: sair do ninho. RPC SECURITY DEFINER trata
  // owner único com membros (rejeita) e owner solo (arquiva env).
  Future<LeaveEnvironmentResult> leaveEnvironment(String environmentId) async {
    final response = await SupabaseService.client.rpc(
      'leave_environment',
      params: {'p_environment_id': environmentId},
    );
    if (response is! Map) {
      throw StateError('Resposta inesperada do servidor.');
    }
    return LeaveEnvironmentResult(
      alreadyLeft: response['already_left'] as bool? ?? false,
      envArchived: response['env_archived'] as bool? ?? false,
    );
  }

  // Sumário do ninho corrente + papel do caller. RLS:
  // environments_select_member já bloqueia ninhos fora.
  Future<EnvironmentSummary?> fetchEnvironmentSummary({
    required String environmentId,
  }) async {
    final client = SupabaseService.client;
    final userId = client.auth.currentUser?.id;
    final envRow = await client
        .from('environments')
        .select('id, name, owner_id, created_at')
        .eq('id', environmentId)
        .maybeSingle();
    if (envRow == null) return null;
    String? role;
    if (userId != null) {
      final memberRow = await client
          .from('environment_members')
          .select('role, joined_at')
          .eq('environment_id', environmentId)
          .eq('user_id', userId)
          .filter('left_at', 'is', null)
          .maybeSingle();
      role = memberRow?['role'] as String?;
    }
    return EnvironmentSummary(
      id: envRow['id'] as String,
      name: envRow['name'] as String,
      ownerId: envRow['owner_id'] as String,
      role: role ?? 'member',
      createdAt:
          DateTime.tryParse(envRow['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class EnvironmentFlags {
  const EnvironmentFlags({
    required this.transferItemEnabled,
    required this.vacationMode,
  });

  final bool transferItemEnabled;
  final bool vacationMode;
}

class EnvironmentMember {
  const EnvironmentMember({
    required this.userId,
    required this.displayName,
    required this.role,
    required this.joinedAt,
  });

  final String userId;
  final String? displayName;
  final String role;
  final DateTime joinedAt;

  bool get isOwner => role == 'owner';
}

class LeaveEnvironmentResult {
  const LeaveEnvironmentResult({
    required this.alreadyLeft,
    required this.envArchived,
  });

  final bool alreadyLeft;
  final bool envArchived;
}

class EnvironmentSummary {
  const EnvironmentSummary({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.role,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String ownerId;
  final String role; // 'owner' | 'member'
  final DateTime createdAt;

  bool get isOwner => role == 'owner';
}

class RoomRow {
  const RoomRow({
    required this.id,
    required this.name,
    required this.sizeCategory,
  });

  final String id;
  final String name;
  final String sizeCategory;
}

class _CreatedRoom {
  const _CreatedRoom({required this.id, required this.name});

  final String id;
  final String name;

  static Map<String, _CreatedRoom> fromResponse(Object? value) {
    if (value is! List) return {};
    return {
      for (final item in value)
        if (item is Map && item['id'] is String && item['name'] is String)
          item['name'] as String: _CreatedRoom(
            id: item['id'] as String,
            name: item['name'] as String,
          ),
    };
  }
}

String _slug(String value) {
  final slug = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug.isEmpty ? 'comodo' : slug;
}

// Defaults usados no Step 2 (cards predefinidos) — UI/UX só.
class DefaultRoomCatalog {
  DefaultRoomCatalog._();

  static const List<Room> presets = [
    Room(name: 'Sala', size: RoomSize.m),
    Room(name: 'Quarto', size: RoomSize.m),
    Room(name: 'Cozinha', size: RoomSize.m),
    Room(name: 'Banheiro', size: RoomSize.p),
  ];
}
