import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ninho/data/repositories/environments_repository.dart';
import 'package:ninho/data/repositories/suggestions_repository.dart';
import 'package:ninho/ui/core/theme.dart';
import 'package:ninho/ui/features/suggestions/suggestions_screen.dart';

class _FakeEnvRepo extends EnvironmentsRepository {
  _FakeEnvRepo({
    this.envId = 'env-1',
    this.rooms = const [],
  });
  final String? envId;
  final List<RoomRow> rooms;

  @override
  Future<String?> fetchCurrentEnvironmentId() async => envId;

  @override
  Future<List<RoomRow>> fetchRooms(String environmentId) async => rooms;
}

class _FakeSuggRepo extends SuggestionsRepository {
  _FakeSuggRepo({this.suggestions = const [], this.error});
  final List<TaskSuggestion> suggestions;
  final Object? error;
  AcceptResult? lastAccept;
  List<TaskSuggestion>? lastSubmitted;

  @override
  Future<SuggestTasksResponse> fetchSuggestions({
    required String environmentId,
  }) async {
    if (error != null) throw error!;
    return SuggestTasksResponse(suggestions: suggestions);
  }

  @override
  Future<AcceptResult> acceptSuggestions({
    required String environmentId,
    required List<TaskSuggestion> suggestions,
  }) async {
    lastSubmitted = suggestions;
    final r = AcceptResult(
      insertedCount: suggestions.length,
      taskIds: [for (var i = 0; i < suggestions.length; i++) 't$i'],
    );
    lastAccept = r;
    return r;
  }
}

void _setMobile(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _wrap(SuggestionsScreen screen) {
  final router = GoRouter(
    initialLocation: '/test',
    routes: [
      GoRoute(path: '/test', builder: (_, _) => screen),
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('HOME')),
      ),
    ],
  );
  return MaterialApp.router(theme: NinhoTheme.light(), routerConfig: router);
}

void main() {
  testWidgets('headline + 2 cômodos com 3 sugestões + selectedCount=3', (
    tester,
  ) async {
    _setMobile(tester);
    final envRepo = _FakeEnvRepo(
      rooms: const [
        RoomRow(id: 'r-cozinha', name: 'Cozinha', sizeCategory: 'G'),
        RoomRow(id: 'r-sala', name: 'Sala', sizeCategory: 'M'),
      ],
    );
    final suggRepo = _FakeSuggRepo(
      suggestions: const [
        TaskSuggestion(
          roomId: 'r-cozinha',
          title: 'Limpar fogão',
          difficulty: TaskDifficulty.mamao,
          intervalDays: 7,
        ),
        TaskSuggestion(
          roomId: 'r-cozinha',
          title: 'Organizar despensa',
          difficulty: TaskDifficulty.embacada,
          intervalDays: 30,
        ),
        TaskSuggestion(
          roomId: 'r-sala',
          title: 'Tirar pó dos móveis',
          difficulty: TaskDifficulty.treta,
          intervalDays: 14,
        ),
      ],
    );

    await tester.pumpWidget(
      _wrap(
        SuggestionsScreen(
          environmentsRepository: envRepo,
          suggestionsRepository: suggRepo,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sugestões da IA'), findsOneWidget);
    expect(find.text('Cozinha'), findsOneWidget);
    expect(find.text('Sala'), findsOneWidget);
    expect(find.text('Limpar fogão'), findsOneWidget);
    expect(find.text('Organizar despensa'), findsOneWidget);
    expect(find.text('Tirar pó dos móveis'), findsOneWidget);
    // 3 cards, 3 selected por default
    expect(find.text('Adicionar 3 tarefas'), findsOneWidget);
  });

  testWidgets('desmarcar uma sugestão atualiza contador', (tester) async {
    _setMobile(tester);
    final suggRepo = _FakeSuggRepo(
      suggestions: const [
        TaskSuggestion(
          roomId: 'r-x',
          title: 'X',
          difficulty: TaskDifficulty.mamao,
          intervalDays: 1,
        ),
        TaskSuggestion(
          roomId: 'r-x',
          title: 'Y',
          difficulty: TaskDifficulty.treta,
          intervalDays: 30,
        ),
      ],
    );
    await tester.pumpWidget(
      _wrap(
        SuggestionsScreen(
          environmentsRepository: _FakeEnvRepo(
            rooms: const [
              RoomRow(id: 'r-x', name: 'Quarto', sizeCategory: 'M'),
            ],
          ),
          suggestionsRepository: suggRepo,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Adicionar 2 tarefas'), findsOneWidget);

    await tester.tap(find.byKey(const Key('suggestion_check_0')));
    await tester.pump();

    expect(find.text('Adicionar 1 tarefa'), findsOneWidget);
  });

  testWidgets('toggle all desmarca tudo + submit fica disabled', (
    tester,
  ) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(
        SuggestionsScreen(
          environmentsRepository: _FakeEnvRepo(
            rooms: const [
              RoomRow(id: 'r-x', name: 'Sala', sizeCategory: 'M'),
            ],
          ),
          suggestionsRepository: _FakeSuggRepo(
            suggestions: const [
              TaskSuggestion(
                roomId: 'r-x',
                title: 'X',
                difficulty: TaskDifficulty.mamao,
                intervalDays: 7,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('suggestions_toggle_all')));
    await tester.pump();

    expect(find.text('Adicionar 0 tarefas'), findsOneWidget);
    expect(find.text('Selecionar todas'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('suggestions_submit')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('submit chama acceptSuggestions com items selecionados', (
    tester,
  ) async {
    _setMobile(tester);
    final suggRepo = _FakeSuggRepo(
      suggestions: const [
        TaskSuggestion(
          roomId: 'r-x',
          title: 'A',
          difficulty: TaskDifficulty.mamao,
          intervalDays: 1,
        ),
        TaskSuggestion(
          roomId: 'r-x',
          title: 'B',
          difficulty: TaskDifficulty.embacada,
          intervalDays: 7,
        ),
      ],
    );
    await tester.pumpWidget(
      _wrap(
        SuggestionsScreen(
          environmentsRepository: _FakeEnvRepo(
            rooms: const [
              RoomRow(id: 'r-x', name: 'Cozinha', sizeCategory: 'G'),
            ],
          ),
          suggestionsRepository: suggRepo,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Desmarca o segundo, só o primeiro vai
    await tester.tap(find.byKey(const Key('suggestion_check_1')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('suggestions_submit')));
    await tester.pumpAndSettle();

    expect(suggRepo.lastSubmitted, isNotNull);
    expect(suggRepo.lastSubmitted!.length, 1);
    expect(suggRepo.lastSubmitted!.first.title, 'A');
    // Após submit → navigate /home
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('rate-limit do servidor vira mensagem amigável', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(
        SuggestionsScreen(
          environmentsRepository: _FakeEnvRepo(),
          suggestionsRepository: _FakeSuggRepo(
            error: Exception('PostgrestException: 54000 Limite diário'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Você já pediu sugestões hoje'),
      findsOneWidget,
    );
  });

  testWidgets('sem ninho cadastrado mostra erro', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(
        SuggestionsScreen(
          environmentsRepository: _FakeEnvRepo(envId: null),
          suggestionsRepository: _FakeSuggRepo(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Você precisa cadastrar um ninho'),
      findsOneWidget,
    );
  });

  testWidgets('descarta sugestão com room_id desconhecido', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(
        SuggestionsScreen(
          environmentsRepository: _FakeEnvRepo(
            rooms: const [
              RoomRow(id: 'r-valido', name: 'Cozinha', sizeCategory: 'M'),
            ],
          ),
          suggestionsRepository: _FakeSuggRepo(
            suggestions: const [
              TaskSuggestion(
                roomId: 'r-valido',
                title: 'OK',
                difficulty: TaskDifficulty.mamao,
                intervalDays: 1,
              ),
              TaskSuggestion(
                roomId: 'r-fantasma',
                title: 'NUNCA',
                difficulty: TaskDifficulty.treta,
                intervalDays: 30,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('OK'), findsOneWidget);
    expect(find.text('NUNCA'), findsNothing);
    expect(find.text('Adicionar 1 tarefa'), findsOneWidget);
  });

  testWidgets('editar sugestão atualiza título', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(
        SuggestionsScreen(
          environmentsRepository: _FakeEnvRepo(
            rooms: const [
              RoomRow(id: 'r-x', name: 'Sala', sizeCategory: 'M'),
            ],
          ),
          suggestionsRepository: _FakeSuggRepo(
            suggestions: const [
              TaskSuggestion(
                roomId: 'r-x',
                title: 'Original',
                difficulty: TaskDifficulty.mamao,
                intervalDays: 7,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('suggestion_edit_0')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('edit_title')), 'Editado');
    await tester.tap(find.byKey(const Key('edit_save')));
    await tester.pumpAndSettle();

    expect(find.text('Editado'), findsOneWidget);
    expect(find.text('Original'), findsNothing);
  });
}
