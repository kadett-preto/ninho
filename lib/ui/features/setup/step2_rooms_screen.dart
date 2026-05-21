import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/environments_repository.dart';
import '../../../data/services/room_photo_service.dart';
import '../../../domain/models/room.dart';
import '../../../domain/models/room_size.dart';
import '../../core/colors.dart';
import '../../core/routes.dart';
import '../../core/spacing.dart';
import 'setup_controller.dart';
import 'widgets/setup_scaffold.dart';

// Stitch — Configurar Ambiente · Passo 2: cômodos.
class SetupStep2RoomsScreen extends StatelessWidget {
  const SetupStep2RoomsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = context.watch<SetupController>();

    // Cards: união entre defaults + custom (mantém ordem); apresets sempre
    // antes dos custom para previsibilidade visual.
    final presetNames = DefaultRoomCatalog.presets.map((r) => r.name).toSet();
    final selectedByName = {for (final r in controller.rooms) r.name: r};

    final cards = [
      ...DefaultRoomCatalog.presets.map(
        (preset) => _RoomCardData(
          name: preset.name,
          selected: selectedByName[preset.name],
        ),
      ),
      ...controller.rooms
          .where((r) => !presetNames.contains(r.name))
          .map((r) => _RoomCardData(name: r.name, selected: r)),
    ];

    return SetupScaffold(
      step: 2,
      totalSteps: 3,
      primaryLabel: 'Continuar',
      primaryEnabled: controller.canAdvanceFromStep2,
      onPrimary: () => context.go(NinhoRoutes.setupStep3),
      onBack: () => context.go(NinhoRoutes.setupStep1),
      child: ListView(
        children: [
          const SizedBox(height: NinhoSpacing.stackMd),
          Text(
            'Quais cômodos tem na casa?',
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: NinhoSpacing.stackSm),
          Text(
            'Isso ajuda a gente a sugerir tarefas certinhas.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: NinhoColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: NinhoSpacing.stackSm),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: NinhoColors.inverseSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'P até 6m²  ·  M 6–12m²  ·  G acima de 12m²',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: NinhoColors.inverseOnSurface,
              ),
            ),
          ),
          const SizedBox(height: NinhoSpacing.stackLg),
          LayoutBuilder(
            builder: (context, constraints) {
              final maxExtent = constraints.maxWidth >= 720 ? 220.0 : 180.0;
              return GridView.builder(
                itemCount: cards.length + 1,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: maxExtent,
                  crossAxisSpacing: NinhoSpacing.gutterMobile,
                  mainAxisSpacing: NinhoSpacing.gutterMobile,
                  childAspectRatio: 0.9,
                ),
                itemBuilder: (context, index) {
                  if (index == cards.length) {
                    return _AddRoomCard(
                      key: const ValueKey('setup_add_room_card'),
                      onAdd: (name, size) =>
                          controller.addCustomRoom(name, size),
                    );
                  }
                  return _RoomCard(data: cards[index]);
                },
              );
            },
          ),
          const SizedBox(height: NinhoSpacing.stackLg),
        ],
      ),
    );
  }
}

class _RoomCardData {
  const _RoomCardData({required this.name, this.selected});
  final String name;
  final Room? selected;
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.data});
  final _RoomCardData data;

  Future<void> _choosePhoto(BuildContext context) async {
    final controller = context.read<SetupController>();
    final source = await showModalBottomSheet<RoomPhotoSource>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(NinhoSpacing.stackMd),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera),
                  title: const Text('Tirar foto'),
                  onTap: () => Navigator.of(ctx).pop(RoomPhotoSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Escolher da galeria'),
                  onTap: () => Navigator.of(ctx).pop(RoomPhotoSource.gallery),
                ),
                if (data.selected?.photoDraft != null)
                  ListTile(
                    leading: const Icon(Icons.delete_outline),
                    title: const Text('Remover foto'),
                    onTap: () {
                      controller.removeRoomPhoto(data.name);
                      Navigator.of(ctx).pop();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (source == null) return;

    final ok = await controller.pickRoomPhoto(data.name, source);
    if (!context.mounted || ok) return;

    final error = controller.lastError ?? 'Não foi possível anexar a foto.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = context.read<SetupController>();
    final isSelected = data.selected != null;

    final palette = _palette(data.name, isSelected);

    return Material(
      color: palette.background,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: () {
          if (isSelected) {
            controller.removeRoom(data.name);
          } else {
            controller.toggleRoom(Room(name: data.name, size: RoomSize.m));
          }
        },
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(NinhoSpacing.paddingCard),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: palette.iconBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _iconFor(data.name),
                      color: palette.iconFg,
                      size: 22,
                    ),
                  ),
                  const Spacer(),
                  _PhotoButton(
                    room: data.selected,
                    color: palette.muted,
                    onPressed: () => _choosePhoto(context),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                data.name,
                style: theme.textTheme.titleMedium?.copyWith(color: palette.fg),
              ),
              const SizedBox(height: NinhoSpacing.stackSm),
              Row(
                children: [
                  for (final size in RoomSize.values)
                    GestureDetector(
                      onTap: () {
                        if (!isSelected) {
                          controller.toggleRoom(
                            Room(name: data.name, size: size),
                          );
                        } else {
                          controller.setRoomSize(data.name, size);
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected && data.selected?.size == size
                              ? palette.iconFg
                              : palette.iconBg,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          size.label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: isSelected && data.selected?.size == size
                                ? palette.background
                                : palette.fg,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String name) {
    final n = name.toLowerCase();
    if (n.contains('sala')) return Icons.chair;
    if (n.contains('cozinha')) return Icons.kitchen;
    if (n.contains('banheiro') || n.contains('banho')) return Icons.shower;
    if (n.contains('quarto')) return Icons.bed;
    if (n.contains('lavand') || n.contains('serviço')) {
      return Icons.local_laundry_service;
    }
    return Icons.home_filled;
  }

  _CardPalette _palette(String name, bool selected) {
    if (!selected) {
      return const _CardPalette(
        background: NinhoColors.surfaceContainer,
        fg: NinhoColors.onSurface,
        muted: NinhoColors.onSurfaceVariant,
        iconBg: NinhoColors.surfaceVariant,
        iconFg: NinhoColors.onSurfaceVariant,
      );
    }
    final n = name.toLowerCase();
    if (n.contains('cozinha')) {
      return const _CardPalette(
        background: NinhoColors.secondaryContainer,
        fg: NinhoColors.onSecondaryContainer,
        muted: NinhoColors.secondary,
        iconBg: Color(0x33536346),
        iconFg: NinhoColors.secondary,
      );
    }
    // Default selecionado: terracotta
    return const _CardPalette(
      background: NinhoColors.primaryContainer,
      fg: NinhoColors.onPrimaryContainer,
      muted: NinhoColors.primary,
      iconBg: Color(0x33944931),
      iconFg: NinhoColors.primary,
    );
  }
}

class _PhotoButton extends StatelessWidget {
  const _PhotoButton({
    required this.room,
    required this.color,
    required this.onPressed,
  });

  final Room? room;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final draft = room?.photoDraft;
    return Tooltip(
      message: draft == null ? 'Adicionar foto' : 'Trocar foto',
      child: InkResponse(
        onTap: onPressed,
        radius: 24,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.24),
            shape: BoxShape.circle,
          ),
          clipBehavior: Clip.antiAlias,
          child: draft == null
              ? Icon(Icons.photo_camera, size: 18, color: color)
              : Image.memory(draft.bytes, fit: BoxFit.cover),
        ),
      ),
    );
  }
}

class _CardPalette {
  const _CardPalette({
    required this.background,
    required this.fg,
    required this.muted,
    required this.iconBg,
    required this.iconFg,
  });
  final Color background;
  final Color fg;
  final Color muted;
  final Color iconBg;
  final Color iconFg;
}

class _AddRoomCard extends StatelessWidget {
  const _AddRoomCard({super.key, required this.onAdd});
  final void Function(String name, RoomSize size) onAdd;

  Future<void> _showDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    var size = RoomSize.m;
    final result = await showDialog<({String name, RoomSize size})>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text('Novo cômodo'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(hintText: 'Ex.: Quintal'),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (final s in RoomSize.values)
                        ChoiceChip(
                          label: Text(s.label),
                          selected: size == s,
                          onSelected: (_) => setState(() => size = s),
                        ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    if (nameCtrl.text.trim().isEmpty) return;
                    Navigator.of(
                      ctx,
                    ).pop((name: nameCtrl.text.trim(), size: size));
                  },
                  child: const Text('Adicionar'),
                ),
              ],
            );
          },
        );
      },
    );
    if (result != null) onAdd(result.name, result.size);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showDialog(context),
      child: DottedBorderBox(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: NinhoColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: NinhoColors.onSurfaceVariant),
            ),
            const SizedBox(height: NinhoSpacing.stackSm),
            Text(
              'Adicionar\ncômodo',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: NinhoColors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DottedBorderBox extends StatelessWidget {
  const DottedBorderBox({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Flutter sem dashed border nativo — simulamos com borda sólida + tom
    // outline-variant. Trocar p/ CustomPainter quando paridade visual exata
    // importar.
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: NinhoColors.outlineVariant, width: 2),
      ),
      padding: const EdgeInsets.all(NinhoSpacing.paddingCard),
      child: child,
    );
  }
}
