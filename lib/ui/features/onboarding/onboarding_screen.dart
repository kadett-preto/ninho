import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/colors.dart';
import '../../core/routes.dart';
import '../../core/spacing.dart';
import 'welcome_card.dart';

// Stack do onboarding (Stitch — Bem-vindo + Playful Geometric Variant).
// O design tem 3-dot indicator; só o card 1 (Welcome) foi entregue pelo Stitch
// até agora. Os cards 2 e 3 ficam pendentes — quando chegarem, basta adicionar
// na lista `_pages` e o PageView lida com indicadores e navegação.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const int _totalCards = 3;

  late final List<Widget> _pages = [
    WelcomeCard(
      onPrimary: _next,
      onSecondary: () => context.go(NinhoRoutes.login),
    ),
    // TODO(stitch): substituir placeholders quando cards 2 e 3 chegarem do Stitch.
    _PlaceholderCard(
      index: 2,
      onPrimary: _next,
      onSecondary: () => context.go(NinhoRoutes.login),
    ),
    _PlaceholderCard(
      index: 3,
      onPrimary: () => context.go(NinhoRoutes.login),
      onSecondary: () => context.go(NinhoRoutes.login),
    ),
  ];

  void _next() {
    if (_page < _totalCards - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    } else {
      context.go(NinhoRoutes.login);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NinhoColors.surface,
      body: SafeArea(
        child: PageView.builder(
          controller: _controller,
          itemCount: _pages.length,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (context, i) => OnboardingPageScaffold(
            currentIndex: _page,
            totalCards: _totalCards,
            child: _pages[i],
          ),
        ),
      ),
    );
  }
}

// Wrapper visual comum (decor + indicador) reutilizado por cada card.
class OnboardingPageScaffold extends StatelessWidget {
  const OnboardingPageScaffold({
    super.key,
    required this.child,
    required this.currentIndex,
    required this.totalCards,
  });

  final Widget child;
  final int currentIndex;
  final int totalCards;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const _DecorBackground(),
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: NinhoSpacing.marginMobile,
              vertical: NinhoSpacing.stackLg,
            ),
            child: Column(
              children: [
                Expanded(child: child),
                const SizedBox(height: NinhoSpacing.stackMd),
                _DotIndicator(current: currentIndex, total: totalCards),
                const SizedBox(height: NinhoSpacing.stackMd),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DecorBackground extends StatelessWidget {
  const _DecorBackground();

  @override
  Widget build(BuildContext context) {
    // Três blobs decorativos (Stitch §Bem-vindo). Sem mix-blend-multiply real
    // (não nativo no Flutter widget tree) — aproximamos com opacidade.
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -64,
            right: -64,
            child: _blob(256, NinhoColors.primaryFixed, 0.6, circle: true),
          ),
          Positioned(
            top: 240,
            left: -48,
            child: _blob(128, NinhoColors.secondaryFixed, 0.8, circle: true),
          ),
          Positioned(
            bottom: 120,
            right: -32,
            child: Transform.rotate(
              angle: 12 * 3.1415926535 / 180,
              child: _blob(160, NinhoColors.tertiaryFixed, 0.5, radius: 24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blob(
    double size,
    Color color,
    double opacity, {
    bool circle = false,
    double radius = 0,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: opacity),
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(radius),
      ),
    );
  }
}

class _DotIndicator extends StatelessWidget {
  const _DotIndicator({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final isActive = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 32 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? NinhoColors.primary : NinhoColors.surfaceVariant,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

// Placeholder para os cards 2 e 3 enquanto não chegarem do Stitch.
class _PlaceholderCard extends StatelessWidget {
  const _PlaceholderCard({
    required this.index,
    required this.onPrimary,
    required this.onSecondary,
  });

  final int index;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        const SizedBox(height: NinhoSpacing.stackLg),
        Text(
          'ninho',
          style: theme.textTheme.headlineMedium?.copyWith(
            color: NinhoColors.primary,
          ),
        ),
        const Spacer(),
        Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            color: NinhoColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(24),
          ),
          alignment: Alignment.center,
          child: Text(
            'Card $index\n(aguardando Stitch)',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: NinhoColors.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: NinhoSpacing.stackLg),
        Text(
          'Slide $index de 3',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: NinhoColors.onSurface,
          ),
        ),
        const Spacer(),
        FilledButton(
          onPressed: onPrimary,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          child: Text(index == 3 ? 'Entrar' : 'Próximo'),
        ),
        const SizedBox(height: NinhoSpacing.stackMd),
        TextButton(
          onPressed: onSecondary,
          child: const Text('Já tenho conta · Entrar'),
        ),
      ],
    );
  }
}
