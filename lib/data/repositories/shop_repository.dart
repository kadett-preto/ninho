import '../services/auth_service.dart';
import '../services/supabase_client.dart';

// Loja da Poeira — IDEA.md §5.8.
//
// RPCs SECURITY DEFINER já garantem antiabuso (saldo, limite semanal,
// destinatário consecutivo, item desativado). Cliente só lê + chama.

class ShopRepository {
  const ShopRepository();

  Future<int> fetchBalance({required String environmentId}) async {
    final response = await SupabaseService.client.rpc(
      'get_dust_balance',
      params: {'p_environment_id': environmentId},
    );
    if (response == null) return 0;
    if (response is int) return response;
    if (response is num) return response.toInt();
    return int.tryParse(response.toString()) ?? 0;
  }

  // Lista membros ativos do ninho exceto o caller. Como RLS em
  // public.users só expõe a própria row, retornamos apenas o user_id —
  // a UI mostra label genérica ("Morador #abc12") até existir uma view
  // de display_name compartilhada (roadmap).
  Future<List<ShopMember>> fetchOtherMembers({
    required String environmentId,
  }) async {
    final client = SupabaseService.client;
    final me = AuthService.currentUser?.id;
    final rows = await client
        .from('environment_members')
        .select('user_id, role')
        .eq('environment_id', environmentId)
        .filter('left_at', 'is', null);
    return [
      for (final row in rows as List<dynamic>)
        if (row is Map<String, dynamic> && row['user_id'] != me)
          ShopMember(
            userId: row['user_id'] as String,
            role: row['role'] as String? ?? 'member',
          ),
    ];
  }

  Future<TransferResult> transferTask({
    required String taskId,
    required String toUserId,
  }) async {
    final response = await SupabaseService.client.rpc(
      'transfer_task',
      params: {'p_task_id': taskId, 'p_to_user_id': toUserId},
    );
    return TransferResult.fromJson(response as Map<String, dynamic>);
  }

  Future<bool> setTransferItemEnabled({
    required String environmentId,
    required bool enabled,
  }) async {
    final response = await SupabaseService.client.rpc(
      'set_transfer_item_enabled',
      params: {'p_environment_id': environmentId, 'p_enabled': enabled},
    );
    return response as bool? ?? enabled;
  }

  Future<List<TransferHistoryEntry>> fetchTransferHistory({
    required String environmentId,
    int limit = 20,
  }) async {
    final rows = await SupabaseService.client
        .from('task_transfers')
        .select('id, task_id, from_user_id, to_user_id, cost_dust, created_at')
        .eq('environment_id', environmentId)
        .order('created_at', ascending: false)
        .limit(limit);
    return [
      for (final row in rows as List<dynamic>)
        TransferHistoryEntry.fromJson(row as Map<String, dynamic>),
    ];
  }
}

class ShopMember {
  const ShopMember({required this.userId, required this.role});
  final String userId;
  final String role;

  String get shortId => userId.length >= 6 ? userId.substring(0, 6) : userId;
}

class TransferResult {
  const TransferResult({
    required this.transferId,
    required this.taskId,
    required this.toUserId,
    required this.cost,
    required this.newBalance,
  });

  factory TransferResult.fromJson(Map<String, dynamic> json) {
    return TransferResult(
      transferId: json['transfer_id'] as String,
      taskId: json['task_id'] as String,
      toUserId: json['to_user_id'] as String,
      cost: (json['cost'] as num).toInt(),
      newBalance: (json['new_balance'] as num).toInt(),
    );
  }

  final String transferId;
  final String taskId;
  final String toUserId;
  final int cost;
  final int newBalance;
}

class TransferHistoryEntry {
  const TransferHistoryEntry({
    required this.id,
    required this.taskId,
    required this.fromUserId,
    required this.toUserId,
    required this.costDust,
    required this.createdAt,
  });

  factory TransferHistoryEntry.fromJson(Map<String, dynamic> json) {
    return TransferHistoryEntry(
      id: json['id'] as String,
      taskId: json['task_id'] as String,
      fromUserId: json['from_user_id'] as String,
      toUserId: json['to_user_id'] as String,
      costDust: (json['cost_dust'] as num).toInt(),
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }

  final String id;
  final String taskId;
  final String fromUserId;
  final String toUserId;
  final int costDust;
  final DateTime createdAt;
}
