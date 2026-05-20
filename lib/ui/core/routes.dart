import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../features/auth/lgpd_consent_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/home/home_placeholder_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/onboarding/splash_screen.dart';
import '../features/setup/setup_controller.dart';
import '../features/setup/step1_name_screen.dart';
import '../features/setup/step2_rooms_screen.dart';
import '../features/setup/step3_timezone_screen.dart';

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
}

final ninhoRouter = GoRouter(
  initialLocation: NinhoRoutes.splash,
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
      builder: (context, state) => const HomePlaceholderScreen(),
    ),
    // ShellRoute escopa SetupController às 3 telas de cadastro.
    ShellRoute(
      builder: (context, state, child) {
        return ChangeNotifierProvider(
          create: (_) => SetupController(),
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
