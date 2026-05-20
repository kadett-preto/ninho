import 'package:go_router/go_router.dart';

import '../features/auth/lgpd_consent_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/home/home_placeholder_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/onboarding/splash_screen.dart';

// Rotas declarativas (skill flutter-setup-declarative-routing).
// Stack inicial: Splash → Onboarding → Login → LGPD → Home.
// Gates de auth/consentimento entram quando providers Supabase Auth forem
// implementados (tasks 2.4, 2.5, 2.7).
class NinhoRoutes {
  NinhoRoutes._();

  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const consent = '/consent';
  static const home = '/home';
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
  ],
);
