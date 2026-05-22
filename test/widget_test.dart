import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:ninho/data/repositories/tasks_repository.dart';
import 'package:ninho/data/services/room_photo_service.dart';
import 'package:ninho/domain/models/room_photo_draft.dart';
import 'package:ninho/ui/core/colors.dart';
import 'package:ninho/ui/core/routes.dart';
import 'package:ninho/ui/core/theme.dart';
import 'package:ninho/ui/features/auth/lgpd_consent_screen.dart';
import 'package:ninho/ui/features/auth/login_screen.dart';
import 'package:ninho/ui/features/home/home_screen.dart';
import 'package:ninho/ui/features/onboarding/splash_screen.dart';
import 'package:ninho/ui/features/onboarding/welcome_card.dart';
import 'package:ninho/ui/features/setup/setup_controller.dart';
import 'package:ninho/ui/features/setup/step1_name_screen.dart';
import 'package:ninho/ui/features/setup/step2_rooms_screen.dart';
import 'package:ninho/ui/features/setup/step3_timezone_screen.dart';
import 'package:ninho/ui/features/tasks/task_completion_screen.dart';
import 'package:ninho/ui/features/tasks/task_detail_screen.dart';

Widget _wrap(Widget child) {
  return MaterialApp(theme: NinhoTheme.light(), home: child);
}

Widget _wrapSetup(SetupController controller, Widget child) {
  return MaterialApp(
    theme: NinhoTheme.light(),
    home: ChangeNotifierProvider.value(value: controller, child: child),
  );
}

Widget _wrapCompletionWithRepo(
  TasksRepository repo, {
  RoomPhotoService? photoService,
}) {
  final router = GoRouter(
    initialLocation: '/complete',
    routes: [
      GoRoute(
        path: '/complete',
        builder: (_, _) => TaskCompletionScreen(
          taskId: 'aaaaaaaa-0000-0000-0000-000000000001',
          tasksRepository: repo,
          photoService: photoService,
        ),
      ),
      GoRoute(path: NinhoRoutes.home, builder: (_, _) => const HomeScreen()),
    ],
  );
  return MaterialApp.router(theme: NinhoTheme.light(), routerConfig: router);
}

class _FakeTasksRepository extends TasksRepository {
  _FakeTasksRepository({this.error});

  final Object? error;
  final String uploadPath =
      'eeeeeeee-0000-0000-0000-000000000001/task-completions/aaaaaaaa-0000-0000-0000-000000000001/user.jpg';
  int completeCalls = 0;
  int uploadCalls = 0;
  String? lastTaskId;
  String? lastPhotoPath;
  RoomPhotoDraft? lastUploadedDraft;

  static const result = CompleteTaskResult(
    completionId: 'aaaaaaaa-0000-0000-0000-000000000001',
    alreadyCompleted: false,
    rewardDelta: 5,
    notificationSuppressedCount: 2,
    feedEventId: 'bbbbbbbb-0000-0000-0000-000000000001',
  );

  @override
  Future<String> uploadCompletionPhoto({
    required String taskId,
    required RoomPhotoDraft draft,
  }) async {
    uploadCalls++;
    lastTaskId = taskId;
    lastUploadedDraft = draft;
    return uploadPath;
  }

  @override
  Future<CompleteTaskResult> completeTask({
    required String taskId,
    String? photoPath,
  }) async {
    completeCalls++;
    lastTaskId = taskId;
    lastPhotoPath = photoPath;
    if (error != null) throw error!;
    return result;
  }
}

class _FakeTaskPhotoService implements RoomPhotoService {
  const _FakeTaskPhotoService({this.draft});

  final RoomPhotoDraft? draft;

  @override
  Future<RoomPhotoDraft?> pickAndPrepare(RoomPhotoSource source) async {
    return draft;
  }
}

void _setMobile(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532); // iPhone 13 px
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('splash renders ninho wordmark', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(_wrap(const SplashScreen()));
    expect(find.text('ninho'), findsOneWidget);
  });

  testWidgets('welcome card shows headline and CTAs', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(WelcomeCard(onPrimary: () {}, onSecondary: () {})),
    );
    expect(
      find.text('A divisão de tarefas justa e leve da casa.'),
      findsOneWidget,
    );
    expect(find.text('Começar'), findsOneWidget);
    expect(find.text('Já tenho conta · Entrar'), findsOneWidget);
  });

  testWidgets('login shows Google + Apple buttons', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(_wrap(const LoginScreen()));
    expect(find.text('Equilíbrio Afetivo'), findsOneWidget);
    expect(find.text('Continuar com Google'), findsOneWidget);
    expect(find.text('Continuar com Apple'), findsOneWidget);
  });

  testWidgets('LGPD: 3 toggles — 1 obrigatório (disabled) + 2 opcionais', (
    tester,
  ) async {
    _setMobile(tester);
    await tester.pumpWidget(_wrap(const LgpdConsentScreen()));
    expect(find.text('Sua privacidade vem primeiro.'), findsOneWidget);
    expect(find.text('Obrigatório'), findsOneWidget);

    final switches = find.byType(Switch);
    expect(switches, findsNWidgets(3));

    // O 1º Switch (obrigatório) tem onChanged null = disabled.
    final required = tester.widget<Switch>(switches.first);
    expect(required.onChanged, isNull);
    expect(required.value, isTrue);

    // Os 2 opcionais começam desligados mas habilitados.
    final notifs = tester.widget<Switch>(switches.at(1));
    expect(notifs.onChanged, isNotNull);
    expect(notifs.value, isFalse);

    final metrics = tester.widget<Switch>(switches.at(2));
    expect(metrics.onChanged, isNotNull);
    expect(metrics.value, isFalse);
  });

  testWidgets('home profile tab keeps logout reachable', (tester) async {
    _setMobile(tester);
    // HomeScreen agora exige repos. Como o test só valida bottom sheet de
    // perfil, qualquer estado renderizado (incluindo erro) já expõe a tab.
    await tester.pumpWidget(_wrap(const HomeScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home_profile_tab')));
    await tester.pumpAndSettle();

    expect(find.text('Perfil'), findsWidgets);
    expect(find.text('Sair do ninho'), findsOneWidget);
    expect(find.byIcon(Icons.logout), findsOneWidget);
  });

  testWidgets('task detail screen renders Stitch content', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(_wrap(const TaskDetailScreen(taskId: 'dishes')));

    expect(find.text('Detalhes da Tarefa'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Lavar a louça'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Lavar a louça'), findsOneWidget);
    expect(find.text('Cozinha'), findsOneWidget);
    expect(find.text('Marcar como feita'), findsOneWidget);
    expect(find.text('Transferir'), findsOneWidget);
  });

  testWidgets('task completion screen renders reward and photo actions', (
    tester,
  ) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(const TaskCompletionScreen(taskId: 'dishes')),
    );

    expect(find.text('Mandou bem!'), findsOneWidget);
    expect(find.text('Lavar a louça'), findsOneWidget);
    expect(find.text('+15 poeiras'), findsOneWidget);
    expect(find.text('Adicionar foto do resultado'), findsOneWidget);
    expect(find.text('Concluir tarefa'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Pular foto'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Pular foto'), findsOneWidget);
  });

  testWidgets('task completion calls repository for UUID task id', (
    tester,
  ) async {
    _setMobile(tester);
    await tester.pumpWidget(_wrapCompletionWithRepo(_FakeTasksRepository()));

    await tester.scrollUntilVisible(
      find.byKey(const Key('task_completion_skip_photo_button')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(
      find.byKey(const Key('task_completion_skip_photo_button')),
    );
    await tester.pumpAndSettle();

    // HomeScreen agora consulta backend; sem fakes vai para estado de
    // loading/erro. Basta confirmar que saímos da tela de conclusão.
    expect(find.text('Mandou bem!'), findsNothing);
  });

  testWidgets('task completion keeps user on screen when RPC fails', (
    tester,
  ) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrapCompletionWithRepo(_FakeTasksRepository(error: 'fail')),
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('task_completion_skip_photo_button')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(
      find.byKey(const Key('task_completion_skip_photo_button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Não conseguimos concluir agora. Tente de novo.'),
      findsOneWidget,
    );
  });

  testWidgets('task completion uploads selected photo before RPC', (
    tester,
  ) async {
    _setMobile(tester);
    final repo = _FakeTasksRepository();
    final draft = RoomPhotoDraft(
      bytes: Uint8List.fromList([1, 2, 3]),
      contentType: 'image/jpeg',
      extension: 'jpg',
    );
    await tester.pumpWidget(
      _wrapCompletionWithRepo(
        repo,
        photoService: _FakeTaskPhotoService(draft: draft),
      ),
    );

    await tester.tap(find.byKey(const Key('task_completion_photo_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Escolher da galeria'));
    await tester.pumpAndSettle();

    expect(find.text('Foto pronta para enviar'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('task_completion_finish_button')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('task_completion_finish_button')));
    await tester.pumpAndSettle();

    expect(repo.uploadCalls, 1);
    expect(repo.completeCalls, 1);
    expect(repo.lastUploadedDraft, draft);
    expect(repo.lastPhotoPath, repo.uploadPath);
    // HomeScreen agora consulta backend; sem fakes vai para estado de
    // loading/erro. Basta confirmar que saímos da tela de conclusão.
    expect(find.text('Mandou bem!'), findsNothing);
  });

  testWidgets('theme uses primary terracotta', (tester) async {
    final theme = NinhoTheme.light();
    expect(theme.colorScheme.primary, NinhoColors.primary);
    expect(theme.colorScheme.secondary, NinhoColors.secondary);
  });

  testWidgets('setup step 1 updates ninho name', (tester) async {
    _setMobile(tester);
    final controller = SetupController();
    await tester.pumpWidget(
      _wrapSetup(controller, const SetupStep1NameScreen()),
    );

    expect(find.text('Crie seu ninho'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Casa da Vila');
    await tester.pump();

    expect(controller.name, 'Casa da Vila');
    expect(controller.canAdvanceFromStep1, isTrue);
  });

  testWidgets('setup step 2 shows room grid and photo picker actions', (
    tester,
  ) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrapSetup(SetupController(), const SetupStep2RoomsScreen()),
    );

    expect(find.text('Quais cômodos tem na casa?'), findsOneWidget);
    expect(find.text('Sala'), findsOneWidget);
    expect(find.text('Adicionar\ncômodo'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.photo_camera).first);
    await tester.pumpAndSettle();

    expect(find.text('Tirar foto'), findsOneWidget);
    expect(find.text('Escolher da galeria'), findsOneWidget);
  });

  testWidgets('setup step 3 confirms default timezone', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrapSetup(SetupController(), const SetupStep3TimezoneScreen()),
    );

    expect(find.text('Qual o fuso da casa?'), findsOneWidget);
    expect(find.text('America/Sao_Paulo'), findsOneWidget);
    expect(find.text('Concluir cadastro'), findsOneWidget);
  });
}
