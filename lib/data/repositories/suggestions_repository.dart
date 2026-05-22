import '../services/supabase_client.dart';

// Sugestões de tarefas via Claude API (IDEA.md §6.3 + §7.6).
//
// Edge Function `suggest-tasks` faz rate-limit + chama IA + sanitiza output.
// Aceitação real vai pelo RPC `accept_suggested_tasks` (SECURITY DEFINER,
// transacional, owner-only).
//
// Modelo permanece "sugestão" enquanto owner revisa/edita no cliente. Só
// vira `tasks` no banco depois do `accept`.
class SuggestionsRepository {
  SuggestionsRepository();

  Future<SuggestTasksResponse> fetchSuggestions({
    required String environmentId,
  }) async {
    final client = SupabaseService.client;
    final response = await client.functions.invoke(
      'suggest-tasks',
      body: {'environmentId': environmentId},
    );
    final data = response.data as Map<String, dynamic>;
    final raw = (data['suggestions'] as List<dynamic>? ?? const []);
    final suggestions = raw
        .whereType<Map<String, dynamic>>()
        .map(TaskSuggestion.fromJson)
        .toList(growable: false);
    return SuggestTasksResponse(suggestions: suggestions);
  }

  Future<AcceptResult> acceptSuggestions({
    required String environmentId,
    required List<TaskSuggestion> suggestions,
  }) async {
    if (suggestions.isEmpty) {
      throw ArgumentError('Selecione ao menos uma tarefa.');
    }
    final client = SupabaseService.client;
    final payload = suggestions.map((s) => s.toAcceptJson()).toList();
    final response = await client.rpc(
      'accept_suggested_tasks',
      params: {
        'p_environment_id': environmentId,
        'p_tasks': payload,
      },
    );
    final data = response as Map<String, dynamic>;
    return AcceptResult(
      insertedCount: (data['inserted_count'] as num?)?.toInt() ?? 0,
      taskIds: ((data['task_ids'] as List<dynamic>?) ?? const [])
          .whereType<String>()
          .toList(growable: false),
    );
  }
}

enum TaskDifficulty {
  mamao('mamao'),
  embacada('embacada'),
  treta('treta');

  const TaskDifficulty(this.wire);
  final String wire;

  static TaskDifficulty? tryParse(String? raw) {
    for (final d in values) {
      if (d.wire == raw) return d;
    }
    return null;
  }
}

class TaskSuggestion {
  const TaskSuggestion({
    required this.roomId,
    required this.title,
    required this.difficulty,
    required this.intervalDays,
    this.description,
  });

  factory TaskSuggestion.fromJson(Map<String, dynamic> json) {
    final difficulty = TaskDifficulty.tryParse(json['difficulty'] as String?);
    if (difficulty == null) {
      throw FormatException('Difficulty inválida: ${json['difficulty']}');
    }
    final interval = (json['interval_days'] as num?)?.toInt();
    if (interval == null || !const [1, 3, 7, 14, 30].contains(interval)) {
      throw FormatException('interval_days inválido: $interval');
    }
    return TaskSuggestion(
      roomId: json['room_id'] as String,
      title: (json['title'] as String).trim(),
      difficulty: difficulty,
      intervalDays: interval,
      description: (json['description'] as String?)?.trim(),
    );
  }

  final String roomId;
  final String title;
  final TaskDifficulty difficulty;
  final int intervalDays;
  final String? description;

  TaskSuggestion copyWith({
    String? title,
    TaskDifficulty? difficulty,
    int? intervalDays,
    String? description,
  }) {
    return TaskSuggestion(
      roomId: roomId,
      title: title ?? this.title,
      difficulty: difficulty ?? this.difficulty,
      intervalDays: intervalDays ?? this.intervalDays,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toAcceptJson() => {
        'room_id': roomId,
        'title': title,
        if (description != null && description!.isNotEmpty)
          'description': description,
        'difficulty': difficulty.wire,
        'interval_days': intervalDays,
      };
}

class SuggestTasksResponse {
  const SuggestTasksResponse({required this.suggestions});
  final List<TaskSuggestion> suggestions;
}

class AcceptResult {
  const AcceptResult({required this.insertedCount, required this.taskIds});
  final int insertedCount;
  final List<String> taskIds;
}
