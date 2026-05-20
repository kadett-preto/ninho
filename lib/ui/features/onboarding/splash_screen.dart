import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/colors.dart';
import '../../core/routes.dart';

// Splash placeholder. Logo final virá do Stitch (asset `logo_sem_fundo.png`).
// Por enquanto, exibe wordmark Montserrat 700 primary terracotta + 1.2s delay.
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
    _navTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      context.go(NinhoRoutes.onboarding);
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
        child: Text(
          'ninho',
          style: theme.textTheme.displayLarge?.copyWith(
            color: NinhoColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
