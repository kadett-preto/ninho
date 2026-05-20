// Escala de espaçamento "Fluid Grid" (DESIGN.md §Layout & Spacing).
// Base unit 8px; todos os múltiplos derivam dele.
class NinhoSpacing {
  NinhoSpacing._();

  static const double unit = 8;

  // Stacks (vertical gap)
  static const double stackSm = 8;
  static const double stackMd = 16;
  static const double stackLg = 32;

  // Mobile
  static const double marginMobile = 24;
  static const double gutterMobile = 16;

  // Cards
  static const double paddingCard = 20;
  static const double cardInnerMin = 16;
}

// Raios de borda. DESIGN.md §Shapes:
//   - Cards primários: 24px
//   - Botões: 16px
//   - Pills (difficulty badges): 100px (efetivamente full)
class NinhoRadii {
  NinhoRadii._();

  static const double sm = 4; // 0.25rem
  static const double regular = 8; // 0.5rem
  static const double md = 12; // 0.75rem
  static const double lg = 16; // 1rem — botões
  static const double xl = 24; // 1.5rem — cards
  static const double full = 9999;
}
