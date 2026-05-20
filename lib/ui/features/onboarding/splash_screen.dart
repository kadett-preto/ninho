import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/services/auth_service.dart';
import '../../core/colors.dart';
import '../../core/routes.dart';
import '../../core/spacing.dart';

// Splash — logo oficial do Stitch (assets/branding/logo.png) + wordmark.
// Auto-advance para /onboarding em 1.4s.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _navTimer;

  @override
  void initState() {
    super.initState();
    _navTimer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      // Se já tem sessão Supabase, pula onboarding/login e cai direto no
      // gate de consentimento (que verifica e encaminha para home se já ok).
      // TODO(task 2.7): checar users.lgpd_consent_at p/ pular /consent quando
      // já aceitou anteriormente.
      final session = AuthService.currentSession;
      context.go(
        session == null ? NinhoRoutes.onboarding : NinhoRoutes.consent,
      );
    });
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: NinhoColors.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/branding/logo.png',
              width: 160,
              height: 160,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  const SizedBox(width: 160, height: 160),
            ),
            const SizedBox(height: NinhoSpacing.stackMd),
            Text(
              'ninho',
              style: theme.textTheme.headlineLarge?.copyWith(
                color: NinhoColors.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: -1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
