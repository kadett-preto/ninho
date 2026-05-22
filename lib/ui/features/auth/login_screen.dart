import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/services/auth_service.dart';
import '../../core/colors.dart';
import '../../core/routes.dart';
import '../../core/spacing.dart';

// Tela de login (Stitch — Login · Playful Geometric Variant 3).
// Google em produção via Supabase OAuth (task 2.4). Apple ainda stubbed
// (task 2.5).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    // Mobile: deep link do OAuth callback dispara onAuthStateChange.
    // Web: signInWithOAuth força full-page redirect — listener nem chega.
    // Em widget tests sem Supabase inicializado, o subscribe explode —
    // ignoramos silenciosamente.
    try {
      _authSub = AuthService.onAuthStateChange.listen((event) {
        if (!mounted) return;
        if (event.event == AuthChangeEvent.signedIn ||
            event.event == AuthChangeEvent.initialSession) {
          if (AuthService.currentSession != null) {
            context.go(NinhoRoutes.splash);
          }
        }
      });
    } catch (_) {
      _authSub = null;
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _signInGoogle() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await AuthService.signInWithGoogle();
      // Em web, signInWithOAuth redireciona a página inteira. Quando voltar
      // do callback do Google, o app reinicializa e SplashScreen vê a sessão.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Falha ao entrar com Google: $e')));
      setState(() => _loading = false);
    }
  }

  Future<void> _signInApple() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await AuthService.signInWithApple();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Falha ao entrar com Apple: $e')));
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: NinhoColors.surface,
      body: SafeArea(
        child: Stack(
          children: [
            const _TopArch(),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: NinhoSpacing.marginMobile,
              ),
              child: Column(
                children: [
                  const SizedBox(height: NinhoSpacing.stackLg),
                  _Header(theme: theme),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const _HeroCircle(),
                        const SizedBox(height: NinhoSpacing.stackLg),
                        Text(
                          'Equilíbrio Afetivo',
                          style: theme.textTheme.headlineMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: NinhoSpacing.stackSm),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Seu espaço, sua harmonia. Entre para dividir as tarefas sem dividir a relação.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: NinhoColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _AuthButtons(
                    loading: _loading,
                    onGoogle: _signInGoogle,
                    onApple: _signInApple,
                  ),
                  const SizedBox(height: NinhoSpacing.stackMd),
                  _LegalFooter(theme: theme),
                  const SizedBox(height: NinhoSpacing.stackSm),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.auto_awesome, color: NinhoColors.primary, size: 24),
        const SizedBox(width: 6),
        Text(
          'ninho',
          style: theme.textTheme.titleMedium?.copyWith(
            color: NinhoColors.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _TopArch extends StatelessWidget {
  const _TopArch();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          color: NinhoColors.surfaceContainerLow.withValues(alpha: 0.5),
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.elliptical(800, 200),
          ),
        ),
      ),
    );
  }
}

class _HeroCircle extends StatelessWidget {
  const _HeroCircle();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 272,
      height: 272,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: NinhoColors.tertiaryFixedDim.withValues(alpha: 0.3),
              border: Border.all(color: NinhoColors.surfaceVariant, width: 1),
              boxShadow: [
                BoxShadow(
                  color: NinhoColors.primary.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: NinhoColors.surfaceContainerHigh,
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Image.asset(
                'assets/illustrations/login_hero.png',
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
          // Floating accents
          Positioned(
            top: 32,
            right: 48,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: NinhoColors.primaryFixed.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: 56,
            left: 56,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: NinhoColors.secondaryFixed.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthButtons extends StatelessWidget {
  const _AuthButtons({
    required this.onGoogle,
    required this.onApple,
    required this.loading,
  });

  final VoidCallback onGoogle;
  final VoidCallback onApple;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AuthButton(
          label: 'Continuar com Google',
          background: NinhoColors.surfaceContainerLowest,
          foreground: NinhoColors.onSurface,
          borderColor: NinhoColors.outlineVariant,
          icon: Icons.public, // TODO(stitch): trocar pelo SVG do Google
          onPressed: loading ? null : onGoogle,
        ),
        const SizedBox(height: NinhoSpacing.stackSm),
        _AuthButton(
          label: 'Continuar com Apple',
          background: NinhoColors.inverseSurface,
          foreground: NinhoColors.inverseOnSurface,
          icon: Icons.apple,
          onPressed: loading ? null : onApple,
        ),
        if (loading) ...[
          const SizedBox(height: NinhoSpacing.stackSm),
          const LinearProgressIndicator(minHeight: 2),
        ],
      ],
    );
  }
}

class _AuthButton extends StatelessWidget {
  const _AuthButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.icon,
    required this.onPressed,
    this.borderColor,
  });

  final String label;
  final Color background;
  final Color foreground;
  final IconData icon;
  final Color? borderColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(16),
        elevation: 0,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: borderColor == null
                ? null
                : BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: borderColor!.withValues(alpha: 0.6),
                    ),
                  ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: foreground, size: 22),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LegalFooter extends StatelessWidget {
  const _LegalFooter({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final linkStyle = theme.textTheme.bodySmall?.copyWith(
      color: NinhoColors.primary,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
    );
    return Text.rich(
      TextSpan(
        style: theme.textTheme.bodySmall?.copyWith(color: NinhoColors.outline),
        children: [
          const TextSpan(text: 'Ao entrar, você concorda com nossos\n'),
          TextSpan(text: 'Termos de Uso', style: linkStyle),
          const TextSpan(text: ' e '),
          TextSpan(text: 'Privacidade', style: linkStyle),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
