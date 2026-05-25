import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/room_photo_draft.dart';
import '../services/supabase_client.dart';
import 'suggestions_repository.dart' show TaskDifficulty;

const _taskCompletionPhotosBucket = 'task-completion-photos';

class TasksRepository {
  const TasksRepository();

  // Lista tasks ativas (archived_at is null) do ninho com rooms embedados e
  // as completions dos últimos 7 dias para derivar hoje/semana no cliente.
  // RLS garante isolamento — esta query só retorna tasks de ninhos onde o
  // auth.uid() é membro ativo (§7.1).
  Future<List<TaskListItem>> fetchTaskList({
    required String environmentId,
  }) async {
    final client = SupabaseService.client;
    final sinceUtc = DateTime.now().toUtc().subtract(const Duration(days: 7));
    final rows = await client
        .from('tasks')
        .select(
          'id, title, room_id, difficulty, assignee_id, recurrence_rule, '
          'start_date, rooms(name), '
          'task_completions(id, completed_at, completed_by)',
        )
        .eq('environment_id', environmentId)
        .filter('archived_at', 'is', null)
        .gte('task_completions.completed_at', sinceUtc.toIso8601String())
        .order('created_at');
    return [
      for (final row in rows as List<dynamic>)
        TaskListItem.fromJson(row as Map<String, dynamic>),
    ];
  }

  Future<String> uploadCompletionPhoto({
    required String taskId,
    required RoomPhotoDraft draft,
  }) async {
    final client = SupabaseService.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sem sessão Supabase ativa');

    final rows = await client
        .from('tasks')
        .select('environment_id')
        .eq('id', taskId)
        .limit(1);
    if (rows.isEmpty) throw StateError('Task não encontrada');

    final environmentId = rows.first['environment_id'] as String;
    final path =
        '$environmentId/task-completions/$taskId/$userId-${DateTime.now().microsecondsSinceEpoch}.${draft.extension}';
    final signedUrl = await client.storage
        .from(_taskCompletionPhotosBucket)
        .createSignedUploadUrl(path);
    await client.storage
        .from(_taskCompletionPhotosBucket)
        .uploadBinaryToSignedUrl(
          signedUrl.path,
          signedUrl.token,
          draft.bytes,
          FileOptions(contentType: draft.contentType, cacheControl: '31536000'),
        );
    return path;
  }

  // Carrega 1 task (com room embedado). RLS filtra; usuário não-membro
  // recebe lista vazia → StateError aqui.
  Future<TaskListItem> fetchTask({required String taskId}) async {
    final client = SupabaseService.client;
    final rows = await client
        .from('tasks')
        .select(
          'id, title, room_id, difficulty, assignee_id, recurrence_rule, '
          'start_date, rooms(name), '
          'task_completions(id, completed_at, completed_by)',
        )
        .eq('id', taskId)
        .filter('archived_at', 'is', null)
        .limit(1);
    final list = rows as List<dynamic>;
    if (list.isEmpty) throw StateError('Tarefa não encontrada');
    return TaskListItem.fromJson(list.first as Map<String, dynamic>);
  }

  // Insert direto via PostgREST. RLS exige created_by = auth.uid() e
  // is_environment_member(environment_id). Não vai para Edge Function
  // por simplicidade — não há rate-limit nem agregação para somar.
  Future<String> createTask({
    required String environmentId,
    required String title,
    required TaskDifficulty difficulty,
    required DateTime startDate,
    String? description,
    String? roomId,
    String? assigneeId,
    String? recurrenceRule,
  }) async {
    final client = SupabaseService.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sem sessão Supabase ativa');
    final row = {
      'environment_id': environmentId,
      'title': title.trim(),
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      'room_id': ?roomId,
      'assignee_id': ?assigneeId,
      'difficulty': difficulty.wire,
      'start_date':
          '${startDate.year.toString().padLeft(4, '0')}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}',
      if (recurrenceRule != null && recurrenceRule.isNotEmpty)
        'recurrence_rule': recurrenceRule,
      'created_by': userId,
    };
    final response = await client
        .from('tasks')
        .insert(row)
        .select('id')
        .single();
    return response['id'] as String;
  }

  // Update via PostgREST. RLS: owner ou (member + assignee_id = auth.uid()).
  Future<void> updateTask({
    required String taskId,
    String? title,
    TaskDifficulty? difficulty,
    DateTime? startDate,
    String? description,
    String? roomId,
    String? assigneeId,
    String? recurrenceRule,
    bool clearAssignee = false,
    bool clearRoom = false,
    bool clearRecurrence = false,
    bool clearDescription = false,
  }) async {
    final updates = <String, dynamic>{};
    if (title != null) updates['title'] = title.trim();
    if (difficulty != null) updates['difficulty'] = difficulty.wire;
    if (startDate != null) {
      updates['start_date'] =
          '${startDate.year.toString().padLeft(4, '0')}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
    }
    if (clearRoom) {
      updates['room_id'] = null;
    } else if (roomId != null) {
      updates['room_id'] = roomId;
    }
    if (clearAssignee) {
      updates['assignee_id'] = null;
    } else if (assigneeId != null) {
      updates['assignee_id'] = assigneeId;
    }
    if (clearRecurrence) {
      updates['recurrence_rule'] = null;
    } else if (recurrenceRule != null) {
      updates['recurrence_rule'] = recurrenceRule;
    }
    if (clearDescription) {
      updates['description'] = null;
    } else if (description != null) {
      updates['description'] = description.trim();
    }
    if (updates.isEmpty) return;
    await SupabaseService.client.from('tasks').update(updates).eq('id', taskId);
  }

  // Soft archive via archived_at. RLS: só owner pode setar (policy delete) —
  // delete_owner. Reusa update path para consistência com Fase 11.
  Future<void> archiveTask({required String taskId}) async {
    await SupabaseService.client
        .from('tasks')
        .update({'archived_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', taskId);
  }

  Future<CompleteTaskResult> completeTask({
    required String taskId,
    String? photoPath,
  }) async {
    final response = await SupabaseService.client.rpc(
      'complete_task',
      params: {'p_task_id': taskId, 'p_photo_path': photoPath},
    );
    return CompleteTaskResult.fromJson(response as Map<String, dynamic>);
  }
}

class TaskListItem {
  TaskListItem({
    required this.id,
    required this.title,
    required this.roomId,
    required this.roomName,
    required this.difficulty,
    required this.assigneeId,
    required this.recurrenceRule,
    required this.recentCompletions,
    this.startDate,
  });

  factory TaskListItem.fromJson(Map<String, dynamic> json) {
    final difficulty =
        TaskDifficulty.tryParse(json['difficulty'] as String?) ??
        TaskDifficulty.mamao;
    final completionsRaw =
        json['task_completions'] as List<dynamic>? ?? const [];
    final completions = <TaskCompletionRef>[];
    for (final item in completionsRaw) {
      if (item is! Map<String, dynamic>) continue;
      final ts = DateTime.tryParse(item['completed_at'] as String? ?? '');
      if (ts == null) continue;
      completions.add(
        TaskCompletionRef(
          id: item['id'] as String,
          completedAt: ts.toLocal(),
          completedBy: item['completed_by'] as String?,
        ),
      );
    }
    completions.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    final rooms = json['rooms'];
    String? roomName;
    if (rooms is Map<String, dynamic>) {
      roomName = rooms['name'] as String?;
    }
    return TaskListItem(
      id: json['id'] as String,
      title: json['title'] as String,
      roomId: json['room_id'] as String?,
      roomName: roomName,
      difficulty: difficulty,
      assigneeId: json['assignee_id'] as String?,
      recurrenceRule: json['recurrence_rule'] as String?,
      startDate: _parseDate(json['start_date'] as String?),
      recentCompletions: completions,
    );
  }

  final String id;
  final String title;
  final String? roomId;
  final String? roomName;
  final TaskDifficulty difficulty;
  final String? assigneeId;
  final String? recurrenceRule;
  final DateTime? startDate;
  final List<TaskCompletionRef> recentCompletions;

  // Intervalo em dias da RRULE FREQ=DAILY;INTERVAL=N. null se sem recorrência.
  int? get intervalDays {
    final rrule = recurrenceRule;
    if (rrule == null || rrule.isEmpty) return null;
    final match = RegExp(r'INTERVAL=(\d+)').firstMatch(rrule);
    if (match == null) return 1; // FREQ=DAILY sem INTERVAL = diária
    return int.tryParse(match.group(1)!) ?? 1;
  }

  // Task ativa em [date] se: tem startDate, é diária (intervalDays==1) OU
  // (date - startDate).days % intervalDays == 0. Sem recorrência: ativa só
  // no startDate. Sem startDate: sempre ativa (fallback conservador).
  bool isExpectedOn(DateTime date) {
    final start = startDate;
    if (start == null) return true;
    final d = DateTime(date.year, date.month, date.day);
    final s = DateTime(start.year, start.month, start.day);
    if (d.isBefore(s)) return false;
    final delta = d.difference(s).inDays;
    final interval = intervalDays;
    if (interval == null) return delta == 0;
    if (interval <= 1) return true;
    return delta % interval == 0;
  }

  bool completedOn(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    for (final c in recentCompletions) {
      if (!c.completedAt.isBefore(start) && c.completedAt.isBefore(end)) {
        return true;
      }
    }
    return false;
  }
}

DateTime? _parseDate(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  // DATE columns vêm como YYYY-MM-DD sem hora.
  return DateTime.tryParse(raw.length == 10 ? '${raw}T00:00:00' : raw);
}

class TaskCompletionRef {
  const TaskCompletionRef({
    required this.id,
    required this.completedAt,
    required this.completedBy,
  });

  final String id;
  final DateTime completedAt;
  final String? completedBy;
}

class CompleteTaskResult {
  const CompleteTaskResult({
    required this.completionId,
    required this.alreadyCompleted,
    required this.rewardDelta,
    required this.notificationSuppressedCount,
    this.feedEventId,
  });

  factory CompleteTaskResult.fromJson(Map<String, dynamic> json) {
    return CompleteTaskResult(
      completionId: json['completion_id'] as String,
      alreadyCompleted: json['already_completed'] as bool? ?? false,
      rewardDelta: (json['reward_delta'] as num?)?.toInt() ?? 0,
      notificationSuppressedCount:
          (json['notification_suppressed_count'] as num?)?.toInt() ?? 0,
      feedEventId: json['feed_event_id'] as String?,
    );
  }

  final String completionId;
  final bool alreadyCompleted;
  final int rewardDelta;
  final int notificationSuppressedCount;
  final String? feedEventId;
}
