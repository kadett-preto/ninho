import '../services/supabase_client.dart';

// Preferências e tokens de notificação — IDEA.md §5.6 + §7.8.
//
// As RPCs `register_push_token` / `revoke_push_token` (migration
// 20260522070000) tratam o token bruto via SECURITY DEFINER. O cliente
// nunca grava direto na tabela push_tokens (RLS bloqueia INSERT).

class NotificationsRepository {
  const NotificationsRepository();

  Future<NotificationPreferences> fetchPreferences() async {
    final client = SupabaseService.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sem sessão Supabase ativa');
    final rows = await client
        .from('notification_preferences')
        .select()
        .eq('user_id', userId)
        .limit(1);
    if (rows.isEmpty) {
      // Trigger users_after_insert_preferences deveria ter criado a linha.
      // Em casos raros (usuário pré-migration), criamos lazily.
      await client.from('notification_preferences').insert({'user_id': userId});
      final retry = await client
          .from('notification_preferences')
          .select()
          .eq('user_id', userId)
          .limit(1);
      return NotificationPreferences.fromJson(retry.first);
    }
    return NotificationPreferences.fromJson(rows.first);
  }

  Future<void> updatePreferences(NotificationPreferences prefs) async {
    final client = SupabaseService.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sem sessão Supabase ativa');
    await client
        .from('notification_preferences')
        .update(prefs.toUpdateMap())
        .eq('user_id', userId);
  }

  Future<void> registerPushToken({
    required String token,
    required PushPlatform platform,
    String? deviceLabel,
  }) async {
    await SupabaseService.client.rpc(
      'register_push_token',
      params: {
        'p_token': token,
        'p_platform': platform.wire,
        'p_device_label': ?deviceLabel,
      },
    );
  }

  Future<void> revokePushToken(String token) async {
    await SupabaseService.client.rpc(
      'revoke_push_token',
      params: {'p_token': token},
    );
  }
}

enum PushPlatform {
  android('android'),
  ios('ios'),
  web('web');

  const PushPlatform(this.wire);
  final String wire;
}

class NotificationPreferences {
  const NotificationPreferences({
    required this.pushEnabled,
    required this.morningTime,
    required this.afternoonTime,
    required this.eveningTime,
    required this.eventTaskTransferred,
    required this.eventNewMember,
    required this.eventFeedPhoto,
    required this.eventStreakRisk,
    required this.eventStreakBroken,
    required this.eventShopPurchase,
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      pushEnabled: json['push_enabled'] as bool? ?? true,
      morningTime: _parseTime(json['morning_time'] as String? ?? '09:00:00'),
      afternoonTime: _parseTime(
        json['afternoon_time'] as String? ?? '15:00:00',
      ),
      eveningTime: _parseTime(json['evening_time'] as String? ?? '20:00:00'),
      eventTaskTransferred: json['event_task_transferred'] as bool? ?? true,
      eventNewMember: json['event_new_member'] as bool? ?? true,
      eventFeedPhoto: json['event_feed_photo'] as bool? ?? true,
      eventStreakRisk: json['event_streak_risk'] as bool? ?? true,
      eventStreakBroken: json['event_streak_broken'] as bool? ?? true,
      eventShopPurchase: json['event_shop_purchase'] as bool? ?? true,
    );
  }

  final bool pushEnabled;
  // Tempo em minutos desde a meia-noite local.
  final int morningTime;
  final int afternoonTime;
  final int eveningTime;
  final bool eventTaskTransferred;
  final bool eventNewMember;
  final bool eventFeedPhoto;
  final bool eventStreakRisk;
  final bool eventStreakBroken;
  final bool eventShopPurchase;

  String formatTime(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'push_enabled': pushEnabled,
      'morning_time': '${formatTime(morningTime)}:00',
      'afternoon_time': '${formatTime(afternoonTime)}:00',
      'evening_time': '${formatTime(eveningTime)}:00',
      'event_task_transferred': eventTaskTransferred,
      'event_new_member': eventNewMember,
      'event_feed_photo': eventFeedPhoto,
      'event_streak_risk': eventStreakRisk,
      'event_streak_broken': eventStreakBroken,
      'event_shop_purchase': eventShopPurchase,
    };
  }

  NotificationPreferences copyWith({
    bool? pushEnabled,
    int? morningTime,
    int? afternoonTime,
    int? eveningTime,
    bool? eventTaskTransferred,
    bool? eventNewMember,
    bool? eventFeedPhoto,
    bool? eventStreakRisk,
    bool? eventStreakBroken,
    bool? eventShopPurchase,
  }) {
    return NotificationPreferences(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      morningTime: morningTime ?? this.morningTime,
      afternoonTime: afternoonTime ?? this.afternoonTime,
      eveningTime: eveningTime ?? this.eveningTime,
      eventTaskTransferred: eventTaskTransferred ?? this.eventTaskTransferred,
      eventNewMember: eventNewMember ?? this.eventNewMember,
      eventFeedPhoto: eventFeedPhoto ?? this.eventFeedPhoto,
      eventStreakRisk: eventStreakRisk ?? this.eventStreakRisk,
      eventStreakBroken: eventStreakBroken ?? this.eventStreakBroken,
      eventShopPurchase: eventShopPurchase ?? this.eventShopPurchase,
    );
  }
}

int _parseTime(String text) {
  final parts = text.split(':');
  final h = int.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0;
  final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
  return h * 60 + m;
}
