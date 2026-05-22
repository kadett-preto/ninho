import 'package:flutter_test/flutter_test.dart';

import 'package:ninho/data/repositories/suggestions_repository.dart';

void main() {
  group('TaskDifficulty', () {
    test('parsing aceita os 3 valores do Ninho', () {
      expect(TaskDifficulty.tryParse('mamao'), TaskDifficulty.mamao);
      expect(TaskDifficulty.tryParse('embacada'), TaskDifficulty.embacada);
      expect(TaskDifficulty.tryParse('treta'), TaskDifficulty.treta);
    });

    test('parsing rejeita valores fora do enum', () {
      expect(TaskDifficulty.tryParse('facil'), isNull);
      expect(TaskDifficulty.tryParse(null), isNull);
      expect(TaskDifficulty.tryParse(''), isNull);
    });
  });

  group('TaskSuggestion.fromJson', () {
    test('parseia payload bem-formado', () {
      final s = TaskSuggestion.fromJson({
        'room_id': 'r1',
        'title': '  Lavar louça ',
        'difficulty': 'mamao',
        'interval_days': 1,
        'description': ' todo dia ',
      });
      expect(s.roomId, 'r1');
      expect(s.title, 'Lavar louça');
      expect(s.difficulty, TaskDifficulty.mamao);
      expect(s.intervalDays, 1);
      expect(s.description, 'todo dia');
    });

    test('description é opcional', () {
      final s = TaskSuggestion.fromJson({
        'room_id': 'r1',
        'title': 'X',
        'difficulty': 'treta',
        'interval_days': 30,
      });
      expect(s.description, isNull);
    });

    test('rejeita difficulty inválida', () {
      expect(
        () => TaskSuggestion.fromJson({
          'room_id': 'r1',
          'title': 'X',
          'difficulty': 'facil',
          'interval_days': 7,
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejeita interval fora do conjunto permitido', () {
      expect(
        () => TaskSuggestion.fromJson({
          'room_id': 'r1',
          'title': 'X',
          'difficulty': 'mamao',
          'interval_days': 2,
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('TaskSuggestion.toAcceptJson', () {
    test('omite description vazia', () {
      const s = TaskSuggestion(
        roomId: 'r1',
        title: 'X',
        difficulty: TaskDifficulty.mamao,
        intervalDays: 7,
        description: '',
      );
      final json = s.toAcceptJson();
      expect(json.containsKey('description'), isFalse);
      expect(json['difficulty'], 'mamao');
      expect(json['interval_days'], 7);
    });

    test('inclui description não-vazia', () {
      const s = TaskSuggestion(
        roomId: 'r1',
        title: 'X',
        difficulty: TaskDifficulty.embacada,
        intervalDays: 3,
        description: 'detalhe',
      );
      expect(s.toAcceptJson()['description'], 'detalhe');
    });
  });

  group('TaskSuggestion.copyWith', () {
    test('mantém room_id imutável, troca demais campos', () {
      const s = TaskSuggestion(
        roomId: 'r1',
        title: 'orig',
        difficulty: TaskDifficulty.mamao,
        intervalDays: 1,
      );
      final t = s.copyWith(
        title: 'edit',
        difficulty: TaskDifficulty.treta,
        intervalDays: 14,
      );
      expect(t.roomId, 'r1');
      expect(t.title, 'edit');
      expect(t.difficulty, TaskDifficulty.treta);
      expect(t.intervalDays, 14);
    });
  });
}
