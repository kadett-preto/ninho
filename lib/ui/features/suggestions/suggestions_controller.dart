import 'package:flutter/foundation.dart';

import '../../../data/repositories/environments_repository.dart';
import '../../../data/repositories/suggestions_repository.dart';

// Estado da tela "Sugestões da IA" (Stitch 10485bb86c9040658544e1afe99d9dd9).
//
// Fluxo: load() → busca env + rooms + sugestões IA → permite toggle/edit por
// item → submit() chama RPC accept_suggested_tasks e devolve quantidade
// inserida.
enum SuggestionsStatus { idle, loading, ready, submitting, error }

class SuggestionsController extends ChangeNotifier {
  SuggestionsController({
    EnvironmentsRepository? environmentsRepository,
    SuggestionsRepository? suggestionsRepository,
  })  : _envRepo = environmentsRepository ?? EnvironmentsRepository(),
        _suggRepo = suggestionsRepository ?? SuggestionsRepository();

  final EnvironmentsRepository _envRepo;
  final SuggestionsRepository _suggRepo;

  SuggestionsStatus _status = SuggestionsStatus.idle;
  SuggestionsStatus get status => _status;

  String? _environmentId;
  String? get environmentId => _environmentId;

  String? _error;
  String? get error => _error;

  // Cômodos do ninho indexados por id — fonte da verdade para grouping +
  // exibição do nome/tamanho na UI. Vem da query RLS-filtrada.
  Map<String, RoomRow> _rooms = const {};
  Map<String, RoomRow> get rooms => _rooms;

  // Lista ordenada de items (suggestion + selected + dirty edits).
  List<SuggestionItem> _items = const [];
  List<SuggestionItem> get items => _items;

  int get selectedCount => _items.where((i) => i.selected).length;
  bool get allSelected =>
      _items.isNotEmpty && _items.every((i) => i.selected);

  Future<void> load() async {
    _status = SuggestionsStatus.loading;
    _error = null;
    notifyListeners();
    try {
      final envId = await _envRepo.fetchCurrentEnvironmentId();
      if (envId == null) {
        throw StateError('Você precisa cadastrar um ninho primeiro.');
      }
      final roomsList = await _envRepo.fetchRooms(envId);
      final roomsMap = {for (final r in roomsList) r.id: r};
      final response = await _suggRepo.fetchSuggestions(environmentId: envId);
      // Defesa: descarta sugestão cujo room_id já não existe (raro mas
      // possível se cômodo for deletado entre chamadas).
      final filtered = response.suggestions
          .where((s) => roomsMap.containsKey(s.roomId))
          .toList(growable: false);
      _environmentId = envId;
      _rooms = roomsMap;
      _items = [
        for (final s in filtered) SuggestionItem(suggestion: s, selected: true),
      ];
      _status = SuggestionsStatus.ready;
    } catch (e) {
      _status = SuggestionsStatus.error;
      _error = _humanize(e);
    } finally {
      notifyListeners();
    }
  }

  void toggle(int index, bool selected) {
    if (index < 0 || index >= _items.length) return;
    _items = List<SuggestionItem>.from(_items);
    _items[index] = _items[index].copyWith(selected: selected);
    notifyListeners();
  }

  void toggleAll() {
    final target = !allSelected;
    _items = [for (final i in _items) i.copyWith(selected: target)];
    notifyListeners();
  }

  void edit(int index, TaskSuggestion updated) {
    if (index < 0 || index >= _items.length) return;
    // Mantém o roomId original — não permitimos mover sugestão entre cômodos
    // na edição (evita confusão e simplifica RPC validation).
    final pinned = updated.copyWith();
    _items = List<SuggestionItem>.from(_items);
    _items[index] = _items[index].copyWith(suggestion: pinned);
    notifyListeners();
  }

  Future<AcceptResult?> submit() async {
    final envId = _environmentId;
    if (envId == null) return null;
    final selected = [
      for (final i in _items)
        if (i.selected) i.suggestion,
    ];
    if (selected.isEmpty) {
      _error = 'Selecione ao menos uma tarefa.';
      notifyListeners();
      return null;
    }
    _status = SuggestionsStatus.submitting;
    _error = null;
    notifyListeners();
    try {
      final result = await _suggRepo.acceptSuggestions(
        environmentId: envId,
        suggestions: selected,
      );
      _status = SuggestionsStatus.ready;
      notifyListeners();
      return result;
    } catch (e) {
      _status = SuggestionsStatus.ready;
      _error = _humanize(e);
      notifyListeners();
      return null;
    }
  }

  // Agrupa items por room_id na ordem original — UI usa isso para renderizar
  // seções por cômodo sem perder a ordem que a IA propôs.
  List<MapEntry<RoomRow, List<MapEntry<int, SuggestionItem>>>> groupedByRoom() {
    final order = <String>[];
    final byRoom = <String, List<MapEntry<int, SuggestionItem>>>{};
    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      if (!byRoom.containsKey(item.suggestion.roomId)) {
        order.add(item.suggestion.roomId);
        byRoom[item.suggestion.roomId] = [];
      }
      byRoom[item.suggestion.roomId]!.add(MapEntry(i, item));
    }
    return [
      for (final id in order)
        if (_rooms[id] != null) MapEntry(_rooms[id]!, byRoom[id]!),
    ];
  }

  String _humanize(Object e) {
    final msg = e.toString();
    if (msg.contains('54000') || msg.contains('Limite diário')) {
      return 'Você já pediu sugestões hoje. Tente de novo amanhã.';
    }
    if (msg.contains('42501')) {
      return 'Apenas o owner do ninho pode pedir sugestões.';
    }
    if (msg.contains('Ninho sem cômodos')) {
      return 'Cadastre cômodos antes de pedir sugestões.';
    }
    if (e is StateError) return e.message;
    return 'Não conseguimos carregar sugestões agora. Tente outra vez.';
  }
}

class SuggestionItem {
  const SuggestionItem({required this.suggestion, required this.selected});

  final TaskSuggestion suggestion;
  final bool selected;

  SuggestionItem copyWith({TaskSuggestion? suggestion, bool? selected}) {
    return SuggestionItem(
      suggestion: suggestion ?? this.suggestion,
      selected: selected ?? this.selected,
    );
  }
}
