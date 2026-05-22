import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:ninho/data/repositories/environments_repository.dart';
import 'package:ninho/data/repositories/suggestions_repository.dart' show TaskDifficulty;
import 'package:ninho/data/repositories/tasks_repository.dart';
import 'package:ninho/ui/features/tasks/tasks_controller.dart';
import 'package:ninho/ui/features/tasks/tasks_screen.dart';

// Theme mínimo só para goldens, sem depender de GoogleFonts (que precisa
// de rede ou assets bundleados — instável em CI/local).
ThemeData _goldenTheme() {
  const seed = Color(0xFF944931);
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: const Color(0xFFFDF9F4),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 24,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(fontFamily: 'Roboto', fontSize: 16),
      bodySmall: TextStyle(fontFamily: 'Roboto', fontSize: 12),
      labelSmall: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

// Golden tests para componentes-chave do módulo de tarefas.
// Padrão: cada teste embrulha o widget em um harness fixo (Locale,
// MediaQuery, Theme) e compara PNG. Para regerar:
//   flutter test --update-goldens test/task_components_golden_test.dart
//
// Fontes externas (Montserrat / Material Icons) não carregam em ambiente
// de teste, então usamos um TextStyle "Roboto" forçado em DefaultTextStyle
// para tornar o golden estável entre máquinas.
Widget _harness(Widget child, {Size size = const Size(360, 200)}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: _goldenTheme(),
    home: Scaffold(
      backgroundColor: const Color(0xFFFDF9F4),
      body: Center(
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: DefaultTextStyle(
            style: const TextStyle(
              fontFamily: 'Roboto',
              package: null,
            ),
            child: child,
          ),
        ),
      ),
    ),
  );
}

class _FakeEnvRepo extends EnvironmentsRepository {
  _FakeEnvRepo({this.rooms = const []});
  final List<RoomRow> rooms;

  @override
  Future<String?> fetchCurrentEnvironmentId() async => 'env-1';

  @override
  Future<List<RoomRow>> fetchRooms(String environmentId) async => rooms;
}

class _FakeTasksRepo extends TasksRepository {
  _FakeTasksRepo({this.items = const []});
  final List<TaskListItem> items;

  @override
  Future<List<TaskListItem>> fetchTaskList({required String environmentId}) async {
    return items;
  }
}

void main() {
  setUpAll(() {
    // Sem rede em CI/local — bloqueia fetch da Google Fonts e cai no
    // fallback do Flutter (Roboto). Garante goldens determinísticos.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('golden: TasksScreen lista 3 dificuldades', (tester) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final tasks = [
      TaskListItem(
        id: 't1',
        title: 'Lavar a louça',
        roomId: 'r-cozinha',
        roomName: 'Cozinha',
        difficulty: TaskDifficulty.mamao,
        assigneeId: 'me',
        recurrenceRule: 'RRULE:FREQ=DAILY;INTERVAL=1',
        recentCompletions: const [],
      ),
      TaskListItem(
        id: 't2',
        title: 'Varrer a sala',
        roomId: 'r-sala',
        roomName: 'Sala',
        difficulty: TaskDifficulty.embacada,
        assigneeId: 'other',
        recurrenceRule: 'RRULE:FREQ=DAILY;INTERVAL=7',
        recentCompletions: const [],
      ),
      TaskListItem(
        id: 't3',
        title: 'Limpar o banheiro',
        roomId: 'r-banheiro',
        roomName: 'Banheiro',
        difficulty: TaskDifficulty.treta,
        assigneeId: null,
        recurrenceRule: null,
        recentCompletions: const [],
      ),
    ];

    await tester.pumpWidget(
      MaterialApp.router(
        theme: _goldenTheme(),
        debugShowCheckedModeBanner: false,
        routerConfig: GoRouter(
          initialLocation: '/test',
          routes: [
            GoRoute(
              path: '/test',
              builder: (_, _) => TasksScreen(
                environmentsRepository: _FakeEnvRepo(
                  rooms: const [
                    RoomRow(id: 'r-cozinha', name: 'Cozinha', sizeCategory: 'G'),
                    RoomRow(id: 'r-sala', name: 'Sala', sizeCategory: 'M'),
                    RoomRow(id: 'r-banheiro', name: 'Banheiro', sizeCategory: 'P'),
                  ],
                ),
                tasksRepository: _FakeTasksRepo(items: tasks),
                currentUserId: 'me',
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(TasksScreen),
      matchesGoldenFile('goldens/tasks_screen_three_difficulties.png'),
    );
  });

  testWidgets('golden: TasksScreen empty state', (tester) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp.router(
        theme: _goldenTheme(),
        debugShowCheckedModeBanner: false,
        routerConfig: GoRouter(
          initialLocation: '/test',
          routes: [
            GoRoute(
              path: '/test',
              builder: (_, _) => TasksScreen(
                environmentsRepository: _FakeEnvRepo(),
                tasksRepository: _FakeTasksRepo(),
                currentUserId: 'me',
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(TasksScreen),
      matchesGoldenFile('goldens/tasks_screen_empty.png'),
    );
  });

  testWidgets('golden: filter chips estado padrão', (tester) async {
    final ctrl = TasksController(
      environmentsRepository: _FakeEnvRepo(
        rooms: const [
          RoomRow(id: 'r-cozinha', name: 'Cozinha', sizeCategory: 'G'),
        ],
      ),
      tasksRepository: _FakeTasksRepo(),
      currentUserId: 'me',
    );
    await ctrl.load();
    addTearDown(ctrl.dispose);

    await tester.pumpWidget(
      _harness(
        ChangeNotifierProvider<TasksController>.value(
          value: ctrl,
          child: const Builder(builder: _chipsHarness),
        ),
        size: const Size(500, 80),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(Center),
      matchesGoldenFile('goldens/tasks_filter_chips.png'),
    );
  });
}

Widget _chipsHarness(BuildContext context) {
  final ctrl = context.watch<TasksController>();
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _GoldenChip(
        label: 'Todas',
        selected: ctrl.filter == TaskFilter.all && ctrl.roomFilter == null,
      ),
      const SizedBox(width: 8),
      _GoldenChip(
        label: 'Minhas',
        selected: ctrl.filter == TaskFilter.mine,
      ),
      const SizedBox(width: 8),
      _GoldenChip(
        label: 'Concluídas',
        selected: ctrl.filter == TaskFilter.completed,
      ),
    ],
  );
}

class _GoldenChip extends StatelessWidget {
  const _GoldenChip({required this.label, required this.selected});
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? const Color(0xFF944931) : const Color(0xFFEBE8E3);
    final fg = selected ? Colors.white : const Color(0xFF1C1C19);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 12,
          letterSpacing: 1,
          fontFamily: 'Roboto',
        ),
      ),
    );
  }
}
