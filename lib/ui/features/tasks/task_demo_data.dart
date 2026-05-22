import 'package:flutter/material.dart';

import '../../core/colors.dart';

enum TaskDemoDifficulty { mamao, embacada, treta }

class TaskDemo {
  const TaskDemo({
    required this.id,
    required this.title,
    required this.room,
    required this.responsible,
    required this.recurrence,
    required this.startDate,
    required this.reward,
    required this.description,
    required this.difficulty,
    required this.icon,
    required this.roomIcon,
    required this.accent,
    required this.iconBackground,
    required this.iconColor,
    required this.assigneeInitial,
  });

  final String id;
  final String title;
  final String room;
  final String responsible;
  final String recurrence;
  final String startDate;
  final int reward;
  final String description;
  final TaskDemoDifficulty difficulty;
  final IconData icon;
  final IconData roomIcon;
  final Color accent;
  final Color iconBackground;
  final Color iconColor;
  final String assigneeInitial;

  String get difficultyLabel => switch (difficulty) {
    TaskDemoDifficulty.mamao => 'Mamão',
    TaskDemoDifficulty.embacada => 'Embaçada',
    TaskDemoDifficulty.treta => 'Treta',
  };

  Color get difficultyBackground => switch (difficulty) {
    TaskDemoDifficulty.mamao => NinhoColors.secondaryFixedDim,
    TaskDemoDifficulty.embacada => NinhoColors.tertiaryFixedDim,
    TaskDemoDifficulty.treta => NinhoColors.primaryContainer,
  };

  Color get difficultyForeground => switch (difficulty) {
    TaskDemoDifficulty.mamao => NinhoColors.onSecondaryFixedVariant,
    TaskDemoDifficulty.embacada => NinhoColors.onTertiaryFixedVariant,
    TaskDemoDifficulty.treta => NinhoColors.onPrimaryContainer,
  };
}

const taskDemoItems = [
  TaskDemo(
    id: 'dishes',
    title: 'Lavar a louça',
    room: 'Cozinha',
    responsible: 'Marina',
    recurrence: 'Toda segunda e quinta',
    startDate: '12 mai',
    reward: 15,
    description:
        'Certifique-se de secar bem os pratos e guardar as panelas no armário debaixo.',
    difficulty: TaskDemoDifficulty.mamao,
    icon: Icons.local_laundry_service_outlined,
    roomIcon: Icons.countertops_outlined,
    accent: NinhoColors.secondaryContainer,
    iconBackground: NinhoColors.secondaryContainer,
    iconColor: NinhoColors.onSecondaryContainer,
    assigneeInitial: 'M',
  ),
  TaskDemo(
    id: 'living-room',
    title: 'Varrer a sala',
    room: 'Sala',
    responsible: 'Lucas',
    recurrence: 'Toda terça e sexta',
    startDate: '12 mai',
    reward: 15,
    description:
        'Passe por baixo do sofá e junte a poeira no canto antes de finalizar.',
    difficulty: TaskDemoDifficulty.embacada,
    icon: Icons.cleaning_services_outlined,
    roomIcon: Icons.chair_outlined,
    accent: NinhoColors.tertiaryFixedDim,
    iconBackground: NinhoColors.surfaceContainerHigh,
    iconColor: NinhoColors.onSurface,
    assigneeInitial: 'L',
  ),
  TaskDemo(
    id: 'bathroom',
    title: 'Limpar o banheiro',
    room: 'Banheiro',
    responsible: 'Marina',
    recurrence: 'Todo sábado',
    startDate: '12 mai',
    reward: 40,
    description:
        'Capriche no box, na pia e no vaso. Deixe o tapete secando depois.',
    difficulty: TaskDemoDifficulty.treta,
    icon: Icons.bathtub_outlined,
    roomIcon: Icons.shower_outlined,
    accent: NinhoColors.primaryContainer,
    iconBackground: NinhoColors.primaryContainer,
    iconColor: NinhoColors.onPrimaryContainer,
    assigneeInitial: 'M',
  ),
];

TaskDemo taskDemoById(String id) {
  return taskDemoItems.firstWhere(
    (task) => task.id == id,
    orElse: () => taskDemoItems.first,
  );
}
