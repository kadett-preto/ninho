import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../features/account/account_settings_screen.dart';
import '../features/account/edit_profile_screen.dart';
import '../features/auth/lgpd_consent_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/feed/feed_photo_detail_screen.dart';
import '../features/feed/feed_screen.dart';
import '../features/home/home_screen.dart';
import '../features/invite/accept_invite_screen.dart';
import '../features/invite/invite_screen.dart';
import '../features/invite/qr_scan_screen.dart';
import '../features/invite/tour_screen.dart';
import '../features/notifications/notification_settings_screen.dart';
import '../features/shop/shop_screen.dart';
import '../features/shop/transfer_history_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/profile/delete_account_screen.dart';
import '../features/profile/export_data_screen.dart';
import '../features/profile/environment_settings_screen.dart';
import '../features/profile/environment_members_screen.dart';
import '../features/profile/environment_rooms_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/profile/transfer_ownership_screen.dart';
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
  static const inviteScan = '/invite/scan';
  static const acceptInvite = '/i';
  static const tour = '/tour';
  static const suggestions = '/suggestions';
  static const feed = '/feed';
  static const tasks = '/tasks';
  static const taskDetail = '/tasks';
  static const notificationSettings = '/settings/notifications';
  static const shop = '/shop';
  static const shopHistory = '/shop/history';
  static const profile = '/profile';
  static const accountSettings = '/profile/account';
  static const accountEditProfile = '/profile/account/edit';
  static const profileExport = '/profile/export';
  static const profileDelete = '/profile/delete';
  static const profileTransferOwnership = '/profile/transfer-ownership';
  static const environmentSettings = '/profile/environment';
  static const environmentMembers = '/profile/environment/members';
  static const environmentRooms = '/profile/environment/rooms';
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
      GoRoute(
        path: NinhoRoutes.inviteScan,
        builder: (context, state) => const QrScanScreen(),
      ),
      GoRoute(
        path: NinhoRoutes.tour,
        builder: (context, state) {
          final extra = state.extra;
          final envName = extra is String ? extra : null;
          return TourScreen(environmentName: envName);
        },
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
        path: NinhoRoutes.feed,
        builder: (context, state) => const FeedScreen(),
      ),
      GoRoute(
        path: '${NinhoRoutes.feed}/:eventId',
        builder: (context, state) =>
            FeedPhotoDetailScreen(eventId: state.pathParameters['eventId']!),
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
        path: NinhoRoutes.shop,
        builder: (context, state) => const ShopScreen(),
      ),
      GoRoute(
        path: NinhoRoutes.shopHistory,
        builder: (context, state) => const TransferHistoryScreen(),
      ),
      GoRoute(
        path: NinhoRoutes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: NinhoRoutes.accountSettings,
        builder: (context, state) => const AccountSettingsScreen(),
      ),
      GoRoute(
        path: NinhoRoutes.accountEditProfile,
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: NinhoRoutes.profileExport,
        builder: (context, state) => const ExportDataScreen(),
      ),
      GoRoute(
        path: NinhoRoutes.profileDelete,
        builder: (context, state) => const DeleteAccountScreen(),
      ),
      GoRoute(
        path: NinhoRoutes.profileTransferOwnership,
        builder: (context, state) => const TransferOwnershipScreen(),
      ),
      GoRoute(
        path: NinhoRoutes.environmentSettings,
        builder: (context, state) => const EnvironmentSettingsScreen(),
      ),
      GoRoute(
        path: NinhoRoutes.environmentMembers,
        builder: (context, state) => const EnvironmentMembersScreen(),
      ),
      GoRoute(
        path: NinhoRoutes.environmentRooms,
        builder: (context, state) => const EnvironmentRoomsScreen(),
      ),
      GoRoute(
        path: '${NinhoRoutes.tasks}/new',
        builder: (context, state) => const TaskFormScreen(),
      ),
      GoRoute(
        path: '${NinhoRoutes.taskDetail}/:taskId/edit',
        builder: (context, state) =>
            TaskFormScreen(taskId: state.pathParameters['taskId']),
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
