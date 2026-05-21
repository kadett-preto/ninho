import '../../domain/models/room.dart';
import '../../domain/models/room_size.dart';
import '../services/supabase_client.dart';

// Cadastro de ninho (IDEA.md §5.2). Insert atômico: o trigger
// `handle_new_environment` (migration 20260519230100) já cria o membership
// owner. Aqui apenas inserimos environment + rooms numa transação lógica.
//
// TODO(task 3.7): mover para Edge Function quando precisarmos garantir
// atomicidade real entre múltiplos inserts e validações server-side.
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

    final envInsert = await client
        .from('environments')
        .insert({'owner_id': userId, 'name': name, 'timezone': timezone})
        .select('id')
        .single();
    final environmentId = envInsert['id'] as String;

    if (rooms.isNotEmpty) {
      await client.from('rooms').insert([
        for (final room in rooms)
          {
            'environment_id': environmentId,
            'name': room.name,
            'size_category': room.size.label,
            'photo_path': room.photoPath,
          },
      ]);
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
