import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../colors.dart';
import '../spacing.dart';

// Bottom nav compartilhado entre Home/Tasks/Feed/Shop/Profile.
// Labels via AppL10n (Fase 12.2). Padroniza ícones, cores e
// comportamento de seleção; a tela escolhe o índice ativo via
// [activeIndex] (0..4 — Home/Tasks/Feed/Shop/Profile).
enum NinhoTab { home, tasks, feed, shop, profile }

class NinhoBottomNav extends StatelessWidget {
  const NinhoBottomNav({
    super.key,
    required this.active,
    required this.onTap,
  });

  final NinhoTab active;
  final ValueChanged<NinhoTab> onTap;

  @override
  Widget build(BuildContext context) {
    // Fallback pt-BR quando AppL10n não está disponível (widget tests
    // antigos que não wrap MaterialApp com localizationsDelegates).
    final l = AppL10n.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final items = <_Item>[
      _Item(
        tab: NinhoTab.home,
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        label: l?.navHome ?? 'Início',
        keyValue: 'nav_home',
      ),
      _Item(
        tab: NinhoTab.tasks,
        icon: Icons.checklist,
        selectedIcon: Icons.checklist,
        label: l?.navTasks ?? 'Tarefas',
        keyValue: 'nav_tasks',
      ),
      _Item(
        tab: NinhoTab.feed,
        icon: Icons.grid_view,
        selectedIcon: Icons.grid_view,
        label: l?.navFeed ?? 'Mural',
        keyValue: 'nav_feed',
      ),
      _Item(
        tab: NinhoTab.shop,
        icon: Icons.storefront_outlined,
        selectedIcon: Icons.storefront,
        label: l?.navShop ?? 'Loja',
        keyValue: 'nav_shop',
      ),
      _Item(
        tab: NinhoTab.profile,
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        label: l?.navProfile ?? 'Perfil',
        keyValue: 'nav_profile',
      ),
    ];
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: NinhoColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14944931),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, bottom + 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (final item in items)
              _NavItem(
                item: item,
                selected: active == item.tab,
                onTap: () => onTap(item.tab),
              ),
          ],
        ),
      ),
    );
  }
}

class _Item {
  const _Item({
    required this.tab,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.keyValue,
  });

  final NinhoTab tab;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String keyValue;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _Item item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? NinhoColors.primary : NinhoColors.onSurfaceVariant;
    return Expanded(
      child: InkWell(
        key: Key(item.keyValue),
        borderRadius: BorderRadius.circular(NinhoRadii.regular),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(selected ? item.selectedIcon : item.icon, color: color),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  item.label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
