import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/colors.dart';
import '../../core/routes.dart';
import '../../core/spacing.dart';

// Ninho — Fase 4.7: tour pós-entrada (3 cards).
//
// Mostra ao novo morador o que esperar do Ninho — tom acolhedor §7, sem
// gamificação punitiva. Stitch ainda não entregou esta tela; visual segue
// tokens canônicos (DESIGN.md): cards radius 24, paleta Harmonia Lar,
// Montserrat via tema.
//
// Não-bloqueante: skip a qualquer momento (texto "Pular"). Conclusão leva
// pra /home.
class TourScreen extends StatefulWidget {
  const TourScreen({super.key, this.environmentName, this.pageController});

  final String? environmentName;
  final PageController? pageController;

  @override
  State<TourScreen> createState() => _TourScreenState();
}

class _TourScreenState extends State<TourScreen> {
  late final PageController _pageCtrl;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _pageCtrl = widget.pageController ?? PageController();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  List<_TourCard> get _cards => [
    _TourCard(
      icon: Icons.favorite,
      title: widget.environmentName != null
          ? 'Bem-vindo ao ninho ${widget.environmentName}'
          : 'Bem-vindo ao ninho',
      body:
          'Aqui vocês dividem o cuidado da casa sem dividir a relação. Tom acolhedor, nunca punitivo.',
    ),
    const _TourCard(
      icon: Icons.checklist,
      title: 'Tarefas com peso justo',
      body:
          'Mamão, Embaçada ou Treta — cada tarefa rende poeira na pá. Quem faz, recebe.',
    ),
    const _TourCard(
      icon: Icons.local_fire_department,
      title: 'Streak do ninho',
      body:
          'Vocês mantêm o ritmo juntos. Dois freezes por mês caso a vida apareça.',
    ),
  ];

  void _next() {
    if (_page < _cards.length - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    } else {
      _finish();
    }
  }

  void _finish() {
    context.go(NinhoRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLast = _page == _cards.length - 1;
    return Scaffold(
      backgroundColor: NinhoColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: NinhoSpacing.marginMobile,
          ),
          child: Column(
            children: [
              SizedBox(
                height: 56,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      key: const Key('tour_skip_button'),
                      onPressed: _finish,
                      style: TextButton.styleFrom(
                        foregroundColor: NinhoColors.onSurfaceVariant,
                      ),
                      child: const Text('Pular'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  key: const Key('tour_pageview'),
                  controller: _pageCtrl,
                  itemCount: _cards.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) => _CardView(card: _cards[i]),
                ),
              ),
              _Dots(active: _page, total: _cards.length),
              const SizedBox(height: NinhoSpacing.stackLg),
              FilledButton(
                key: const Key('tour_primary_button'),
                onPressed: _next,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(NinhoRadii.lg),
                  ),
                ),
                child: Text(
                  isLast ? 'Bora cuidar juntos' : 'Próximo',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: NinhoColors.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: NinhoSpacing.stackMd),
            ],
          ),
        ),
      ),
    );
  }
}

class _TourCard {
  const _TourCard({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;
}

class _CardView extends StatelessWidget {
  const _CardView({required this.card});
  final _TourCard card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 152,
              height: 152,
              decoration: BoxDecoration(
                color: NinhoColors.primaryFixed,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: NinhoColors.primary.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(card.icon, size: 64, color: NinhoColors.primary),
            ),
            const SizedBox(height: NinhoSpacing.stackLg),
            Text(
              card.title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: NinhoColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: NinhoSpacing.stackMd),
            Text(
              card.body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: NinhoColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.active, required this.total});
  final int active;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final selected = i == active;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: selected ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: selected ? NinhoColors.primary : NinhoColors.outlineVariant,
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }
}
