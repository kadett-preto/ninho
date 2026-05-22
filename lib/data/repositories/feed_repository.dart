import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../services/supabase_client.dart';
import 'suggestions_repository.dart' show TaskDifficulty;

const _taskCompletionPhotosBucket = 'task-completion-photos';

class FeedRepository {
  const FeedRepository();

  Future<String> fetchEnvironmentName({required String environmentId}) async {
    final rows = await SupabaseService.client
        .from('environments')
        .select('name')
        .eq('id', environmentId)
        .limit(1);
    if (rows.isEmpty) return 'Seu ninho';
    return rows.first['name'] as String? ?? 'Seu ninho';
  }

  Future<List<FeedTimelineItem>> fetchTimeline({
    required String environmentId,
    int limit = 30,
  }) async {
    final client = SupabaseService.client;
    final rows = await client
        .from('feed_events')
        .select('id, actor_id, event_type, payload, created_at')
        .eq('environment_id', environmentId)
        .order('created_at', ascending: false)
        .limit(limit);

    final items = <FeedTimelineItem>[];
    for (final row in rows as List<dynamic>) {
      final event = row as Map<String, dynamic>;
      final payload = _asMap(event['payload']);
      final actorId = event['actor_id'] as String?;
      final createdAt =
          DateTime.tryParse(event['created_at'] as String? ?? '')?.toLocal() ??
          DateTime.now();
      final photoPath = payload['photo_path'] as String?;
      final photoUrl = await _signedPhotoUrl(client, photoPath);
      items.add(
        FeedTimelineItem(
          id: event['id'] as String,
          eventType: event['event_type'] as String? ?? 'event',
          actorId: actorId,
          actorLabel: _actorLabel(actorId),
          createdAt: createdAt,
          title:
              payload['task_title'] as String? ?? payload['title'] as String?,
          caption: payload['caption'] as String? ?? _defaultCaption(null),
          difficulty: TaskDifficulty.tryParse(payload['difficulty'] as String?),
          photoUrl: photoUrl,
          heartCount: (payload['heart_count'] as num?)?.toInt() ?? 0,
          celebrationCount:
              (payload['celebration_count'] as num?)?.toInt() ?? 0,
          summary: payload['summary'] as String?,
          memberName: payload['member_name'] as String?,
          streakCount: (payload['streak_count'] as num?)?.toInt(),
        ),
      );
    }
    return items;
  }

  RealtimeChannel watchTimeline({
    required String environmentId,
    required void Function() onChange,
  }) {
    return SupabaseService.client
        .channel('feed:$environmentId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'feed_events',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'environment_id',
            value: environmentId,
          ),
          callback: (_) => onChange(),
        )
        .subscribe();
  }

  Future<FeedPhotoDetail> fetchPhotoDetail({required String eventId}) async {
    final client = SupabaseService.client;
    final rows = await client
        .from('feed_events')
        .select('id, environment_id, actor_id, event_type, payload, created_at')
        .eq('id', eventId)
        .limit(1);
    final list = rows as List<dynamic>;
    if (list.isEmpty) throw StateError('Evento do mural não encontrado.');

    final event = list.first as Map<String, dynamic>;
    final payload = _asMap(event['payload']);
    final taskId = payload['task_id'] as String?;
    final completionId = payload['completion_id'] as String?;
    if (taskId == null || completionId == null) {
      throw StateError('Evento do mural sem foto vinculada.');
    }

    final taskRows = await client
        .from('tasks')
        .select('id, title, difficulty, room_id, rooms(name)')
        .eq('id', taskId)
        .limit(1);
    final task = taskRows.isEmpty ? <String, dynamic>{} : taskRows.first;

    final completionRows = await client
        .from('task_completions')
        .select('id, completed_at, completed_by, photo_path')
        .eq('id', completionId)
        .limit(1);
    final completion = completionRows.isEmpty
        ? <String, dynamic>{}
        : completionRows.first;

    final photoPath =
        completion['photo_path'] as String? ?? payload['photo_path'] as String?;
    final photoUrl = await _signedPhotoUrl(client, photoPath);
    final actorId =
        event['actor_id'] as String? ?? completion['completed_by'] as String?;
    final actorLabel = _actorLabel(actorId);

    final rooms = task['rooms'];
    final roomName = rooms is Map<String, dynamic>
        ? rooms['name'] as String?
        : null;
    final completedAt = DateTime.tryParse(
      completion['completed_at'] as String? ??
          event['created_at'] as String? ??
          '',
    );

    return FeedPhotoDetail(
      eventId: event['id'] as String,
      taskId: taskId,
      completionId: completionId,
      actorId: actorId,
      actorLabel: actorLabel,
      createdAt: completedAt?.toLocal() ?? DateTime.now(),
      photoUrl: photoUrl,
      caption: payload['caption'] as String? ?? _defaultCaption(roomName),
      taskTitle:
          task['title'] as String? ?? payload['task_title'] as String? ?? '',
      roomName: roomName,
      difficulty:
          TaskDifficulty.tryParse(
            task['difficulty'] as String? ?? payload['difficulty'] as String?,
          ) ??
          TaskDifficulty.mamao,
      heartCount: (payload['heart_count'] as num?)?.toInt() ?? 0,
      celebrationCount: (payload['celebration_count'] as num?)?.toInt() ?? 0,
      comments: _commentsFromPayload(payload['comments']),
    );
  }

  Future<String?> _signedPhotoUrl(SupabaseClient client, String? path) async {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return client.storage
        .from(_taskCompletionPhotosBucket)
        .createSignedUrl(path, 60 * 60);
  }
}

class FeedTimelineItem {
  const FeedTimelineItem({
    required this.id,
    required this.eventType,
    required this.actorId,
    required this.actorLabel,
    required this.createdAt,
    required this.title,
    required this.caption,
    required this.difficulty,
    required this.photoUrl,
    required this.heartCount,
    required this.celebrationCount,
    required this.summary,
    required this.memberName,
    required this.streakCount,
  });

  final String id;
  final String eventType;
  final String? actorId;
  final String actorLabel;
  final DateTime createdAt;
  final String? title;
  final String caption;
  final TaskDifficulty? difficulty;
  final String? photoUrl;
  final int heartCount;
  final int celebrationCount;
  final String? summary;
  final String? memberName;
  final int? streakCount;

  bool get hasPhoto => photoUrl != null;
  bool get isCompletedTask => eventType == 'task.completed';
  bool get isWeeklySummary => eventType == 'weekly.summary';
  bool get isNewMember => eventType == 'member.joined';
  bool get isStreak => eventType == 'streak.milestone';
}

class FeedPhotoDetail {
  const FeedPhotoDetail({
    required this.eventId,
    required this.taskId,
    required this.completionId,
    required this.actorId,
    required this.actorLabel,
    required this.createdAt,
    required this.photoUrl,
    required this.caption,
    required this.taskTitle,
    required this.roomName,
    required this.difficulty,
    required this.heartCount,
    required this.celebrationCount,
    required this.comments,
  });

  final String eventId;
  final String taskId;
  final String completionId;
  final String? actorId;
  final String actorLabel;
  final DateTime createdAt;
  final String? photoUrl;
  final String caption;
  final String taskTitle;
  final String? roomName;
  final TaskDifficulty difficulty;
  final int heartCount;
  final int celebrationCount;
  final List<FeedComment> comments;
}

class FeedComment {
  const FeedComment({
    required this.authorLabel,
    required this.body,
    required this.createdAt,
  });

  final String authorLabel;
  final String body;
  final DateTime createdAt;
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return {};
}

List<FeedComment> _commentsFromPayload(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map)
        FeedComment(
          authorLabel: item['author'] as String? ?? 'Morador',
          body: item['body'] as String? ?? '',
          createdAt:
              DateTime.tryParse(
                item['created_at'] as String? ?? '',
              )?.toLocal() ??
              DateTime.now(),
        ),
  ];
}

String _shortId(String value) =>
    value.length >= 6 ? value.substring(0, 6) : value;

String _actorLabel(String? actorId) {
  if (actorId == null) return 'Morador';
  final currentUser = AuthService.currentUser;
  if (actorId == currentUser?.id) {
    return currentUser?.email?.split('@').first ?? 'Você';
  }
  return 'Morador #${_shortId(actorId)}';
}

String _defaultCaption(String? roomName) {
  if (roomName == null || roomName.isEmpty) return 'Tarefa concluída.';
  return '$roomName brilhando!';
}
