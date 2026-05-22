import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../features/auth/lgpd_consent_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/home/home_screen.dart';
import '../features/invite/accept_invite_screen.dart';
import '../features/invite/invite_screen.dart';
import '../features/notifications/notification_settings_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/onboarding/splash_screen.dart';
import '../features/setup/setup_controller.dart';
import '../features/setup/step1_name_screen.dart';
import '../features/setup/step2_rooms_screen.dart';
import '../features/setup/step3_timezone_screen.dart';
import '../features/suggestions/suggestions_screen.dart';
import '../features/tasks/task_completion_screen.dart';
import '../features/tasks/task_detail_screen.dart';
import '../features/tasks/task_form_screen.dart';
import '../features/tasks/tasks_screen.dart';

class NinhoRoutes {
  NinhoRoutes._();

  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const consent = '/consent';
  static const home = '/home';
  static const setupStep1 = '/setup/step1';
  static const setupStep2 = '/setup/step2';
  static const setupStep3 = '/setup/step3';
  static const inviteFromSetup = '/invite/setup';
  static const invite = '/invite';
  static const acceptInvite = '/i';
  static const suggestions = '/suggestions';
  static const tasks = '/tasks';
  static const taskDetail = '/tasks';
  static const notificationSettings = '/settings/notifications';
}

typedef SetupControllerFactory = SetupController Function();

GoRouter createNinhoRouter({
  String initialLocation = NinhoRoutes.splash,
  SetupControllerFactory? setupControllerFactory,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: NinhoRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: NinhoRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: NinhoRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: NinhoRoutes.consent,
        builder: (context, state) => const LgpdConsentScreen(),
      ),
      GoRoute(
        path: NinhoRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: NinhoRoutes.invite,
        builder: (context, state) => const InviteScreen(),
      ),
      GoRoute(
        path: NinhoRoutes.inviteFromSetup,
        builder: (context, state) => const InviteScreen(fromSetup: true),
      ),
      // Deep link / QR: /i/<token>. Token vai no path (não em query) para
      // evitar logs de servidores intermediários (§7.3).
      GoRoute(
        path: '${NinhoRoutes.acceptInvite}/:token',
        builder: (context, state) =>
            AcceptInviteScreen(token: state.pathParameters['token']!),
      ),
      GoRoute(
        path: NinhoRoutes.suggestions,
        builder: (context, state) => const SuggestionsScreen(),
      ),
      GoRoute(
        path: NinhoRoutes.tasks,
        builder: (context, state) => const TasksScreen(),
      ),
      GoRoute(
        path: NinhoRoutes.notificationSettings,
        builder: (context, state) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: '${NinhoRoutes.tasks}/new',
        builder: (context, state) => const TaskFormScreen(),
      ),
      GoRoute(
        path: '${NinhoRoutes.taskDetail}/:taskId/edit',
        builder: (context, state) => TaskFormScreen(
          taskId: state.pathParameters['taskId'],
        ),
      ),
      GoRoute(
        path: '${NinhoRoutes.taskDetail}/:taskId',
        builder: (context, state) =>
            TaskDetailScreen(taskId: state.pathParameters['taskId']!),
      ),
      GoRoute(
        path: '${NinhoRoutes.taskDetail}/:taskId/complete',
        builder: (context, state) =>
            TaskCompletionScreen(taskId: state.pathParameters['taskId']!),
      ),
      // ShellRoute escopa SetupController às 3 telas de cadastro.
      ShellRoute(
        builder: (context, state, child) {
          return ChangeNotifierProvider(
            create: (_) => setupControllerFactory?.call() ?? SetupController(),
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: NinhoRoutes.setupStep1,
            builder: (context, state) => const SetupStep1NameScreen(),
          ),
          GoRoute(
            path: NinhoRoutes.setupStep2,
            builder: (context, state) => const SetupStep2RoomsScreen(),
          ),
          GoRoute(
            path: NinhoRoutes.setupStep3,
            builder: (context, state) => const SetupStep3TimezoneScreen(),
          ),
        ],
      ),
    ],
  );
}

final ninhoRouter = createNinhoRouter();
