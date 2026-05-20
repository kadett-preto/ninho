import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/services/auth_service.dart';
import '../../../data/services/posthog_service.dart';
import '../../core/colors.dart';
import '../../core/routes.dart';
import '../../core/spacing.dart';

// Placeholder de destino pós-fluxo de auth/onboarding. Tela real "Hoje"
// (Stitch — Início) entra na Fase 6.
//
// Já hospeda o ponto de logout enquanto a tela de Perfil não existe — task 2.8.
class HomePlaceholderScreen extends StatefulWidget {
  const HomePlaceholderScreen({super.key});

  @override
  State<HomePlaceholderScreen> createState() => _HomePlaceholderScreenState();
}

class _HomePlaceholderScreenState extends State<HomePlaceholderScreen> {
  bool _signingOut = false;

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      // Limpa rastreamento de analytics antes de invalidar a sessão (§7.5).
      await PosthogService.optOutAndReset();
      await AuthService.signOut();
      if (!mounted) return;
      context.go(NinhoRoutes.splash);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Falha ao sair: $e')));
      setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final email = AuthService.currentUser?.email ?? '—';
    return Scaffold(
      backgroundColor: NinhoColors.surface,
      appBar: AppBar(title: const Text('Ninho')),
      body: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: NinhoSpacing.marginMobile,
          vertical: NinhoSpacing.stackLg,
        ),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Bem-vindo ao Ninho.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: NinhoSpacing.stackSm),
                    Text(
                      'Home real entra na Fase 6.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: NinhoColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: NinhoSpacing.stackLg),
                    Text(
                      'Logado como',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: NinhoColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(email, style: theme.textTheme.bodyLarge),
                  ],
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _signingOut ? null : _signOut,
              icon: _signingOut
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.logout),
              label: const Text('Sair do ninho'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                foregroundColor: NinhoColors.primary,
                side: const BorderSide(color: NinhoColors.outlineVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
