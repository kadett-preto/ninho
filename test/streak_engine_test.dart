import 'package:flutter_test/flutter_test.dart';
import 'package:ninho/domain/streak_engine.dart';

DateTime _day(int year, int month, int day) => DateTime(year, month, day);

StreakTask _task(
  String id, {
  required String? assignee,
  required DateTime startDate,
  int intervalDays = 1,
}) {
  return StreakTask(
    id: id,
    assigneeId: assignee,
    startDate: startDate,
    intervalDays: intervalDays,
  );
}

StreakCompletion _completion(
  String taskId,
  String by,
  DateTime at,
) {
  return StreakCompletion(taskId: taskId, completedBy: by, completedAt: at);
}

void main() {
  const engine = StreakEngine();

  group('isExpectedOn', () {
    test('daily task starting on day → expected every day', () {
      final t = _task('t', assignee: 'a', startDate: _day(2026, 5, 1));
      expect(t.isExpectedOn(_day(2026, 5, 1)), isTrue);
      expect(t.isExpectedOn(_day(2026, 5, 2)), isTrue);
      expect(t.isExpectedOn(_day(2026, 5, 10)), isTrue);
    });

    test('weekly task only every 7 days from start', () {
      final t = _task(
        't',
        assignee: 'a',
        startDate: _day(2026, 5, 1),
        intervalDays: 7,
      );
      expect(t.isExpectedOn(_day(2026, 5, 1)), isTrue);
      expect(t.isExpectedOn(_day(2026, 5, 2)), isFalse);
      expect(t.isExpectedOn(_day(2026, 5, 8)), isTrue);
      expect(t.isExpectedOn(_day(2026, 5, 15)), isTrue);
    });

    test('task before start date isnt expected', () {
      final t = _task('t', assignee: 'a', startDate: _day(2026, 5, 10));
      expect(t.isExpectedOn(_day(2026, 5, 9)), isFalse);
    });
  });

  group('evaluate', () {
    test('todas tasks concluídas: streak avança +1 para todos', () {
      final day = _day(2026, 5, 5);
      final out = engine.evaluate(
        StreakInput(
          evaluationDate: day,
          userIds: const ['alice', 'bob'],
          tasks: [
            _task('t1', assignee: 'alice', startDate: _day(2026, 5, 1)),
            _task('t2', assignee: 'bob', startDate: _day(2026, 5, 1)),
          ],
          completions: [
            _completion('t1', 'alice', day),
            _completion('t2', 'bob', day),
          ],
          priorUserStreaks: {
            'alice': StreakState.initial(day).copyWith(current: 3, best: 5),
            'bob': StreakState.initial(day).copyWith(current: 1, best: 1),
          },
          priorEnvironmentStreak:
              StreakState.initial(day).copyWith(current: 1, best: 4),
        ),
      );

      expect(out.userStreaks['alice']?.current, 4);
      expect(out.userStreaks['alice']?.best, 5);
      expect(out.userStreaks['bob']?.current, 2);
      expect(out.environmentStreak.current, 2);
      expect(out.environmentStreak.best, 4);
      expect(out.userOutcomes['alice'], StreakDayOutcome.kept);
      expect(out.environmentOutcome, StreakDayOutcome.kept);
    });

    test('falha com freeze disponível: consume e mantém streak', () {
      final day = _day(2026, 5, 5);
      final out = engine.evaluate(
        StreakInput(
          evaluationDate: day,
          userIds: const ['alice'],
          tasks: [
            _task('t1', assignee: 'alice', startDate: _day(2026, 5, 1)),
          ],
          completions: const [],
          priorUserStreaks: {
            'alice': StreakState.initial(day).copyWith(current: 5),
          },
          priorEnvironmentStreak: StreakState.initial(day),
        ),
      );

      expect(out.userStreaks['alice']?.current, 5);
      expect(out.userStreaks['alice']?.freezesLeftMonth, 1);
      expect(out.userOutcomes['alice'], StreakDayOutcome.frozen);
    });

    test('falha com freezes esgotados: streak zera', () {
      final day = _day(2026, 5, 5);
      final out = engine.evaluate(
        StreakInput(
          evaluationDate: day,
          userIds: const ['alice'],
          tasks: [
            _task('t1', assignee: 'alice', startDate: _day(2026, 5, 1)),
          ],
          completions: const [],
          priorUserStreaks: {
            'alice': StreakState.initial(day).copyWith(
              current: 5,
              freezesLeftMonth: 0,
            ),
          },
          priorEnvironmentStreak: StreakState.initial(day),
        ),
      );

      expect(out.userStreaks['alice']?.current, 0);
      expect(out.userOutcomes['alice'], StreakDayOutcome.broken);
    });

    test('streak de ninho zera mesmo com freeze individual cobrindo', () {
      final day = _day(2026, 5, 5);
      final out = engine.evaluate(
        StreakInput(
          evaluationDate: day,
          userIds: const ['alice', 'bob'],
          tasks: [
            _task('t1', assignee: 'alice', startDate: _day(2026, 5, 1)),
            _task('t2', assignee: 'bob', startDate: _day(2026, 5, 1)),
          ],
          completions: [_completion('t2', 'bob', day)],
          priorUserStreaks: {
            'alice': StreakState.initial(day).copyWith(current: 10),
            'bob': StreakState.initial(day).copyWith(current: 10),
          },
          priorEnvironmentStreak:
              StreakState.initial(day).copyWith(current: 10),
        ),
      );

      // Alice falhou + tinha freeze → kept individual com 10
      expect(out.userOutcomes['alice'], StreakDayOutcome.frozen);
      expect(out.userStreaks['alice']?.current, 10);
      expect(out.userStreaks['alice']?.freezesLeftMonth, 1);
      // Bob não falhou → +1
      expect(out.userStreaks['bob']?.current, 11);
      // Ninho zerou porque alice falhou (freeze não cobre ninho)
      expect(out.environmentStreak.current, 0);
      expect(out.environmentOutcome, StreakDayOutcome.broken);
    });

    test('modo viagem: dia pausa tudo, freezes preservados', () {
      final day = _day(2026, 5, 5);
      final out = engine.evaluate(
        StreakInput(
          evaluationDate: day,
          userIds: const ['alice'],
          tasks: [
            _task('t1', assignee: 'alice', startDate: _day(2026, 5, 1)),
          ],
          completions: const [],
          priorUserStreaks: {
            'alice': StreakState.initial(day).copyWith(
              current: 7,
              freezesLeftMonth: 2,
            ),
          },
          priorEnvironmentStreak:
              StreakState.initial(day).copyWith(current: 7),
          vacationDays: [day],
        ),
      );

      expect(out.userStreaks['alice']?.current, 7);
      expect(out.userStreaks['alice']?.freezesLeftMonth, 2);
      expect(out.environmentStreak.current, 7);
      expect(out.userOutcomes['alice'], StreakDayOutcome.paused);
      expect(out.environmentOutcome, StreakDayOutcome.paused);
    });

    test('virada de mês reseta freezes para 2', () {
      final day = _day(2026, 6, 1);
      final out = engine.evaluate(
        StreakInput(
          evaluationDate: day,
          userIds: const ['alice'],
          tasks: [
            _task('t1', assignee: 'alice', startDate: _day(2026, 5, 1)),
          ],
          completions: [_completion('t1', 'alice', day)],
          priorUserStreaks: {
            'alice': const StreakState(
              current: 3,
              best: 5,
              freezesLeftMonth: 0,
              monthKey: '2026-05',
            ),
          },
          priorEnvironmentStreak: const StreakState(
            current: 3,
            best: 3,
            freezesLeftMonth: 2,
            monthKey: '2026-05',
          ),
        ),
      );

      expect(out.userStreaks['alice']?.freezesLeftMonth, 2);
      expect(out.userStreaks['alice']?.monthKey, '2026-06');
      expect(out.userStreaks['alice']?.current, 4);
    });

    test('dia sem tasks esperadas: streak avança (dia limpo)', () {
      // Task semanal — só esperada a cada 7 dias. Hoje não é dia esperado.
      final day = _day(2026, 5, 3);
      final out = engine.evaluate(
        StreakInput(
          evaluationDate: day,
          userIds: const ['alice'],
          tasks: [
            _task(
              't1',
              assignee: 'alice',
              startDate: _day(2026, 5, 1),
              intervalDays: 7,
            ),
          ],
          completions: const [],
          priorUserStreaks: {
            'alice': StreakState.initial(day).copyWith(current: 2),
          },
          priorEnvironmentStreak: StreakState.initial(day),
        ),
      );

      expect(out.userStreaks['alice']?.current, 3);
      expect(out.userOutcomes['alice'], StreakDayOutcome.kept);
    });

    test('task sem assignee não conta para streak de ninguém', () {
      final day = _day(2026, 5, 5);
      final out = engine.evaluate(
        StreakInput(
          evaluationDate: day,
          userIds: const ['alice'],
          tasks: [
            _task('t1', assignee: null, startDate: _day(2026, 5, 1)),
          ],
          completions: const [],
          priorUserStreaks: {
            'alice': StreakState.initial(day).copyWith(current: 1),
          },
          priorEnvironmentStreak: StreakState.initial(day),
        ),
      );

      // Alice não tinha task esperada → streak avança normalmente
      expect(out.userStreaks['alice']?.current, 2);
      expect(out.environmentStreak.current, 1);
    });

    test('estado inicial sem priorState: cria default', () {
      final day = _day(2026, 5, 5);
      final out = engine.evaluate(
        StreakInput(
          evaluationDate: day,
          userIds: const ['alice'],
          tasks: const [],
          completions: const [],
          priorUserStreaks: const {},
          priorEnvironmentStreak: StreakState.initial(day),
        ),
      );

      expect(out.userStreaks['alice']?.current, 1);
      expect(out.userStreaks['alice']?.freezesLeftMonth, 2);
      expect(out.userStreaks['alice']?.monthKey, '2026-05');
    });
  });
}
