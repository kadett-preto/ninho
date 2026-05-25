import '../services/auth_service.dart';
import '../services/supabase_client.dart';

// Snapshot de streaks (IDEA.md §5.7).
//
// `streaks` é populada pelo cron `evaluate_environment_streaks` à meia-noite
// local. Cliente só lê; RLS expõe: streak do ambiente + a do próprio usuário.
class StreaksRepository {
  const StreaksRepository();

  Future<StreakSummary> fetchSummary({required String environmentId}) async {
    final client = SupabaseService.client;
    final userId = AuthService.currentUser?.id;
    final rows = await client
        .from('streaks')
        .select('kind, user_id, current_count, best_count, freezes_left_month')
        .eq('environment_id', environmentId);

    int? userStreak;
    int? userBest;
    int? envStreak;
    int? envBest;
    int? freezesLeft;
    for (final row in rows as List<dynamic>) {
      if (row is! Map<String, dynamic>) continue;
      final kind = row['kind'] as String?;
      final count = (row['current_count'] as num?)?.toInt() ?? 0;
      final best = (row['best_count'] as num?)?.toInt() ?? 0;
      if (kind == 'environment') {
        envStreak = count;
        envBest = best;
      } else if (kind == 'user' && row['user_id'] == userId) {
        userStreak = count;
        userBest = best;
        freezesLeft = (row['freezes_left_month'] as num?)?.toInt();
      }
    }
    return StreakSummary(
      userCount: userStreak ?? 0,
      userBest: userBest ?? 0,
      environmentCount: envStreak ?? 0,
      environmentBest: envBest ?? 0,
      freezesLeftMonth: freezesLeft ?? 0,
    );
  }
}

class StreakSummary {
  const StreakSummary({
    required this.userCount,
    required this.userBest,
    required this.environmentCount,
    required this.environmentBest,
    required this.freezesLeftMonth,
  });

  final int userCount;
  final int userBest;
  final int environmentCount;
  final int environmentBest;
  final int freezesLeftMonth;
}
